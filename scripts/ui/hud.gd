extends Control
## Sahip: B. Ana HUD (Prompt 5 §3): üst bilgi çubuğu, sol kaynak paneli, alt menü.
## Yalnızca GameState'i okur; yazmaz. Paneller "ui_panel" grubundadır, aynı anda biri açık kalır.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
## [anahtar, başlık, ikon]
const RESOURCES := [
	["water_security", "Su güvenliği", "water"],
	["energy_security", "Enerji dengesi", "energy"],
	["quality_of_life", "Yaşam kalitesi", "quality"],
	["ecosystem_health", "Ekosistem sağlığı", "ecosystem"],
]

var _cards: Dictionary = {}  # anahtar -> {"value": Label, "status": Label, "bar": ProgressBar, "detail": Label}
var _shown_credits := 0.0
var _credits_tween: Tween
var _last_net := 0  # son yıl sonu net bakiyesi (gelir - gider)
var _has_report := false  # "Son rapor" ilk yıl sonundan önce kapalı


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_cards()
	%EndTurnButton.pressed.connect(EventBus.end_turn_requested.emit)
	%BuildMenuButton.pressed.connect(_open_panel.bind("build_panel"))
	%LabButton.pressed.connect(_open_panel.bind("climate_lab"))
	%CityInfoButton.pressed.connect(_open_panel.bind("city_info"))
	%ReportButton.pressed.connect(_open_panel.bind("year_report"))
	%SettingsButton.pressed.connect(_open_panel.bind("settings"))
	%MenuButton.pressed.connect(%QuitConfirm.popup_centered)
	%QuitConfirm.confirmed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	%CollapseButton.pressed.connect(_toggle_resources)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.year_ended.connect(_on_year_ended)
	EventBus.crisis_warned.connect(func(_w): _refresh_warnings())
	EventBus.crisis_resolved.connect(func(_r): _refresh_warnings())
	EventBus.year_started.connect(func(_y): _refresh_missions())
	_shown_credits = GameState.stats.credits
	_on_stats_changed(GameState.get_stats())
	_refresh_warnings()
	_refresh_missions()


func _open_panel(panel_name: String) -> void:
	get_tree().call_group("ui_panel", "close")
	get_tree().call_group(panel_name, "open")


func _on_phase_changed(phase: StringName) -> void:
	var building := phase == &"build"
	%EndTurnButton.disabled = not building
	%BuildMenuButton.disabled = not building
	%ReportButton.disabled = not building or not _has_report


func _on_year_ended(report: Dictionary) -> void:
	_last_net = report.income - report.upkeep
	_has_report = true


func _toggle_resources() -> void:
	%ResourceList.visible = not %ResourceList.visible
	%CollapseButton.text = "–" if %ResourceList.visible else "+"


# --- Üst çubuk ve kaynaklar ---

func _build_resource_cards() -> void:
	for r in RESOURCES:
		_cards[r[0]] = _make_card(r[1], r[2])
	_cards["economy"] = _make_card("Ekonomik durum", "economy")


func _make_card(title: String, icon_name: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = UiText.icon(icon_name)
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UiText.C_ACCENT
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 20)
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.custom_minimum_size.x = 78
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for c in [icon, name_label, value, status]:
		row.add_child(c)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", UiText.C_MUTED)
	detail.visible = false
	for c in [row, bar, detail]:
		box.add_child(c)
	%ResourceList.add_child(box)
	return {"value": value, "status": status, "bar": bar, "detail": detail}


func _set_card(key: String, value: float, shown: String, detail := "") -> void:
	var card: Dictionary = _cards[key]
	var st := UiText.status(value)
	card.value.text = shown
	card.status.text = st[0]
	card.status.add_theme_color_override("font_color", st[1])
	card.bar.value = value
	card.bar.add_theme_stylebox_override("fill", _bar_fill(st[1]))
	card.detail.text = detail
	card.detail.visible = detail != ""


func _bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb


func _on_stats_changed(stats: Dictionary) -> void:
	var b: BalanceConfig = Catalog.data.balance
	%YearValue.text = str(stats.year)
	%YearProgress.max_value = b.end_year - b.start_year + 1
	%YearProgress.value = stats.year - b.start_year + 1
	%YearProgress.tooltip_text = "%d / %d. yıl" % [stats.year - b.start_year + 1, b.end_year - b.start_year + 1]
	%PopulationValue.text = UiText.thousands(stats.population)
	_animate_credits(stats.credits)

	for r in RESOURCES:
		var detail := ""
		if r[0] == "energy_security":
			detail = "Yenilenebilir %d / talep %d · pay %%%d" % [roundi(stats.renewable_energy), roundi(stats.energy_demand), roundi(stats.renewable_share * 100)]
		elif r[0] == "water_security":
			detail = "Su arzı %d / talep %d · denge %+d" % [roundi(stats.water_supply), roundi(stats.water_demand), roundi(stats.water_supply - stats.water_demand)]
		_set_card(r[0], stats[r[0]], str(roundi(stats[r[0]])), detail)

	# Ekonomik durum: kasanın en ucuz yatırıma yetmesi ve son yılın net bakiyesi.
	var cheapest := _cheapest_available_cost()
	var econ := 80.0 if stats.credits >= cheapest else (40.0 if stats.credits >= 0 else 10.0)
	_set_card("economy", econ, UiText.thousands(stats.credits),
			("Geçen yıl net %s · " % UiText.format_delta(_last_net) if _has_report else "") + ("en ucuz yatırım %d" % cheapest if cheapest > 0 else "bütün yatırımlar yapıldı"))


func _cheapest_available_cost() -> int:
	var built := GameState.plots.values()
	var cheapest := 0
	for def in Catalog.data.buildings:
		if built.count(def.id) < def.max_count and (cheapest == 0 or def.cost < cheapest):
			cheapest = def.cost
	return cheapest


## Bütçe sayısı yumuşakça yeni değere akar; yetmiyorsa kırmızı.
func _animate_credits(target: int) -> void:
	var low := target < _cheapest_available_cost() or target < 0
	%CreditsValue.add_theme_color_override("font_color", UiText.C_CRIT if low else Color.WHITE)
	%CreditsValue.tooltip_text = "Kasa en ucuz yatırıma yetmiyor." if low else ""
	if _credits_tween:
		_credits_tween.kill()
	_credits_tween = create_tween()
	_credits_tween.tween_method(func(v: float): %CreditsValue.text = UiText.thousands(roundi(v)), _shown_credits, float(target), 0.45)
	_shown_credits = target


# --- Uyarılar ve görevler ---

func _refresh_warnings() -> void:
	for child in %Warnings.get_children():
		child.queue_free()
	for w in GameState.pending_crises:
		var def := Catalog.get_event(w.event_id)
		var label := _side_label("Uyarı · %d sonunda %s" % [w.due_year, def.display_name if def else str(w.event_id)], UiText.C_HIGH)
		%Warnings.add_child(label)
		var t := label.create_tween().set_loops(3)
		t.tween_property(label, "modulate:a", 0.45, 0.35)
		t.tween_property(label, "modulate:a", 1.0, 0.35)


func _refresh_missions() -> void:
	for child in %Missions.get_children():
		child.queue_free()
	var stats := GameState.get_stats()
	for m in Catalog.data.missions:
		if GameState.missions.get(m.id, &"active") != &"active":
			continue
		var label := _side_label("Görev · %s %s%d · şu an %d · son yıl %d · +%d" % [
				UiText.STAT_NAMES.get(m.stat, m.stat), "en çok " if m.at_most else "", roundi(m.target), roundi(stats[m.stat]), m.deadline_year, m.reward_credits], Color.WHITE)
		label.tooltip_text = m.description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		%Missions.add_child(label)


## Şehrin üstünde açık zeminde de okunsun diye koyu kenar çizgili etiket.
func _side_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.12, 0.9))
	return label
