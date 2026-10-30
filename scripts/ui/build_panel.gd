extends PanelContainer
## Sahip: B. Seçili arsaya yatırım listesi, bilgi kartı ve "İnşa et" (sözleşme §6.2).

var _plot_id: StringName
var _plot_kind: StringName
var _selected: BuildingDefinition


func _ready() -> void:
	hide()
	%BuildButton.pressed.connect(_on_build_pressed)
	EventBus.plot_selected.connect(_on_plot_selected)
	EventBus.plot_deselected.connect(hide)
	EventBus.build_approved.connect(_on_build_approved)
	EventBus.build_rejected.connect(func(_p, _b, reason): %ErrorLabel.text = UiText.REJECT_REASONS.get(reason, str(reason)))
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_plot_selected(plot_id: StringName, plot_kind: StringName, _is_empty: bool) -> void:
	_plot_id = plot_id
	_plot_kind = plot_kind
	_selected = null
	%ErrorLabel.text = ""
	_refresh()
	show()


func _on_stats_changed(_stats: Dictionary) -> void:
	if visible:
		_refresh()


func _on_phase_changed(phase: StringName) -> void:
	if phase != &"build":
		hide()


func _on_build_approved(plot_id: StringName, _building_id: StringName) -> void:
	if plot_id == _plot_id:
		_selected = null
		_refresh()


func _refresh() -> void:
	%PlotTitle.text = "%s · %s" % [UiText.PLOT_KINDS.get(_plot_kind, str(_plot_kind)), _plot_id]
	for child in %Cards.get_children():
		child.queue_free()

	var built_id := GameState.get_building_on(_plot_id)
	if built_id != &"":
		var built := Catalog.get_building(built_id)
		%Cards.add_child(_make_label("Bu arsada: %s" % built.display_name))
		_show_info(built)
		%BuildButton.hide()
		return

	var credits: int = GameState.stats.credits
	var options := Catalog.buildings_for_plot_kind(_plot_kind)
	if options.is_empty():
		%Cards.add_child(_make_label("Bu arsa türüne uygun yatırım yok."))
	for def in options:
		var card := Button.new()
		card.text = "%s\n%d kredi · gider %d/yıl" % [def.display_name, def.cost, def.upkeep_per_year]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.toggle_mode = true
		card.button_pressed = def == _selected
		# Parası yetmeyen kart gri görünür ama seçilebilir (sözleşme §6.2).
		card.modulate.a = 1.0 if credits >= def.cost else 0.5
		card.pressed.connect(_on_card_pressed.bind(def))
		%Cards.add_child(card)
	_show_info(_selected)
	%BuildButton.show()
	%BuildButton.disabled = _selected == null


func _on_card_pressed(def: BuildingDefinition) -> void:
	_selected = def
	%ErrorLabel.text = ""
	_refresh()


func _show_info(def: BuildingDefinition) -> void:
	if def == null:
		%InfoCardView.text = "[i]Bir yatırım seç.[/i]"
		return
	var text := "[b]%s[/b]\n%s" % [def.display_name, def.short_description]
	if def.info_card:
		text += "\n\n" + def.info_card.body
		for source in def.info_card.sources:
			text += "\n[font_size=12]Kaynak: %s[/font_size]" % source
	%InfoCardView.text = text


func _on_build_pressed() -> void:
	if _selected:
		EventBus.build_requested.emit(_plot_id, _selected.id)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
