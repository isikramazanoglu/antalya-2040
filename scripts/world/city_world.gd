extends Node3D
## Sahip: A. Arsa seçimi, bina yerleştirme, efekt tetikleme (mimari §2.3, sözleşme §6.1, §6.4).
## Ekip B ile yalnızca EventBus ve sözleşme §4 fonksiyonları üzerinden konuşur.
## Final sunumu (sözleşme v1.9, FINAL_VISUAL_CONTRACT.md): final_presentation_requested → FinalPresentation.

## Sözleşme §10: katman 2 = plots.
const PLOTS_LAYER_MASK := 1 << 1
const RAY_LENGTH := 1000.0
## Sözleşme §8 sahne yolu. Tanımın `scene` alanı boşsa bu yola bakılır, o da yoksa yer tutucu.
const BUILDING_SCENE_PATH := "res://scenes/buildings/b_%s.tscn"

@onready var _plots: Node3D = $Plots
@onready var _fx: DisasterFX = $DisasterFX
@onready var _camera_rig: CameraRig = $CameraRig

var _selected: BuildPlot
var _hovered: BuildPlot
var _selection_enabled := true
## Aşama sinyali bir kez geldiyse görseller onunla sürülür; crisis_started/resolved yalnızca yedektir.
var _stage_driven := false
## Final sunumu: yerleşimde olup şehirde (henüz) olmayan binaların geçici kopyaları, plot_id → Node3D.
var _stand_ins := {}
var _presentation: FinalPresentation


func _ready() -> void:
	EventBus.build_approved.connect(_on_build_approved)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.crisis_started.connect(_on_crisis_started)
	EventBus.crisis_resolved.connect(_on_crisis_resolved)
	# Sözleşme v1.3: BuildPanel kapanınca seçim bırakılır; seçili arsa varsa plot_deselected yayılır.
	EventBus.plot_deselect_requested.connect(_deselect)
	# Sözleşme v1.5: krizin aşamaları (uyarı → hazırlık → kriz → çözüldü → bitti).
	EventBus.crisis_stage_changed.connect(_on_crisis_stage_changed)
	# Sözleşme v1.9: final raporundaki "Şehrin dönüşümünü izle" düğmesi bu dinleyici varsa görünür.
	_presentation = FinalPresentation.new()
	_presentation.name = "FinalPresentation"
	add_child(_presentation)
	EventBus.final_presentation_requested.connect(_presentation.play)
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
	# Alt node'lar (DisasterFX) CityWorld'ün _ready'sinden önce de çağırabilir; @onready'e güvenme.
	for child in get_node("Plots").get_children():
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
	var scene := building_scene(building_id)
	if scene == null:
		push_warning("CityWorld: '%s' için bina sahnesi yok, yer tutucu gösteriliyor" % building_id)
	if plot.place_building(scene, animate, building_id) == null:
		return false
	# Kriz sürerken (ör. hazırlık yılında) kurulan koruyucu bina hemen görünsün.
	_fx.refresh_protection()
	return true


## Sözleşme §8: tanımın `scene` alanı, yoksa b_<id>.tscn; ikisi de yoksa null.
func building_scene(building_id: StringName) -> PackedScene:
	var def := Catalog.get_building(building_id)
	if def and def.scene:
		return def.scene
	var path := BUILDING_SCENE_PATH % building_id
	return load(path) if ResourceLoader.exists(path) else null


# --- Final sunumu (FINAL_VISUAL_CONTRACT.md §B, §C) ---

## Şehri verilen yerleşime (plot_id → building_id) göre yalnızca GÖRSEL olarak gösterir: GameState'e yazmaz,
## place_building ile kalıcı bina eklemez. Arsadaki gerçek bina gizlenir ya da gösterilir; yerleşimde olup
## şehirde olmayan (ya da farklı olan) bina geçici bir kopyayla çizilir. restore_city_state() asıl hâle döndürür.
func show_city_state(plots: Dictionary, animate: bool) -> void:
	for plot in get_plots():
		show_plot_state(plot.plot_id, _layout_id(plots, plot.plot_id), animate)


## Tek arsanın görünümü (bina inşa sırasıyla tek tek göstermek için). Görünen binayı döndürür; boşsa null.
func show_plot_state(plot_id: StringName, building_id: StringName, animate: bool) -> Node3D:
	var plot := find_plot(plot_id)
	if plot == null:
		push_warning("CityWorld: sunumda bilinmeyen arsa '%s'" % plot_id)
		return null
	var real := plot.get_building()
	var real_matches := real != null and building_id != &"" and plot.building_id == building_id
	if real:
		var was_hidden := not real.visible
		real.visible = real_matches
		if real_matches and was_hidden and animate and real.has_method("play_build_animation"):
			real.play_build_animation()
	var stand_in: Node3D = _stand_ins.get(plot_id)
	if stand_in and (real_matches or stand_in.get_meta(&"building_id") != building_id):
		_stand_ins.erase(plot_id)
		stand_in.queue_free()
		stand_in = null
	if real_matches:
		return real
	if building_id == &"" or stand_in:
		return stand_in
	if Catalog.get_building(building_id) == null or building_scene(building_id) == null:
		push_warning("CityWorld: sunumda '%s' arsasındaki '%s' tanınmadı, boş gösteriliyor" % [plot_id, building_id])
		return null
	stand_in = building_scene(building_id).instantiate()
	stand_in.set_meta(&"building_id", building_id)
	add_child(stand_in)
	stand_in.global_transform = plot.get_node("BuildingAnchor").global_transform
	_stand_ins[plot_id] = stand_in
	if animate and stand_in.has_method("play_build_animation"):
		stand_in.play_build_animation()
	return stand_in


## Sunum sonrası: gerçek binalar görünür, geçici kopyalar silinir, arsa etiketleri geri gelir.
func restore_city_state() -> void:
	for plot_id in _stand_ins:
		_stand_ins[plot_id].queue_free()
	_stand_ins.clear()
	for plot in get_plots():
		plot.set_label_visible(true)
		var real := plot.get_building()
		if real:
			real.visible = true


func set_plot_labels_visible(value: bool) -> void:
	for plot in get_plots():
		plot.set_label_visible(value)


func get_camera_rig() -> CameraRig:
	return _camera_rig


func get_disaster_fx() -> DisasterFX:
	return _fx


## Yerleşim sözlüğünde anahtar StringName ya da String olabilir.
func _layout_id(plots: Dictionary, plot_id: StringName) -> StringName:
	return StringName(plots.get(plot_id, plots.get(String(plot_id), &"")))


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
	# Arsa inşaat panelinin veya diğer panellerin arkasında kalmasın.
	_camera_rig.bring_into_view(plot.global_position)


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


func _on_crisis_stage_changed(_event_id: StringName, stage: StringName, info: Dictionary) -> void:
	_stage_driven = true
	if not _fx.set_stage(stage, info):
		return
	# Kriz başlarken etkilenen bölge ekran dışındaysa kamera yalnızca görünür olacak kadar kayar.
	if stage == &"active":
		var effect := _fx.get_effect(info.get("visual_effect_id", &""))
		if effect:
			_camera_rig.bring_into_view(effect.focus_point)


func _on_crisis_started(_event_id: StringName, risk_type: StringName, severity: float) -> void:
	if not _stage_driven:
		_fx.play(risk_type, severity)


func _on_crisis_resolved(_result: Dictionary) -> void:
	if not _stage_driven:
		_fx.stop()
