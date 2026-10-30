extends PanelContainer
## Sahip: B. İnşaat ve yatırım menüsü (Prompt 5 §4-6). GameState'e yazmaz; yalnızca build_requested yayar.
## Arsa seçilince o arsaya uygun yatırımları, "İnşaat" düğmesiyle açılınca bütün yatırımları (arsa seçmeden) listeler.

var _plot_id: StringName = &""
var _plot_kind: StringName = &""
var _selected: BuildingDefinition


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("build_panel")
	hide()
	%BuildButton.pressed.connect(_on_build_pressed)
	%CloseButton.pressed.connect(_close_by_player)
	%DetailToggle.toggled.connect(func(on): %DetailBody.visible = on)
	EventBus.plot_selected.connect(_on_plot_selected)
	EventBus.plot_deselected.connect(close)
	EventBus.build_approved.connect(_on_build_approved)
	EventBus.build_rejected.connect(func(_p, _b, reason): _show_error(UiText.REJECT_REASONS.get(reason, str(reason))))
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_stats_changed(_stats: Dictionary) -> void:
	if visible:
		_refresh()


func _on_phase_changed(phase: StringName) -> void:
	if phase != &"build":
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		_close_by_player()
		get_viewport().set_input_as_handled()


## HUD'daki "İnşaat" düğmesi: arsa seçmeden bütün yatırımları incele.
func open() -> void:
	_plot_id = &""
	_plot_kind = &""
	_selected = null
	_open_panel()


func close() -> void:
	hide()


## Oyuncu paneli kendisi kapattı (× veya Esc): şehirdeki arsa vurgusu da bırakılsın (sözleşme v1.3).
func _close_by_player() -> void:
	close()
	if _plot_id != &"":
		EventBus.plot_deselect_requested.emit()


func _on_plot_selected(plot_id: StringName, plot_kind: StringName, _is_empty: bool) -> void:
	get_tree().call_group("ui_panel", "close")
	_plot_id = plot_id
	_plot_kind = plot_kind
	_selected = null
	_open_panel()


func _open_panel() -> void:
	%ErrorLabel.text = ""
	%DetailToggle.button_pressed = false
	_refresh()
	if not visible:
		UiText.pop_in(self)


func _on_build_approved(plot_id: StringName, _building_id: StringName) -> void:
	if plot_id == _plot_id:
		_selected = null
		_refresh()


func _show_error(text: String) -> void:
	%ErrorLabel.text = text
	%ErrorLabel.visible = text != ""


func _refresh() -> void:
	for child in %Cards.get_children():
		child.queue_free()
	var built_id := GameState.get_building_on(_plot_id) if _plot_id != &"" else &""
	if _plot_id == &"":
		%Title.text = "Yatırımlar"
		%Hint.text = "Yatırım yapmak için şehirde boş bir arsaya tıkla. Burada bütün yatırımları inceleyebilirsin."
	else:
		%Title.text = "%s · %s" % [UiText.PLOT_KINDS.get(_plot_kind, str(_plot_kind)), _plot_id]
		%Hint.text = "Bu arsada: %s" % Catalog.get_building(built_id).display_name if built_id != &"" else "Bu arsaya uygun yatırımlar"

	var options: Array[BuildingDefinition] = Catalog.data.buildings if _plot_id == &"" else Catalog.buildings_for_plot_kind(_plot_kind)
	if built_id != &"":
		options = [Catalog.get_building(built_id)]
		_selected = options[0]
	for def in options:
		%Cards.add_child(_make_card(def))
	_show_detail(_selected)
	_update_build_button(built_id)


func _make_card(def: BuildingDefinition) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_pressed = def == _selected
	card.custom_minimum_size = Vector2(0, 112)
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_on_card_pressed.bind(def))
	# Seçili kart turkuaz dolgu yerine turkuaz kenarlıkla belirir; içindeki yazılar okunur kalır.
	var picked := StyleBoxFlat.new()
	picked.bg_color = Color(0.1, 0.24, 0.27)
	picked.set_border_width_all(2)
	picked.border_color = UiText.C_ACCENT
	picked.set_corner_radius_all(6)
	card.add_theme_stylebox_override("pressed", picked)
	card.add_theme_stylebox_override("hover_pressed", picked)
	card.mouse_entered.connect(func(): card.create_tween().tween_property(card, "modulate", Color(1.08, 1.08, 1.08, card.modulate.a), 0.1))
	card.mouse_exited.connect(func(): card.create_tween().tween_property(card, "modulate", Color(1, 1, 1, card.modulate.a), 0.1))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var thumb := TextureRect.new()
	thumb.texture = def.icon
	thumb.custom_minimum_size = Vector2(128, 88)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(_label(def.display_name, 17, Color.WHITE))
	text.add_child(_label(def.short_description, 14, UiText.C_MUTED, true))
	var kinds := PackedStringArray()
	for k in def.allowed_plot_kinds:
		kinds.append(UiText.PLOT_KIND_SHORT.get(k, str(k)))
	var affordable: bool = GameState.stats.credits >= def.cost
	var price := _label("%s kredi · gider %d/yıl · %s" % [UiText.thousands(def.cost), def.upkeep_per_year, ", ".join(kinds)], 14,
			Color.WHITE if affordable else UiText.C_CRIT)
	text.add_child(price)
	var chips := PackedStringArray()
	for e in effects(def):
		chips.append(e[0])
	text.add_child(_label("  ·  ".join(chips), 13, UiText.C_ACCENT, true))
	if not affordable:
		card.tooltip_text = "Bütçe yetmiyor"
		card.modulate.a = 0.6
	return card


func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 240
	return l


## Kartta ve ayrıntıda gösterilen etkiler: [metin, olumlu mu]. Hepsi veriden okunur, hesap yapılmaz.
static func effects(def: BuildingDefinition) -> Array:
	var out := []
	if def.energy_production > 0.0:
		out.append(["Yenilenebilir enerji +%d" % def.energy_production, true])
	if def.energy_consumption != 0.0:
		out.append(["Enerji talebi %+d" % def.energy_consumption, def.energy_consumption < 0.0])
	if def.water_production > 0.0:
		out.append(["Su arzı +%d" % def.water_production, true])
	if def.water_consumption != 0.0:
		out.append(["Su talebi %+d" % def.water_consumption, def.water_consumption < 0.0])
	for key in def.on_build_effects:
		var v: float = def.on_build_effects[key]
		out.append(["%s %s" % [UiText.STAT_NAMES.get(key, key), UiText.format_delta(v)], v > 0.0])
	for sector in def.emission_multipliers:
		var m: float = def.emission_multipliers[sector]
		out.append(["%s emisyonu %+d%%" % [UiText.SECTOR_NAMES.get(sector, sector), roundi(m * 100)], m < 0.0])
	for risk in def.risk_reduction:
		out.append(["%s hasarı -%d%%" % [UiText.RISK_NAMES.get(risk, risk), roundi(def.risk_reduction[risk] * 100)], true])
	return out


func _on_card_pressed(def: BuildingDefinition) -> void:
	_selected = def
	_show_error("")
	_refresh()


func _show_detail(def: BuildingDefinition) -> void:
	%Detail.visible = def != null
	if def == null:
		return
	var card := def.info_card
	var t := "[b]%s[/b]   [color=#4dd9d1]%s[/color]\n" % [def.display_name, UiText.CATEGORY_THEME.get(def.category, "")]
	if card and card.benefit != "":
		t += "[b]Temel fayda:[/b] %s\n[b]İklim bağlantısı:[/b] %s\n[b]Stratejik avantaj:[/b] %s\n" % [card.benefit, card.climate_link, card.strategic]
	t += "\n"
	for e in effects(def):
		t += "[color=%s]%s %s[/color]\n" % [("#6bd185" if e[1] else "#ff8c73"), "+" if e[1] else "−", e[0]]
	t += "[font_size=13][color=#b8c4c2]Değerler oyun dengeleme parametresidir, gerçek ölçüm değildir.[/color][/font_size]"
	%DetailSummary.text = t
	var body := card.body if card else ""
	if card:
		for source in card.sources:
			body += "\n[font_size=12]Kaynak: %s[/font_size]" % source
	%DetailBody.text = body
	%DetailToggle.visible = body != ""
	%DetailBody.visible = %DetailToggle.button_pressed and body != ""


func _update_build_button(built_id: StringName) -> void:
	var button: Button = %BuildButton
	button.visible = _plot_id != &"" and built_id == &""
	button.disabled = _selected == null
	if _selected == null:
		button.text = "Bir yatırım seç"
		return
	button.text = "İnşa et · %s kredi" % UiText.thousands(_selected.cost)
	if GameState.stats.credits < _selected.cost:
		button.disabled = true
		_show_error("Bu yatırımı gerçekleştirmek için yeterli bütçen yok (%s / %s kredi)." % [UiText.thousands(GameState.stats.credits), UiText.thousands(_selected.cost)])


func _on_build_pressed() -> void:
	if _selected and _plot_id != &"":
		EventBus.build_requested.emit(_plot_id, _selected.id)
