class_name TurnManager
extends Node
## Sahip: B. Yıl sonu adımlarını sıralar ve faz makinesini tutar (mimari §3.1).
## Kendi formülü yok; hesap simülatörlerde, yazma GameController'da.

@onready var controller: GameController = get_parent()

var _start_emissions := 0.0
var _built_this_year: Array = []


func _ready() -> void:
	EventBus.build_approved.connect(func(_plot_id, building_id): _built_this_year.append(building_id))


func start_game() -> void:
	_start_emissions = GameState.stats.emissions_total
	_set_phase(&"build")
	EventBus.year_started.emit(GameState.stats.year)


func end_year() -> void:
	if GameState.phase != &"build":
		return
	# Gün 2: zamanı gelen kriz adımı buraya gelecek (crisis fazı).
	var before := GameState.get_stats()
	var eco := EconomySimulator.compute_year(before, controller.built_definitions(), Catalog.data.balance)
	controller.apply_deltas(eco.deltas)
	# Gün 2: iklim adımı ve uyarı planlama buraya gelecek.
	controller.record_history()
	var report := {
		"year": before.year,
		"stats_before": before,
		"stats_after": GameState.get_stats(),
		"income": eco.income,
		"upkeep": eco.upkeep,
		"built_this_year": _built_this_year.duplicate(),
		"crisis_results": [],
		"new_warnings": [],
	}
	_set_phase(&"report")
	EventBus.year_ended.emit(report)


func close_report() -> void:
	if GameState.phase != &"report":
		return
	if GameState.stats.year >= Catalog.data.balance.end_year:
		_set_phase(&"game_over")
		var final_stats := GameState.get_stats()
		var summary := EconomySimulator.final_score(final_stats, _start_emissions)
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
