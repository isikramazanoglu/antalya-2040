class_name BusinessSimulator
extends RefCounted
## Sahip: B. İşletmeler ve çevre denetimi (Prompt 13). Saf hesap: durum tutmaz, sinyal yaymaz, GameState'e yazmaz.
## İşletme sözlüğü (GameState.businesses öğesi) docs/BUSINESS_SYSTEM.md §3'te. Bütün sayılar BalanceConfig'te.

const LEVEL_NAMES := ["Uygun", "Hafif ihlal", "Orta ihlal", "Ağır ihlal", "Çok ağır ihlal"]
const GHG_NAMES := ["Düşük", "Orta", "Yüksek", "Çok yüksek"]
const ORDERS := [&"filter", &"clean_energy", &"treatment", &"grace", &"suspend"]
## Kurgusal şirket adları (gerçek şirketleri temsil etmez).
const NAME_PARTS := ["Akdeniz", "Toros", "Konyaaltı", "Lara", "Kepez", "Aksu", "Düden", "Olimpos", "Belek", "Kaleiçi", "Falez", "Manavgat"]
const TYPE_WORDS := {
	&"small_factory": "Üretim", &"heavy_factory": "Ağır Sanayi", &"logistics_warehouse": "Lojistik", &"concrete_plant": "Beton",
	&"waste_facility": "Atık İşleme", &"chemical_plant": "Kimya", &"food_factory": "Gıda", &"textile_plant": "Tekstil",
	&"energy_intensive_commerce": "Ticaret", &"small_workshop": "Atölye",
}


static func get_type(types: Array[BusinessType], id: StringName) -> BusinessType:
	for t in types:
		if t.id == id:
			return t
	return null


## Yeni işletme sözlüğü. seq kalıcı sayaçtır; kimlik bir kez verilir, yeniden kullanılmaz.
static func create(t: BusinessType, site_id: StringName, seq: int, year: int, month: int) -> Dictionary:
	return {
		"business_id": StringName("B%03d" % seq),
		"business_name": "%s %s A.Ş." % [NAME_PARTS[seq % NAME_PARTS.size()], TYPE_WORDS.get(t.id, "Sanayi")],
		"business_type": t.id,
		"site_id": site_id,
		"established_year": year,
		"established_month": month,
		"production": 1.0,
		"operational_status": &"active",
		"suspended_months": 0,
		"upgrades": {"filter": false, "clean_energy": false, "treatment": false},
		"pending_improvements": [],
		"inspection_history": [],
		"violation_history": [],
		"fines_paid": 0,
		"escalation": 0,
		"last_inspection": {},  # {"year", "month"}: yeniden denetim aralığı için
		"fines_by_year": {},  # yıl -> o yıl kesilen ceza sayısı (yıllık sınır)
	}


## İşletmenin o anki etkileri (yükseltmeler, üretim, faaliyet durumu dahil).
static func effective(b: Dictionary, t: BusinessType, bal: BalanceConfig) -> Dictionary:
	var p: float = b.production
	var air := t.air * p
	var waste := t.waste * p
	var ghg_energy := t.ghg * t.ghg_energy_share * p
	var ghg_process := t.ghg * (1.0 - t.ghg_energy_share) * p
	var up: Dictionary = b.upgrades
	if up.filter:
		air *= 1.0 - bal.order_reduction.get("filter", 0.0)
	if up.treatment:
		waste *= 1.0 - bal.order_reduction.get("treatment", 0.0)
	if up.clean_energy:
		ghg_energy *= 1.0 - bal.order_reduction.get("clean_energy", 0.0)
	var contribution := t.yearly_contribution * p
	if (b.pending_improvements as Array).any(func(o): return o.order != &"grace"):
		contribution *= 1.0 - bal.order_contribution_cut
	var share := 1.0
	match b.operational_status:
		&"suspended":
			share = bal.suspended_emission_share
			contribution = 0.0
		&"closed":
			share = 0.0
			contribution = 0.0
	return {
		"air": air * share, "waste": waste * share, "ghg": (ghg_energy + ghg_process) * share,
		"energy": t.energy_use * p * share, "water": t.water_use * p * share,
		"contribution": contribution, "employees": t.employees if b.operational_status == &"active" else 0,
	}


## 0 uygun … 4 çok ağır. Standartlar oyun değeridir (gerçek mevzuat değil).
static func violation_level(eff: Dictionary, bal: BalanceConfig) -> int:
	var ratio := maxf(eff.air / bal.air_standard, eff.waste / bal.waste_standard)
	if ratio <= 1.0:
		return 0
	if ratio <= 1.5:
		return 1
	if ratio <= 2.0:
		return 2
	if ratio <= 3.0:
		return 3
	return 4


static func ghg_level(eff: Dictionary) -> int:
	return 0 if eff.ghg < 2.0 else (1 if eff.ghg < 4.0 else (2 if eff.ghg < 6.0 else 3))


static func fine_amount(b: Dictionary, t: BusinessType, level: int, bal: BalanceConfig) -> int:
	var mult: float = bal.fine_level_multipliers[clampi(level, 0, bal.fine_level_multipliers.size() - 1)]
	var amount: float = bal.fine_base * t.size * mult * (1.0 + b.fines_paid * bal.fine_repeat_factor) * (1.0 + 0.5 * b.escalation)
	return mini(roundi(amount), bal.fine_cap)


static func months_between(from: Dictionary, year: int, month: int) -> int:
	if from.is_empty():
		return 9999
	return (year - from.year) * 12 + month - from.month


## Denetlenebilir mi? &"" evet; değilse neden.
static func inspect_block_reason(b: Dictionary, year: int, month: int, bal: BalanceConfig) -> StringName:
	if b.operational_status == &"closed":
		return &"closed"
	if months_between(b.last_inspection, year, month) < bal.inspection_cooldown_months:
		return &"cooldown"
	return &""


## Denetim raporu (yeni kayıt). Değerlendirme veri modelinden; görselden değil.
static func inspect(b: Dictionary, t: BusinessType, bal: BalanceConfig, year: int, month: int) -> Dictionary:
	var eff := effective(b, t, bal)
	var level := violation_level(eff, bal)
	return {
		"inspection_id": "%s-%d-%02d" % [b.business_id, year, month],
		"year": year, "month": month,
		"level": level,
		"air": snappedf(eff.air, 0.1), "waste": snappedf(eff.waste, 0.1), "ghg": snappedf(eff.ghg, 0.1),
		"air_ok": eff.air <= bal.air_standard, "waste_ok": eff.waste <= bal.waste_standard,
		"filter": b.upgrades.filter, "treatment": b.upgrades.treatment, "clean_energy": b.upgrades.clean_energy,
		"previous_violations": (b.violation_history as Array).size(),
		"suggested_fine": fine_amount(b, t, level, bal) if level > 0 else 0,
		"fined": false, "fine_paid": 0, "order": &"",
	}


## Ceza kesilebilir mi? Son denetimde ihlal varsa, o denetime henüz ceza kesilmediyse ve işletme bu yıl
## yıllık ceza sınırını doldurmadıysa (year: içinde bulunulan yıl; 0 ise yıllık sınır denetlenmez).
static func fine_block_reason(b: Dictionary, year := 0, bal: BalanceConfig = null) -> StringName:
	var hist: Array = b.inspection_history
	if hist.is_empty():
		return &"no_inspection"
	var last: Dictionary = hist[-1]
	if last.level == 0:
		return &"no_violation"
	if last.fined:
		return &"already_fined"
	if bal and int(b.get("fines_by_year", {}).get(year, 0)) >= bal.fines_per_business_per_year:
		return &"yearly_fine_limit"
	return &""


## Karar verilebilir mi? Yalnızca son denetimde ihlal varsa ve o denetim için henüz karar yoksa.
static func order_block_reason(b: Dictionary, order: StringName) -> StringName:
	if not order in ORDERS:
		return &"unknown_order"
	if b.operational_status == &"closed":
		return &"closed"
	var hist: Array = b.inspection_history
	if hist.is_empty() or hist[-1].level == 0:
		return &"no_violation"
	if hist[-1].order != &"":
		return &"already_ordered"
	if order in [&"filter", &"clean_energy", &"treatment"] and b.upgrades.get(order, false):
		return &"already_upgraded"
	if order == &"suspend" and b.operational_status == &"suspended":
		return &"already_suspended"
	return &""


## Bir ay geçer: süresi dolan kararlar uygulanır. Dönüş: [güncel işletme, olaylar].
## Olaylar: {"kind": &"order_done" | &"grace_improved" | &"grace_ignored" | &"closed", "order": …}
static func month_tick(b: Dictionary, t: BusinessType, bal: BalanceConfig, roll: float) -> Array:
	var out := b.duplicate(true)
	var events := []
	if out.operational_status == &"suspended":
		out.suspended_months += 1
		if out.suspended_months >= bal.closure_after_suspended_months:
			out.operational_status = &"closed"
			out.pending_improvements = []
			events.append({"kind": &"closed"})
			return [out, events]
	var still := []
	for o in out.pending_improvements:
		o.months_left -= 1
		if o.months_left > 0:
			still.append(o)
			continue
		if o.order == &"grace":
			# Süre doldu: işletme yarı yarıya kendiliğinden iyileştirir; yapmazsa bir sonraki ceza ağırlaşır.
			var eff := effective(out, t, bal)
			if roll < 0.5:
				var fix := &"filter" if eff.air / bal.air_standard >= eff.waste / bal.waste_standard else &"treatment"
				out.upgrades[fix] = true
				events.append({"kind": &"grace_improved", "order": fix})
			else:
				out.escalation += 1
				events.append({"kind": &"grace_ignored"})
		else:
			out.upgrades[o.order] = true
			events.append({"kind": &"order_done", "order": o.order})
	out.pending_improvements = still
	return [out, events]


## Yıllık gelişim: üretim dalgalanır (drift ±). roll -1..1.
static func year_tick(b: Dictionary, bal: BalanceConfig, roll: float) -> Dictionary:
	var out := b.duplicate(true)
	if out.operational_status == &"active":
		out.production = clampf(out.production * (1.0 + bal.production_drift * roll), 0.6, 1.4)
	return out


## Şehir toplamı: ekonomiye, kaynaklara, emisyona ve kirlilik endekslerine eklenen değerler.
static func city_totals(businesses: Array, types: Array[BusinessType], bal: BalanceConfig) -> Dictionary:
	var t := {"contribution": 0.0, "energy": 0.0, "water": 0.0, "ghg": 0.0, "air": 0.0, "waste": 0.0, "employees": 0, "count": 0}
	for b in businesses:
		var bt := get_type(types, b.business_type)
		if bt == null or b.operational_status == &"closed":
			continue
		var e := effective(b, bt, bal)
		for k in ["contribution", "energy", "water", "ghg", "air", "waste"]:
			t[k] += e[k]
		t.employees += e.employees
		t.count += 1
	t["air_pollution"] = clampf(t.air * bal.air_index_per_unit, 0.0, 100.0)
	t["waste_pollution"] = clampf(t.waste * bal.waste_index_per_unit, 0.0, 100.0)
	return t


## Bu ay yeni işletme gelir mi? Dönüş: {} ya da {"type": BusinessType, "site_id"}. r1, r2, r3: 0..1 rastgele.
## Koşullar: boş sanayi yeri, üst sınır, nüfus, hava kirliliği tavanı, su durumu, lojistik ihtiyacı.
static func spawn(stats: Dictionary, businesses: Array, types: Array[BusinessType], bal: BalanceConfig, r1: float, r2: float, r3: float) -> Dictionary:
	var used := {}
	var alive := 0
	for b in businesses:
		if b.operational_status != &"closed":
			used[b.site_id] = true
			alive += 1
	var free: Array = bal.industrial_sites.filter(func(s): return not used.has(s))
	if free.is_empty() or alive >= bal.max_businesses:
		return {}
	var pop_factor := clampf(stats.population / 500.0, 0.5, 2.0)
	var p := bal.business_spawn_chance * pop_factor * (1.0 - float(alive) / bal.max_businesses)
	if r1 >= p:
		return {}
	var air_now: float = city_totals(businesses, types, bal).air_pollution
	var weights := []
	var total := 0.0
	for t in types:
		var w := 0.0
		if stats.population >= t.min_population:
			w = t.spawn_weight
			if air_now > bal.air_pollution_soft_cap and t.air >= 6.0:
				w *= 0.2  # çevre taşıma kapasitesi: kirleten sanayinin kontrolsüz artışı sınırlanır
			if stats.water_security < 40.0 and t.water_use >= 4.0:
				w *= 0.3  # su altyapısı yetersiz
			if t.logistics and stats.population > 550:
				w *= 1.5  # büyüyen şehirde lojistik ihtiyacı
		weights.append(w)
		total += w
	if total <= 0.0:
		return {}
	var pick := r2 * total
	for i in types.size():
		pick -= weights[i]
		if pick <= 0.0 and weights[i] > 0.0:
			return {"type": types[i], "site_id": free[mini(int(r3 * free.size()), free.size() - 1)]}
	return {}


## Ekip A görseli için veri (sözleşme v1.10). Görsel hesap yapmaz; bunu kullanır.
static func visual_info(b: Dictionary, t: BusinessType, bal: BalanceConfig) -> Dictionary:
	var eff := effective(b, t, bal)
	return {
		"business_id": b.business_id,
		"business_type": b.business_type,
		"business_name": b.business_name,
		"visual_id": t.visual_id if t else &"",
		"site_id": b.site_id,
		"operational_status": b.operational_status,
		"violation_level": violation_level(eff, bal),
		"emission_level": ghg_level(eff),
		"smoke_intensity": clampf(eff.air / 10.0, 0.0, 1.0),
		"upgrades": (b.upgrades as Dictionary).duplicate(),
	}
