extends Control
## Sahip: B. Kriz paneli (Prompt 7A §10): risk seviyesi, hasar dökümü, yatırım avantajları, müdahale seçimi ve onay.
## Hesap yapmaz: EventManager'ın salt okunur fonksiyonlarını gösterir; seçimi crisis_response_chosen ile bildirir.

var _def: EventDefinition
var _severity := 0.0
var _assessment: Dictionary = {}
var _selected: CrisisResponse


func _ready() -> void:
	hide()
	%ConfirmButton.pressed.connect(_on_confirm)
	EventBus.crisis_started.connect(_on_crisis_started)
	EventBus.crisis_resolved.connect(func(_result): hide())


func _on_crisis_started(event_id: StringName, _risk_type: StringName, severity: float) -> void:
	_def = Catalog.get_event(event_id)
	_severity = severity
	_selected = null
	var buildings := GameState.built_definitions()
	_assessment = EventManager.assess(_def, severity, GameState.get_stats(), buildings, Catalog.data.balance)
	%Title.text = _def.display_name
	var level := UiText.status(100.0 - severity * 100.0)  # şiddet yüksekse durum kötü
	%Risk.text = "Risk seviyesi: %s (%%%d)" % [level[0], roundi(severity * 100)]
	%Risk.add_theme_color_override("font_color", level[1])

	var t := _def.description
	if _def.info_card:
		t += "\n[i]%s[/i]" % _def.info_card.body
	t += "\n\n[b]Hasarı belirleyenler[/b]  [color=#b8c4c2](oyun parametreleri)[/color]\n"
	t += "Tehlike ×%.2f · Maruziyet (nüfus) ×%.2f · Hassasiyet ×%.2f · Uyum kapasitesi −%%%d\n" % [
		_assessment.hazard, _assessment.exposure, _assessment.vulnerability, roundi(_assessment.mitigation * 100)]
	var adv := PackedStringArray()
	for id in _assessment.advantages:
		adv.append(Catalog.get_building(id).display_name)
	t += "[b]Yatırım avantajların:[/b] %s" % (", ".join(adv) if adv.size() > 0 else "[color=#ff8c73]yok, bu krize hazırlıksızsın[/color]")
	%Description.text = t

	for child in %Responses.get_children():
		child.queue_free()
	var credits: int = GameState.stats.credits
	var group := ButtonGroup.new()
	for response in EventManager.available_responses(_def, buildings):
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tag := ""
		if response.required_building != &"":
			tag = "   [altyapı: %s]" % Catalog.get_building(response.required_building).display_name
		button.text = "%s · %s%s" % [response.label, "ücretsiz" if response.cost == 0 else "%d kredi" % response.cost, tag]
		button.tooltip_text = response.description
		if response.cost > credits:
			button.disabled = true
			button.tooltip_text += "\nBütçe yetmiyor."
		button.pressed.connect(_on_response_pressed.bind(response))
		%Responses.add_child(button)
	%Preview.text = "[color=#b8c4c2]Bir müdahale seç; olası etkileri burada görünür.[/color]"
	%ConfirmButton.disabled = true
	UiText.pop_in(self)


func _on_response_pressed(response: CrisisResponse) -> void:
	_selected = response
	var damage := EventManager.preview(_def, response, _assessment)
	var parts := PackedStringArray()
	for key in damage:
		var v: float = damage[key]
		parts.append("[color=#%s]%s %s[/color]" % [UiText.delta_color(v).to_html(false), UiText.STAT_NAMES.get(key, key), UiText.format_delta(v)])
	%Preview.text = "[b]Olası etkiler:[/b] " + ("  ·  ".join(parts) if parts.size() > 0 else "etki yok") + "\n[color=#b8c4c2]%s[/color]" % response.description
	%ConfirmButton.disabled = false


func _on_confirm() -> void:
	if _selected:
		%ConfirmButton.disabled = true  # çift tıklamada ikinci istek gitmesin
		EventBus.crisis_response_chosen.emit(_def.id, _selected.id)
