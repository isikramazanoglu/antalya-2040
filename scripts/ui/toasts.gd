extends VBoxContainer
## Sahip: B. Geçici bildirimler (Prompt 5 §7): ekranın üst ortasında, birkaç saniye görünüp kaybolur.
## Pop-up açmaz, oyunu durdurmaz. Yalnızca EventBus'ı dinler. İnşaat retleri BuildPanel'in içinde gösterilir.

const LIFETIME := 3.2
const MAX_VISIBLE := 4

var _last_renewable := 0.0
var _water_alerted := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.build_approved.connect(_on_build_approved)
	# Rapor ve kriz panelleri ekranın ortasını kaplar; o anda bildirimler başlığı örtmesin.
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.crisis_warned.connect(_on_crisis_warned)
	EventBus.stats_changed.connect(_on_stats_changed)
	_last_renewable = GameState.stats.get("renewable_share", 0.0)


func show_toast(text: String, color: Color, icon_name := "") -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	if icon_name != "":
		var icon := TextureRect.new()
		icon.texture = UiText.icon(icon_name)
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = color
		row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.45))
	row.add_child(label)
	add_child(panel)
	while get_child_count() > MAX_VISIBLE:
		get_child(0).free()
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.tween_interval(LIFETIME)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(panel.queue_free)


func _on_phase_changed(phase: StringName) -> void:
	if phase == &"report" or phase == &"crisis":
		for child in get_children():
			child.queue_free()


func _on_build_approved(_plot_id: StringName, building_id: StringName) -> void:
	var def := Catalog.get_building(building_id)
	show_toast("%s başarıyla kuruldu." % def.display_name, UiText.C_GOOD, "build")


func _on_crisis_warned(w: Dictionary) -> void:
	var def := Catalog.get_event(w.event_id)
	show_toast(def.warning_text if def.warning_text != "" else "Uyarı: %d sonunda %s bekleniyor." % [w.due_year, def.display_name], UiText.C_HIGH, "warning")


func _on_stats_changed(stats: Dictionary) -> void:
	var share: float = stats.get("renewable_share", 0.0)
	if share > _last_renewable + 0.001:
		show_toast("Temiz elektrik payın %%%d oldu." % roundi(share * 100), UiText.C_GOOD, "energy")
	_last_renewable = share
	if stats.water_security < 35.0 and not _water_alerted:
		show_toast("Şehrin suyu azalıyor, dikkat!", UiText.C_CRIT, "water")
	_water_alerted = stats.water_security < 35.0
