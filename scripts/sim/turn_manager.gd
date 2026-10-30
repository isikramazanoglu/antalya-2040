class_name TurnManager
extends Node
## Sahip: B. Yıl sonu adımlarını sıralar ve faz makinesini tutar (mimari §3.1).
## Kendi formülü yok; hesap simülatörlerde, yazma GameController'da.
## Sıra: kriz(ler) → ekonomi → iklim → uyarı planlama → rapor.

@onready var controller: GameController = get_parent()

var _start_stats: Dictionary = {}
var _built_this_year: Array = []
var _crisis_queue: Array = []
var _current_crisis: Dictionary = {}
var _crisis_results: Array = []
var _stats_before: Dictionary = {}  # kriz hasarı da raporda görünsün diye yıl sonu başında alınır
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.build_approved.connect(func(_plot_id, building_id): _built_this_year.append(building_id))


func start_game() -> void:
	_start_stats = GameState.get_stats()
	_rng.seed = GameState.rng_seed
	_set_phase(&"build")
	EventBus.year_started.emit(GameState.stats.year)


func end_year() -> void:
	if GameState.phase != &"build":
		return
	var year: int = GameState.stats.year
	_crisis_queue = GameState.pending_crises.filter(func(w): return w.due_year == year)
	_crisis_results.clear()
	_stats_before = GameState.get_stats()
	_continue_year()


## Kriz varsa sıradakini başlatıp yanıt bekler; yoksa yılı bitirir.
func _continue_year() -> void:
	if not _crisis_queue.is_empty():
		_current_crisis = _crisis_queue.pop_front()
		_set_phase(&"crisis")
		EventBus.crisis_started.emit(_current_crisis.event_id, _current_crisis.risk_type, _current_crisis.severity)
		return
	_finish_year()


func on_crisis_response(event_id: StringName, response_id: StringName) -> void:
	if GameState.phase != &"crisis" or event_id != _current_crisis.get("event_id"):
		return
	var def := Catalog.get_event(event_id)
	var response := EventManager.find_response(def, response_id)
	if response == null:
		push_warning("TurnManager: bilinmeyen müdahale %s" % response_id)
		return
	var result := EventManager.resolve(def, response, GameState.built_definitions(), Catalog.data.balance)
	controller.remove_pending(_current_crisis)
	controller.apply_deltas(result.damage)
	_crisis_results.append(result)
	_current_crisis = {}
	EventBus.crisis_resolved.emit(result)
	_continue_year()


func _finish_year() -> void:
	var balance: BalanceConfig = Catalog.data.balance
	var before := _stats_before
	var buildings := GameState.built_definitions()

	var eco := EconomySimulator.compute_year(GameState.get_stats(), buildings, balance)
	controller.apply_deltas(eco.deltas)

	var climate := ClimateSimulator.compute_year(GameState.get_stats(), buildings, balance, Catalog.data.co2)
	controller.apply_climate(climate)
	controller.apply_deltas(climate.deltas)

	var warnings := EventManager.plan_warnings(before.year, Catalog.data.events, climate.risks,
			GameState.pending_crises, balance, _rng)
	for w in warnings:
		controller.add_pending(w)
		EventBus.crisis_warned.emit(w)

	var missions := MissionTracker.evaluate(Catalog.data.missions, GameState.get_stats(), GameState.missions)
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
	}
	_set_phase(&"report")
	EventBus.year_ended.emit(report)


func close_report() -> void:
	if GameState.phase != &"report":
		return
	if GameState.stats.year >= Catalog.data.balance.end_year:
		_set_phase(&"game_over")
		var final_stats := GameState.get_stats()
		var summary := EconomySimulator.final_score(final_stats, _start_stats)
		summary["final_stats"] = final_stats
		summary["history"] = GameState.history.duplicate(true)
		EventBus.game_over.emit(summary)
		return
	controller.advance_year()
	_built_this_year.clear()
	_set_phase(&"build")
	EventBus.year_started.emit(GameState.stats.year)


func _set_phase(phase: StringName) -> void:
	controller.apply_phase(phase)
	EventBus.phase_changed.emit(phase)
