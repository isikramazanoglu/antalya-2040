class_name FinalEvaluator
extends RefCounted
## Sahip: B. 2052 final değerlendirmesi (Prompt 10A). Saf hesap: kayıtlı verilerden okur, hiçbir şey yazmaz.
## Bu bir oyun içi değerlendirmedir; bilimsel bir iklim dayanıklılığı ölçümü değildir.
## Boş veya eksik veride çökmez; her alt puan 0..100 aralığındadır.

## Genel puan ağırlıkları (toplam 100). docs/GAME_DESIGN.md "Final değerlendirmesi".
const WEIGHTS := {"economy": 15, "water": 15, "energy": 15, "adaptation": 15, "ecosystem": 15, "quality": 15, "preparedness": 10}
const TITLES := {"economy": "Parayı iyi kullanma", "water": "Su", "energy": "Temiz elektrik",
		"adaptation": "Tehlikelere karşı koruma", "ecosystem": "Doğayı koruma", "quality": "Yaşam kalitesi", "preparedness": "Krizlere hazırlık"}
const ADVICE := {
	"economy": "Borca girmeden yatırım yap; bakım masraflarını gelirle dengele.",
	"water": "Su deposu, suyu yeniden kullanma ve kent tarımı ile şehrin suyunu artır.",
	"energy": "Güneş enerjisi ve verimli binalarla temiz elektriği artır, kişi başına karbonu azalt.",
	"adaptation": "Kuraklık, sıcak ve taşkın için koruyucu yatırımları dengeli kur.",
	"ecosystem": "Park, kent tarımı, kompost ve kıyı onarımıyla doğayı güçlendir.",
	"quality": "Park, toplu taşıma ve serinleme merkezi gibi insanların günlük hayatını iyileştiren yatırımlar yap.",
	"preparedness": "Uyarı gelince, kriz gelmeden önce koruyucu yatırımı yap.",
}
const GRADES := [
	[80, "İklim Lideri", "Şehrin 2052'ye dengeli ve dayanıklı ulaştı. Kararların ekonomi, doğa ve halkın güvenliği arasında iyi bir denge kurdu."],
	[65, "Dayanıklı Şehir", "Şehrin krizleri büyük kayıp vermeden atlattı. Birkaç alanda daha cesur adımlarla iklim lideri olabilirdin."],
	[50, "Gelişen Şehir", "Doğru yöne adımlar attın ama bazı riskler hazırlıksız yakaladı. Zayıf kalan alanlara öncelik vermek farkı yaratır."],
	[0, "Risk Altında", "Şehir 2052'ye kırılgan girdi. Yatırımları uyarılardan önce yapmak ve kaynakları dengelemek bir sonraki oyunda en büyük farkı yaratır."],
]


static func _num(d: Dictionary, key: String, fallback := 0.0) -> float:
	var v = d.get(key, fallback)
	return float(v) if v != null else fallback


static func evaluate(start: Dictionary, final: Dictionary, history: Array, reports: Array, crises: Array, builds: Array, b: BalanceConfig) -> Dictionary:
	var dims := {}
	var max_mit := maxf(b.max_mitigation, 0.01)

	# Ekonomi: borçsuz yıl oranı (%60) + yıl sonu kasası (500 kredi ve üstü tam, %40).
	var years := maxi(history.size(), 1)
	var debt_years := history.filter(func(s): return _num(s, "credits") < 0.0).size()
	var credits := _num(final, "credits")
	dims["economy"] = [60.0 * (1.0 - float(debt_years) / years) + 40.0 * clampf(credits / 500.0, 0.0, 1.0),
			"%d yıldan %d tanesinde borçtaydın, sonunda %d kredin vardı" % [history.size(), debt_years, roundi(credits)]]

	# Su: su güvenliği (%70) + arzın talebi karşılama oranı (%30; geri kazanılmış su yalnızca içme dışı kısmı).
	var demand := _num(final, "water_demand")
	var supply := _num(final, "water_supply") + _num(final, "recycled_water_used")
	var coverage := clampf(supply / demand, 0.0, 1.0) if demand > 0.0 else 1.0
	dims["water"] = [0.7 * _num(final, "water_security") + 30.0 * coverage,
			"su puanı %d, su ihtiyacı karşılama oranı %%%d" % [roundi(_num(final, "water_security")), roundi(coverage * 100)]]

	# Enerji: enerji güvenliği (%40) + yenilenebilir payı (%30) + kişi başı emisyon azalması (%30; %50 azalma tam puan).
	var pc_cut := emission_reduction(start, final)
	dims["energy"] = [0.4 * _num(final, "energy_security") + 30.0 * clampf(_num(final, "renewable_share"), 0.0, 1.0) + 30.0 * clampf(pc_cut / 50.0, 0.0, 1.0),
			"temiz elektrik payı %%%d, kişi başına karbon %%%d azaldı" % [roundi(_num(final, "renewable_share") * 100), roundi(pc_cut)]]

	# Uyum: üç risk için ortalama yatırım koruması, en yüksek korumaya göre.
	var resilience := _num(final, "climate_resilience")
	dims["adaptation"] = [100.0 * resilience / max_mit, "üç tehlikeye karşı ortalama koruma %%%d" % roundi(resilience * 100)]
	dims["ecosystem"] = [_num(final, "ecosystem_health"), "doğa puanı %d/100" % roundi(_num(final, "ecosystem_health"))]
	dims["quality"] = [_num(final, "quality_of_life"), "yaşam kalitesi %d/100" % roundi(_num(final, "quality_of_life"))]

	# Hazırlık: krizler anındaki ortalama koruma; kriz yoksa uyum puanı kullanılır.
	if crises.is_empty():
		dims["preparedness"] = [dims["adaptation"][0], "kriz olmadı; tehlikelere karşı koruman esas alındı"]
	else:
		var mit_sum := 0.0
		for c in crises:
			mit_sum += _num(c, "mitigation")
		var avg := mit_sum / crises.size()
		dims["preparedness"] = [100.0 * avg / max_mit, "%d krizde ortalama koruma %%%d" % [crises.size(), roundi(avg * 100)]]

	var dimensions := []
	var total := 0.0
	var weight_sum := 0.0
	for key in WEIGHTS:
		var score := clampf(float(dims[key][0]), 0.0, 100.0)
		dimensions.append({"id": key, "title": TITLES[key], "score": roundi(score), "weight": WEIGHTS[key], "why": dims[key][1], "advice": ADVICE[key]})
		total += score * WEIGHTS[key]
		weight_sum += WEIGHTS[key]
	var overall := roundi(total / weight_sum)
	var sorted := dimensions.duplicate()
	sorted.sort_custom(func(x, y): return x.score > y.score)
	var grade: Array = GRADES[-1]
	for g in GRADES:
		if overall >= g[0]:
			grade = g
			break
	return {
		"overall": overall,
		"grade": grade[1],
		"grade_text": grade[2],
		"dimensions": dimensions,
		"best": sorted[0],
		"worst": sorted[-1],
		"emission_reduction_pct": roundi(pc_cut),
		"comparisons": compare(start, final),
		"totals": totals(reports, crises, builds),
	}


## Kişi başı emisyondaki % azalma (artış 0 sayılır).
static func emission_reduction(start: Dictionary, final: Dictionary) -> float:
	var sp := _num(start, "emissions_total") / maxf(_num(start, "population", 1.0), 1.0)
	var fp := _num(final, "emissions_total") / maxf(_num(final, "population", 1.0), 1.0)
	return maxf(0.0, (sp - fp) / sp * 100.0) if sp > 0.0 else 0.0


## 2040 ↔ 2052 karşılaştırması. better: &"up" yükseliş iyi, &"down" düşüş iyi, &"neutral" tek başına iyi/kötü değil.
## pct: başlangıç 0 ise null (yüzde hesaplanmaz).
static func compare(start: Dictionary, final: Dictionary) -> Array:
	var rows := [
		["credits", "Bütçe (kredi)", &"neutral", 1.0],
		["population", "Nüfus", &"neutral", 1.0],
		["water_security", "Su puanı", &"up", 1.0],
		["energy_balance", "Temiz elektrik − ihtiyaç", &"up", 1.0],
		["renewable_share", "Temiz elektrik payı (%)", &"up", 100.0],
		["quality_of_life", "Yaşam kalitesi", &"up", 1.0],
		["ecosystem_health", "Doğa", &"up", 1.0],
		["emissions_total", "Karbon salımı", &"down", 1.0],
		["waste_recovery", "Çöp azaltma (%)", &"up", 100.0],
		["climate_resilience", "Tehlikelere karşı koruma (%)", &"up", 100.0],
	]
	var out := []
	for r in rows:
		var a: float = _value(start, r[0]) * r[3]
		var f: float = _value(final, r[0]) * r[3]
		var delta: float = f - a
		out.append({"key": r[0], "title": r[1], "start": a, "final": f, "delta": delta,
				"pct": (delta / absf(a) * 100.0) if not is_zero_approx(a) else null, "better": r[2],
				"improved": (delta > 0.0 and r[2] == &"up") or (delta < 0.0 and r[2] == &"down")})
	return out


static func _value(d: Dictionary, key: String) -> float:
	if key == "energy_balance":
		return _num(d, "renewable_energy") - _num(d, "energy_demand")
	return _num(d, key)


static func totals(reports: Array, crises: Array, builds: Array) -> Dictionary:
	var t := {"investment_cost": 0, "upkeep": 0, "income": 0, "crisis_loss": 0, "buildings": builds.size()}
	for e in builds:
		t.investment_cost += int(e.get("cost", 0))
	for r in reports:
		t.upkeep += int(r.get("upkeep", 0))
		t.income += int(r.get("income", 0))
	for c in crises:
		t.crisis_loss += int(c.get("damage", {}).get("credits", 0.0))
	return t
