extends Control
## Sahip: B. Kriz anında müdahale seçimi (sözleşme §6.6). Hasarı hesaplamaz; sonuç yıl sonu raporunda.

var _event_id: StringName


func _ready() -> void:
	hide()
	EventBus.crisis_started.connect(_on_crisis_started)
	EventBus.crisis_resolved.connect(func(_result): hide())


func _on_crisis_started(event_id: StringName, risk_type: StringName, _severity: float) -> void:
	var def := Catalog.get_event(event_id)
	_event_id = event_id
	%Title.text = def.display_name
	var text := def.description
	if def.info_card:
		text += "\n\n[i]%s[/i]" % def.info_card.body
	%Description.text = text
	var mit := ClimateSimulator.mitigation(GameState.built_definitions(), risk_type, Catalog.data.balance)
	%MitigationLabel.text = "Yatırımların bu krizin hasarını %%%d azaltacak." % roundi(mit * 100)

	for child in %Responses.get_children():
		child.queue_free()
	var credits: int = GameState.stats.credits
	for response in def.responses:
		var button := Button.new()
		button.text = "%s · %s" % [response.label, "ücretsiz" if response.cost == 0 else "%d kredi" % response.cost]
		button.tooltip_text = response.description
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = response.cost > credits
		button.pressed.connect(EventBus.crisis_response_chosen.emit.bind(_event_id, response.id))
		%Responses.add_child(button)
	show()
