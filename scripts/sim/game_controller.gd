class_name GameController
extends Node
## Sahip: B. Oyuncu taleplerini karşılar; GameState'e yazan tek modül (mimari §3).

@onready var turn_manager: TurnManager = $TurnManager

var _plot_kinds: Dictionary = {}  # plot_id -> plot_kind, plot_selected'dan öğrenilir


func _ready() -> void:
	EventBus.plot_selected.connect(_on_plot_selected)
	EventBus.build_requested.connect(_on_build_requested)
	EventBus.end_turn_requested.connect(turn_manager.end_year)
	EventBus.report_closed.connect(turn_manager.close_report)
	EventBus.crisis_response_chosen.connect(turn_manager.on_crisis_response)
	# UI node'ları _ready'lerini bitirsin, ilk year_started'ı kaçırmasın.
	turn_manager.start_game.call_deferred()


func _on_plot_selected(plot_id: StringName, plot_kind: StringName, _is_empty: bool) -> void:
	_plot_kinds[plot_id] = plot_kind


## Sözleşme §6.3 kontrol zinciri. Geçerse &"", değilse ret nedeni.
func check_build(plot_id: StringName, building_id: StringName) -> StringName:
	if GameState.phase != &"build":
		return &"wrong_phase"
	var def := Catalog.get_building(building_id)
	if def == null:
		return &"unknown_building"
	if GameState.get_building_on(plot_id) != &"":
		return &"plot_occupied"
	if not _plot_kinds.get(plot_id, &"") in def.allowed_plot_kinds:
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


func record_history() -> void:
	GameState.record_history()


## Enerji ve su akışlarını güncel nüfus ve binalardan yeniden hesaplatıp yazar.
func refresh_resources() -> void:
	GameState.set_resources(EconomySimulator.compute_resources(GameState.stats.population, GameState.built_definitions(), Catalog.data.balance))


func apply_climate(climate: Dictionary) -> void:
	GameState.set_climate(climate)


func set_mission_state(mission_id: StringName, state: StringName) -> void:
	GameState.set_mission_state(mission_id, state)


func add_pending(warning: Dictionary) -> void:
	GameState.add_pending(warning)


func remove_pending(warning: Dictionary) -> void:
	GameState.remove_pending(warning)
