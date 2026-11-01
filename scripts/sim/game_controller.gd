class_name GameController
extends Node
## Sahip: B. Oyuncu taleplerini karşılar; GameState'e yazan tek modül (mimari §3).

@onready var turn_manager: TurnManager = $TurnManager

var _plot_kinds: Dictionary = {}  # plot_id -> plot_kind, plot_selected'dan öğrenilir


func _ready() -> void:
	add_to_group("game_controller")
	EventBus.plot_selected.connect(_on_plot_selected)
	# Otomatik kayıt: her yeni yılın başında (Ocak), oyun bitince kayıt silinir.
	EventBus.year_started.connect(func(_y): save_game.call_deferred())
	EventBus.game_over.connect(func(_s): SaveGame.delete())
	EventBus.build_requested.connect(_on_build_requested)
	EventBus.end_turn_requested.connect(turn_manager.end_year)
	EventBus.report_closed.connect(turn_manager.close_report)
	EventBus.crisis_response_chosen.connect(turn_manager.on_crisis_response)
	var clock := MonthClock.new()
	clock.name = "MonthClock"
	add_child(clock)
	# UI node'ları _ready'lerini bitirsin, ilk year_started'ı kaçırmasın.
	turn_manager.start_game.call_deferred()


## Yol kenarı araç denetimi (teslim MVP): trafikten bir araç durdurulur; emisyon seviyesi araç verisinden (görselden değil).
const VEHICLE_MODELS := ["Otomobil", "Kamyonet", "Minibüs", "Otobüs", "Elektrikli otomobil"]
const VEHICLE_LEVELS := ["Düşük", "Orta", "Yüksek"]
const VEHICLE_FINE := 10


var _vehicle_seq := 0


func inspect_vehicle() -> Dictionary:
	_vehicle_seq += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.rng_seed, GameState.stats.year, GameState.month, _vehicle_seq])
	var model: String = VEHICLE_MODELS[rng.randi() % VEHICLE_MODELS.size()]
	var roll := rng.randf()
	var level := 0 if model == "Elektrikli otomobil" else (2 if roll < 0.3 else (1 if roll < 0.65 else 0))
	GameState.vehicle_check = {"plate": "07 %s %03d" % [["AB", "KL", "MN", "TR", "ZS", "DE"][rng.randi() % 6], rng.randi_range(100, 999)],
			"model": model, "level": level}
	return GameState.vehicle_check


## Yalnızca yüksek emisyonda; aynı araca aynı ay bir kez. Ceza ortak kredi bakiyesine girer.
func fine_vehicle() -> StringName:
	var v: Dictionary = GameState.vehicle_check
	if v.is_empty():
		return &"no_inspection"
	if v.level < 2:
		return &"no_violation"
	var key: int = GameState.stats.year * 12 + GameState.month
	if GameState.vehicle_fines.get(v.plate, -1) == key:
		return &"already_fined"
	GameState.vehicle_fines[v.plate] = key
	GameState.apply_deltas({"credits": VEHICLE_FINE})
	turn_manager.note_fine(VEHICLE_FINE)
	_toast("%s plakalı araca %d kredi egzoz cezası kesildi." % [v.plate, VEHICLE_FINE], UiText.C_ACCENT, "coin")
	return &""


## Zorunlu iklim sorusu doğru cevaplandı: bu ay bir daha sorulmaz, sıradaki soru hazırlanır.
func quiz_passed() -> void:
	GameState.quiz_done_key = GameState.stats.year * 12 + GameState.month
	GameState.quiz_count += 1


## Oyunu kaydeder (yalnızca build fazında). HUD "Ana menü" ve otomatik kayıt kullanır.
func save_game() -> bool:
	var edu := get_tree().get_first_node_in_group("education")
	return SaveGame.save(turn_manager.save_state(), edu.save_state() if edu and edu.has_method("save_state") else {})


func _on_plot_selected(plot_id: StringName, plot_kind: StringName, _is_empty: bool) -> void:
	_plot_kinds[plot_id] = plot_kind


## Sözleşme §6.3 kontrol zinciri. Geçerse &"", değilse ret nedeni.
func check_build(plot_id: StringName, building_id: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var def := Catalog.get_building(building_id)
	if def == null:
		return &"unknown_building"
	# Bina sahnesi yüklenemiyorsa hiçbir şey değişmeden reddedilir (işlem bölünmez kalır).
	if def.scene == null or not def.scene.can_instantiate():
		return &"scene_unavailable"
	if not _plot_kinds.has(plot_id):
		return &"unknown_plot"
	if GameState.get_building_on(plot_id) != &"":
		return &"plot_occupied"
	if not _plot_kinds[plot_id] in def.allowed_plot_kinds:
		return &"wrong_plot_kind"
	if GameState.plots.values().count(building_id) >= def.max_count:
		return &"max_count_reached"
	if GameState.stats.credits < def.cost:
		return &"not_enough_credits"
	return &""


func _on_build_requested(plot_id: StringName, building_id: StringName) -> void:
	var reason := check_build(plot_id, building_id)
	if reason != &"":
		EventBus.build_rejected.emit(plot_id, building_id, reason)
		return
	var def := Catalog.get_building(building_id)
	GameState.place_building(plot_id, building_id)
	GameState.log_build({"plot_id": plot_id, "building_id": building_id, "year": GameState.stats.year, "cost": def.cost})
	var deltas := def.on_build_effects.duplicate()
	deltas["credits"] = deltas.get("credits", 0) - def.cost
	GameState.apply_deltas(deltas)
	refresh_resources()
	EventBus.build_approved.emit(plot_id, building_id)


# --- TurnManager'ın sonuçları buradan yazdırılır ---

func apply_deltas(deltas: Dictionary) -> void:
	GameState.apply_deltas(deltas)


func apply_phase(phase: StringName) -> void:
	GameState.set_phase(phase)


func advance_year() -> void:
	GameState.advance_year()


func set_month(value: int) -> void:
	GameState.set_month(value)


func record_history() -> void:
	GameState.record_history()


## Enerji/su akışlarını ve sektör emisyonlarını güncel nüfus ve binalardan yeniden hesaplatıp yazar.
func refresh_resources() -> void:
	var buildings := GameState.built_definitions()
	var values := EconomySimulator.compute_resources(GameState.stats.population, buildings, Catalog.data.balance)
	values.merge(ClimateSimulator.compute_emissions(GameState.stats.population, buildings, Catalog.data.balance))
	values["climate_resilience"] = ClimateSimulator.resilience(buildings, Catalog.data.balance)
	add_business_load(values)
	GameState.set_resources(values)


## İşletmelerin enerji/su talebini, sera gazını ("industry" kalemi) ve kirlilik endekslerini ekler (v1.10).
## Küresel CO₂ (global_co2_ppm) değişmez: o gerçek ölçüm serisidir.
func add_business_load(values: Dictionary) -> void:
	var t := business_totals()
	if values.has("energy_demand"):
		values.energy_demand += t.energy
		values.water_demand += t.water
		values.renewable_share = clampf(values.renewable_energy / values.energy_demand, 0.0, 1.0) if values.energy_demand > 0.0 else 0.0
	var by_sector: Dictionary = values.emissions_by_sector
	by_sector["industry"] = t.ghg
	values.emissions_total += t.ghg
	values["air_pollution"] = t.air_pollution
	values["waste_pollution"] = t.waste_pollution


func business_totals() -> Dictionary:
	return BusinessSimulator.city_totals(GameState.businesses, Catalog.data.business_types, Catalog.data.balance)


# --- İşletmeler ve çevre denetimi (Prompt 13). Oyuncu istekleri: &"" başarı, değilse neden. ---

func _type(b: Dictionary) -> BusinessType:
	return BusinessSimulator.get_type(Catalog.data.business_types, b.business_type)


func _toast(text: String, color: Color, icon := "warning") -> void:
	get_tree().call_group("toasts", "show_toast", text, color, icon)


func _publish(b: Dictionary, sig: Signal) -> void:
	sig.emit(BusinessSimulator.visual_info(b, _type(b), Catalog.data.balance))


## Denetimin bu ay ücretsiz mi, kaç kredi mi? (0 ücretsiz)
func inspection_cost() -> int:
	var bal := Catalog.data.balance
	return 0 if GameState.inspections_used < bal.inspections_per_month else bal.extra_inspection_cost


func inspect_business(business_id: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var b := GameState.get_business(business_id)
	if b.is_empty():
		return &"unknown_business"
	var bal := Catalog.data.balance
	var reason := BusinessSimulator.inspect_block_reason(b, GameState.stats.year, GameState.month, bal)
	if reason != &"":
		return reason
	var cost := inspection_cost()
	if cost > GameState.stats.credits:
		return &"not_enough_credits"
	var record := BusinessSimulator.inspect(b, _type(b), bal, GameState.stats.year, GameState.month)
	b.inspection_history.append(record)
	b.last_inspection = {"year": GameState.stats.year, "month": GameState.month}
	if record.level > 0:
		b.violation_history.append({"inspection_id": record.inspection_id, "level": record.level, "year": record.year, "month": record.month})
	GameState.set_business(b)
	GameState.set_business_counters(GameState.business_seq, GameState.inspections_used + 1)
	if cost > 0:
		GameState.apply_deltas({"credits": -cost})
		turn_manager.note_inspection_cost(cost)
	if record.level > 0:
		_toast("%s denetlendi: %s." % [b.business_name, BusinessSimulator.LEVEL_NAMES[record.level].to_lower()], UiText.C_HIGH)
	else:
		_toast("%s denetlendi: kurallara uygun." % b.business_name, UiText.C_GOOD, "ecosystem")
	_publish(b, EventBus.business_updated)
	return &""


## Ceza: son denetimdeki ihlal için bir kez. Tutar belediye kasasına (tek para birimi: kredi) girer.
func fine_business(business_id: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var b := GameState.get_business(business_id)
	if b.is_empty():
		return &"unknown_business"
	var reason := BusinessSimulator.fine_block_reason(b, GameState.stats.year, Catalog.data.balance)
	if reason != &"":
		return reason
	var record: Dictionary = b.inspection_history[-1]
	var amount := BusinessSimulator.fine_amount(b, _type(b), record.level, Catalog.data.balance)
	record.fined = true
	record.fine_paid = amount
	b.fines_paid += 1
	b.escalation = 0
	var by_year: Dictionary = b.get("fines_by_year", {})
	by_year[GameState.stats.year] = int(by_year.get(GameState.stats.year, 0)) + 1
	b["fines_by_year"] = by_year
	GameState.set_business(b)
	GameState.apply_deltas({"credits": amount})
	turn_manager.note_fine(amount)
	_toast("%s %d kredi çevre cezası ödedi." % [b.business_name, amount], UiText.C_ACCENT, "coin")
	return &""


## Kararlar: filter, clean_energy, treatment, grace (süre ver), suspend (faaliyeti durdur). Her denetime bir karar.
func order_business(business_id: StringName, order: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var b := GameState.get_business(business_id)
	if b.is_empty():
		return &"unknown_business"
	var reason := BusinessSimulator.order_block_reason(b, order)
	if reason != &"":
		return reason
	var bal := Catalog.data.balance
	b.inspection_history[-1].order = order
	if order == &"suspend":
		b.operational_status = &"suspended"
		b.suspended_months = 0
		b.pending_improvements = []
		var t := _type(b)
		GameState.apply_deltas({"quality_of_life": -bal.quality_loss_per_100_employees * t.employees / 100.0})
		_toast("%s faaliyetini durdurdu; %d kişi işsiz kaldı." % [b.business_name, t.employees], UiText.C_HIGH)
	else:
		b.pending_improvements.append({"order": order, "months_left": int(bal.order_months.get(order, 3))})
	GameState.set_business(b)
	refresh_resources()
	_publish(b, EventBus.business_updated)
	return &""


## Durdurulan işletmeyi yeniden açar (çalışanlar geri döner, kirlilik de).
func resume_business(business_id: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var b := GameState.get_business(business_id)
	if b.is_empty() or b.operational_status != &"suspended":
		return &"not_suspended"
	b.operational_status = &"active"
	b.suspended_months = 0
	GameState.set_business(b)
	refresh_resources()
	_publish(b, EventBus.business_updated)
	return &""


## Ay geçişi (TurnManager.advance_month): denetim hakları yenilenir, kararların süresi işler, yeni işletme gelebilir.
## rolls: 0..1 rastgele sayılar (TurnManager'ın tohumlu üretecinden; kayıtla aynı sonuç).
func business_month(rolls: Array) -> void:
	var bal := Catalog.data.balance
	GameState.set_business_counters(GameState.business_seq, 0)
	var k := 3
	for b0 in GameState.businesses.duplicate(true):
		if b0.operational_status == &"closed" or (b0.pending_improvements.is_empty() and b0.operational_status != &"suspended"):
			continue
		var res := BusinessSimulator.month_tick(b0, _type(b0), bal, rolls[k % rolls.size()])
		k += 1
		var b: Dictionary = res[0]
		for e in res[1]:
			match e.kind:
				&"order_done", &"grace_improved":
					_toast("%s çevre dönüşümünü tamamladı." % b.business_name, UiText.C_GOOD, "ecosystem")
				&"grace_ignored":
					_toast("%s verilen sürede iyileştirme yapmadı; yeniden denetle." % b.business_name, UiText.C_HIGH)
				&"closed":
					_toast("%s uzun süre kapalı kaldığı için kapandı." % b.business_name, UiText.C_MUTED)
		if b.operational_status == &"closed":
			GameState.remove_business(b.business_id)
			EventBus.business_removed.emit(b.business_id, b.site_id)
		else:
			GameState.set_business(b)
			if not (res[1] as Array).is_empty():
				_publish(b, EventBus.business_updated)
	var s := BusinessSimulator.spawn(GameState.get_stats(), GameState.businesses, Catalog.data.business_types, bal, rolls[0], rolls[1], rolls[2])
	if not s.is_empty():
		var seq := GameState.business_seq + 1
		var nb := BusinessSimulator.create(s.type, s.site_id, seq, GameState.stats.year, GameState.month)
		GameState.set_business_counters(seq, GameState.inspections_used)
		GameState.set_business(nb)
		_toast("Yeni işletme kuruldu: %s (%s)." % [nb.business_name, (s.type as BusinessType).display_name], UiText.C_INFO, "city")
		_publish(nb, EventBus.business_spawned)
	refresh_resources()


## Yıl sonu: üretim dalgalanır. rolls: -1..1.
func business_year(rolls: Array) -> void:
	var k := 0
	for b0 in GameState.businesses.duplicate(true):
		var b := BusinessSimulator.year_tick(b0, Catalog.data.balance, rolls[k % rolls.size()])
		k += 1
		GameState.set_business(b)
		_publish(b, EventBus.business_updated)


func apply_climate(climate: Dictionary) -> void:
	GameState.set_climate(climate)


func set_mission_state(mission_id: StringName, state: StringName) -> void:
	GameState.set_mission_state(mission_id, state)


func record_report(report: Dictionary) -> void:
	GameState.record_report(report)


func log_crisis(result: Dictionary) -> void:
	GameState.log_crisis(result)


func add_pending(warning: Dictionary) -> void:
	GameState.add_pending(warning)


func remove_pending(warning: Dictionary) -> void:
	GameState.remove_pending(warning)
