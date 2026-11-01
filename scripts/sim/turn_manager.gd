class_name TurnManager
extends Node
## Sahip: B. Yıl sonu adımlarını sıralar ve faz makinesini tutar (mimari §3.1).
## Kendi formülü yok; hesap simülatörlerde, yazma GameController'da.
## Sıra: kriz(ler) → ekonomi → iklim → uyarı planlama → rapor.

@onready var controller: GameController = get_parent()

var _start_stats: Dictionary = {}
var _start_plots: Dictionary = {}  # 2040 başındaki yerleşim (final görsel sözleşmesi city_2040)
var _built_this_year: Array = []
var _crisis_queue: Array = []
var _current_crisis: Dictionary = {}
var _crisis_results: Array = []
var _stats_before: Dictionary = {}  # yıl başı (Ocak) değerleri; rapor bütün yılı (yatırım, aylık bütçe, kriz) anlatır
var _ending_year := false  # kriz kuyruğu bitince yıl kapanır mı (yıl sonu) yoksa ay akmaya devam mı eder
var _month_credits := 0  # bu yıl aylık olarak verilen bütçe; yıl sonunda yıllık hesaptan düşülür
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.build_approved.connect(func(_plot_id, building_id): _built_this_year.append(building_id))


## Sözleşme v1.5/v1.6: aşama bilgisini görsel sisteme bildirir. Koruma o anki binalardan EventManager ile hesaplanır.
const STAGE_PROGRESS := {&"warning": 0.0, &"preparation": 0.25, &"active": 0.5, &"resolved": 0.75, &"ended": 1.0}


func _emit_stage(warning: Dictionary, stage: StringName) -> void:
	var def := Catalog.get_event(warning.event_id)
	var a := EventManager.assess(def, warning.severity, GameState.get_stats(), GameState.built_definitions(), Catalog.data.balance)
	EventBus.crisis_stage_changed.emit(warning.event_id, stage, {
		"severity": warning.severity,
		"due_year": warning.due_year,
		"visual_effect_id": def.visual_effect_id,
		"affected_area": def.affected_area,
		"affected_plot_kinds": def.affected_plot_kinds.duplicate(),
		"progress": STAGE_PROGRESS[stage],
		"mitigation": a.mitigation,  # v1.6
		"advantages": a.advantages,  # v1.6
	})


func start_game() -> void:
	controller.refresh_resources()  # başlangıç kaydında enerji/su akışları da dolu olsun
	_start_stats = GameState.get_stats()
	_start_plots = GameState.plots.duplicate()
	_rng.seed = GameState.rng_seed
	_reset_year()
	_set_phase(&"build")
	EventBus.year_started.emit(GameState.stats.year)


func _reset_year() -> void:
	_crisis_results.clear()
	_stats_before = GameState.get_stats()
	_month_credits = 0


## Takvim bir ay ilerler (MonthClock). Aralık bitince yıl kapanır. Ay geçerken yıllık net bütçenin
## 1/12'si verilir (yıl sonunda kalanı); o ay gelen krizler başlar, çözülünce takvim kaldığı yerden akar.
func advance_month() -> void:
	if GameState.phase != &"build":
		return
	if GameState.month >= 12:
		end_year()
		return
	var eco := EconomySimulator.compute_year(GameState.get_stats(), GameState.built_definitions(), Catalog.data.balance)
	var monthly := roundi(eco.deltas.get("credits", 0) / 12.0)
	_month_credits += monthly
	controller.apply_deltas({"credits": monthly})
	controller.set_month(GameState.month + 1)
	var year: int = GameState.stats.year
	_crisis_queue = GameState.pending_crises.filter(func(w): return w.due_year == year and _crisis_month(w) == GameState.month)
	if not _crisis_queue.is_empty():
		_ending_year = false
		_continue_year()


func _crisis_month(warning: Dictionary) -> int:
	var def := Catalog.get_event(warning.event_id)
	return def.month if def else 12


## Yıl sonuna atlar (HUD "Yıl sonuna atla" ya da Aralık bitişi): yılın kalan krizleri sırayla gelir, sonra rapor.
func end_year() -> void:
	if GameState.phase != &"build":
		return
	var year: int = GameState.stats.year
	_crisis_queue = GameState.pending_crises.filter(func(w): return w.due_year == year)
	_ending_year = true
	_continue_year()


## Kriz varsa sıradakini başlatıp yanıt bekler; yoksa yılı bitirir.
func _continue_year() -> void:
	if not _crisis_queue.is_empty():
		var crisis: Dictionary = _crisis_queue.pop_front()
		_current_crisis = crisis
		_set_phase(&"crisis")
		# Yerel kopya: bir dinleyici crisis_started içinde hemen yanıt verirse _current_crisis boşalır.
		_emit_stage(crisis, &"active")
		EventBus.crisis_started.emit(crisis.event_id, crisis.risk_type, crisis.severity)
		return
	if _ending_year:
		_finish_year()
	else:
		_set_phase(&"build")  # yıl ortası kriz bitti; takvim akmaya devam eder


func on_crisis_response(event_id: StringName, response_id: StringName) -> void:
	if GameState.phase != &"crisis" or event_id != _current_crisis.get("event_id"):
		return
	var def := Catalog.get_event(event_id)
	var response := EventManager.find_response(def, response_id)
	var buildings := GameState.built_definitions()
	# Geçersiz seçim (altyapı yok, bütçe yetmiyor) durumu değiştirmeden yok sayılır; kriz açık kalır.
	var reason := EventManager.validate(def, response, buildings, GameState.stats.credits)
	if reason != &"":
		push_warning("TurnManager: müdahale reddedildi %s (%s)" % [response_id, reason])
		return
	var result := EventManager.resolve(def, response, _current_crisis.severity, GameState.get_stats(), buildings, Catalog.data.balance)
	var resolved := _current_crisis
	controller.remove_pending(_current_crisis)
	controller.apply_deltas(result.damage)
	controller.refresh_resources()
	_crisis_results.append(result)
	var logged := result.duplicate(true)
	logged["year"] = GameState.stats.year
	controller.log_crisis(logged)
	_current_crisis = {}
	EventBus.crisis_resolved.emit(result)
	_emit_stage(resolved, &"resolved")
	_continue_year()


func _finish_year() -> void:
	var balance: BalanceConfig = Catalog.data.balance
	var before := _stats_before
	var buildings := GameState.built_definitions()

	var eco := EconomySimulator.compute_year(GameState.get_stats(), buildings, balance)
	var deltas: Dictionary = eco.deltas.duplicate()
	deltas["credits"] = deltas.get("credits", 0) - _month_credits  # ay ay verilen kısım tekrar verilmez
	controller.apply_deltas(deltas)
	controller.refresh_resources()  # nüfus değişti, talep de değişir

	var climate := ClimateSimulator.compute_year(GameState.get_stats(), buildings, balance, Catalog.data.co2)
	controller.apply_climate(climate)
	controller.apply_deltas(climate.deltas)

	var warnings := EventManager.plan_warnings(before.year, Catalog.data.events, climate.risks,
			GameState.pending_crises, balance, _rng)
	for w in warnings:
		controller.add_pending(w)
		EventBus.crisis_warned.emit(w)
		_emit_stage(w, &"warning")

	var context := {"built": GameState.plots.values(), "crisis_results": _crisis_results}
	var missions := MissionTracker.evaluate(Catalog.data.missions, GameState.get_stats(), GameState.missions, context)
	for id in missions.completed:
		controller.set_mission_state(id, &"done")
	for id in missions.failed:
		controller.set_mission_state(id, &"failed")
	if missions.reward > 0:
		controller.apply_deltas({"credits": missions.reward})

	controller.record_history()
	var report := {
		"year": before.year,
		"stats_before": before,
		"stats_after": GameState.get_stats(),
		"income": eco.income,
		"upkeep": eco.upkeep,
		"built_this_year": _built_this_year.duplicate(),
		"crisis_results": _crisis_results.duplicate(true),
		"new_warnings": warnings,
		"missions": missions,
		"investment_cost": GameState.build_log.filter(func(e): return e.year == before.year).reduce(func(acc, e): return acc + e.cost, 0),  # v1.9
	}
	controller.record_report(report)
	_set_phase(&"report")
	EventBus.year_ended.emit(report)


func close_report() -> void:
	if GameState.phase != &"report":
		return
	for r in _crisis_results:
		_emit_stage({"event_id": r.event_id, "severity": r.severity, "due_year": GameState.stats.year}, &"ended")
	if GameState.stats.year >= Catalog.data.balance.end_year:
		_set_phase(&"game_over")
		var final_stats := GameState.get_stats()
		var ev := FinalEvaluator.evaluate(_start_stats, final_stats, GameState.history, GameState.year_reports,
				GameState.crisis_log, GameState.build_log, Catalog.data.balance)
		var summary := {
			"score": ev.overall,
			"grade": ev.grade,
			"emission_reduction_pct": ev.emission_reduction_pct,
			"final_stats": final_stats,
			"history": GameState.history.duplicate(true),
			"start_stats": _start_stats.duplicate(true),  # v1.7
			"evaluation": ev,  # v1.9
			"city_2040": {"year": Catalog.data.balance.start_year, "plots": _start_plots.duplicate()},  # v1.9
			"city_2052": {"year": final_stats.year, "plots": GameState.plots.duplicate(), "builds": GameState.build_log.duplicate(true)},  # v1.9
		}
		EventBus.game_over.emit(summary)
		return
	controller.advance_year()
	_built_this_year.clear()
	_reset_year()
	_set_phase(&"build")
	EventBus.year_started.emit(GameState.stats.year)
	for w in GameState.pending_crises:
		if w.due_year == GameState.stats.year:
			_emit_stage(w, &"preparation")


func _set_phase(phase: StringName) -> void:
	controller.apply_phase(phase)
	EventBus.phase_changed.emit(phase)
