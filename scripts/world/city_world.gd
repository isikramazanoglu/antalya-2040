extends Node3D
## Sahip: A. Arsa seçimi, bina yerleştirme, efekt tetikleme (mimari §2.3, sözleşme §6.1, §6.4).
## Ekip B ile yalnızca EventBus ve sözleşme §4 fonksiyonları üzerinden konuşur.

## Sözleşme §10: katman 2 = plots.
const PLOTS_LAYER_MASK := 1 << 1
const RAY_LENGTH := 1000.0
## Sözleşme §8 sahne yolu. Tanımın `scene` alanı boşsa bu yola bakılır, o da yoksa yer tutucu.
const BUILDING_SCENE_PATH := "res://scenes/buildings/b_%s.tscn"

@onready var _plots: Node3D = $Plots
@onready var _fx: DisasterFX = $DisasterFX

var _selected: BuildPlot
var _hovered: BuildPlot
var _selection_enabled := true


func _ready() -> void:
	EventBus.build_approved.connect(_on_build_approved)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.crisis_started.connect(_on_crisis_started)
	EventBus.crisis_resolved.connect(_on_crisis_resolved)
	# Sahne yeniden açıldıysa GameState'teki binaları animasyonsuz geri kur.
	for plot in get_plots():
		var building_id := GameState.get_building_on(plot.plot_id)
		if building_id != &"":
			place_building(plot.plot_id, building_id, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_plot_at(event.position) if _selection_enabled else null)
	elif event.is_action_pressed("select"):
		if not _selection_enabled:
			return
		var plot := _plot_at(event.position)
		if plot:
			_select(plot)
		else:
			_deselect()
	elif event.is_action_pressed("cancel"):
		_deselect()


func get_plots() -> Array[BuildPlot]:
	var result: Array[BuildPlot] = []
	for child in _plots.get_children():
		if child is BuildPlot:
			result.append(child)
	return result


func find_plot(plot_id: StringName) -> BuildPlot:
	var node := _plots.get_node_or_null(NodePath(String(plot_id)))
	return node as BuildPlot


## Arsa türü (sözleşme §7); arsa yoksa &"".
func get_plot_kind(plot_id: StringName) -> StringName:
	var plot := find_plot(plot_id)
	return plot.plot_kind if plot else &""


## Şehirde bu arsada bina görünüyor mu. Bilinmeyen arsa için false.
func is_plot_occupied(plot_id: StringName) -> bool:
	var plot := find_plot(plot_id)
	return plot != null and plot.is_occupied()


## Onaylanmış binayı arsaya yalnızca görsel olarak koyar; bütçe, gösterge ve tur durumuna dokunmaz.
## Arsa yoksa veya doluysa false döner ve uyarı yazar. Sahne bulunamazsa yer tutucu kutu konur (sözleşme §4).
func place_building(plot_id: StringName, building_id: StringName, animate := true) -> bool:
	var plot := find_plot(plot_id)
	if plot == null:
		push_warning("CityWorld: '%s' arsası yok, '%s' yerleştirilmedi" % [plot_id, building_id])
		return false
	if plot.is_occupied():
		push_warning("CityWorld: '%s' arsası dolu, '%s' yerleştirilmedi" % [plot_id, building_id])
		return false
	var def := Catalog.get_building(building_id)
	var scene: PackedScene = def.scene if def else null
	if scene == null:
		var path := BUILDING_SCENE_PATH % building_id
		if ResourceLoader.exists(path):
			scene = load(path)
		else:
			push_warning("CityWorld: '%s' için bina sahnesi yok, yer tutucu gösteriliyor" % building_id)
	return plot.place_building(scene, animate) != null


# --- Seçim ---

func _plot_at(screen_pos: Vector2) -> BuildPlot:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, PLOTS_LAYER_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return (hit.collider as Node).get_parent() as BuildPlot


func _select(plot: BuildPlot) -> void:
	if _selected and _selected != plot:
		_selected.set_selected(false)
	_selected = plot
	plot.set_selected(true)
	EventBus.plot_selected.emit(plot.plot_id, plot.plot_kind, plot.is_empty())


func _deselect() -> void:
	if _selected == null:
		return
	_selected.set_selected(false)
	_selected = null
	EventBus.plot_deselected.emit()


func _set_hovered(plot: BuildPlot) -> void:
	if plot == _hovered:
		return
	if _hovered:
		_hovered.set_hovered(false)
	_hovered = plot
	if plot:
		plot.set_hovered(true)


# --- EventBus ---

## Sözleşme §3.2: faz build değilse seçim kapanır, seçili arsa varsa plot_deselected.
func _on_phase_changed(phase: StringName) -> void:
	_selection_enabled = phase == &"build"
	if not _selection_enabled:
		_deselect()
		_set_hovered(null)


func _on_build_approved(plot_id: StringName, building_id: StringName) -> void:
	place_building(plot_id, building_id)


func _on_crisis_started(_event_id: StringName, risk_type: StringName, severity: float) -> void:
	_fx.play(risk_type, severity)


func _on_crisis_resolved(_result: Dictionary) -> void:
	_fx.stop()
