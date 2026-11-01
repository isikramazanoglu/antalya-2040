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
	var color: Color = UiText.status(100.0 - severity * 100.0)[1]  # şiddet yüksekse kırmızıya döner
	var word := "Çok yüksek" if severity >= 0.6 else ("Yüksek" if severity >= 0.4 else ("Orta" if severity >= 0.25 else "Düşük"))
	%Risk.text = "Ne kadar tehlikeli: %s" % word
	%Risk.add_theme_color_override("font_color", color)

	var t := _def.description
	if _def.info_card:
		t += "\n[i]%s[/i]" % _def.info_card.body
	var adv := PackedStringArray()
	for id in _assessment.advantages:
		adv.append(Catalog.get_building(id).display_name)
	if adv.size() > 0:
		t += "\n\n[b][color=#6bd185]Hazırsın![/color][/b] Kurduğun yatırımlar zararı [b]%%%d[/b] azaltıyor: %s" % [roundi(_assessment.mitigation * 100), ", ".join(adv)]
	else:
		t += "\n\n[b][color=#ff8c73]Hazırlıksızsın.[/color][/b] Bu krize karşı henüz bir yatırımın yok."
	# Hesabın ayrıntısı meraklısı için küçük ve soluk.
	t += "\n[font_size=12][color=#b8c4c2]Oyun hesabı: tehlike ×%.2f · nüfus ×%.2f · şehrin zayıflığı ×%.2f · hazırlık −%%%d[/color][/font_size]" % [
		_assessment.hazard, _assessment.exposure, _assessment.vulnerability, roundi(_assessment.mitigation * 100)]
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
			tag = "   (%s sayesinde)" % Catalog.get_building(response.required_building).display_name
		button.text = "%s · %s%s" % [response.label, "ücretsiz" if response.cost == 0 else "%d kredi" % response.cost, tag]
		button.tooltip_text = response.description
		if response.cost > credits:
			button.disabled = true
			button.tooltip_text += "\nBütçe yetmiyor."
		button.pressed.connect(_on_response_pressed.bind(response))
		%Responses.add_child(button)
	%Preview.text = "[color=#b8c4c2]Ne yapacağını seç; ne olacağını burada görürsün.[/color]"
	%ConfirmButton.disabled = true
	UiText.pop_in(self)


func _on_response_pressed(response: CrisisResponse) -> void:
	_selected = response
	var damage := EventManager.preview(_def, response, _assessment)
	var parts := PackedStringArray()
	for key in damage:
		var v: float = damage[key]
		parts.append("[color=#%s]%s %s[/color]" % [UiText.delta_color(v).to_html(false), UiText.STAT_NAMES.get(key, key), UiText.format_delta(v)])
	%Preview.text = "[b]Ne olacak:[/b] " + ("  ·  ".join(parts) if parts.size() > 0 else "zarar yok") + "\n[color=#b8c4c2]%s[/color]" % response.description
	%ConfirmButton.disabled = false


func _on_confirm() -> void:
	if _selected:
		%ConfirmButton.disabled = true  # çift tıklamada ikinci istek gitmesin
		EventBus.crisis_response_chosen.emit(_def.id, _selected.id)
