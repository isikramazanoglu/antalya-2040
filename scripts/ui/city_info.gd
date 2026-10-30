extends PanelContainer
## Sahip: B. Şehir bilgileri paneli: yapılan yatırımlar, görev durumları, yaşanan krizler. Yalnızca okur.

var _crises: Array = []  # crisis_resolved sonuçları + yıl


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("city_info")
	hide()
	%CloseButton.pressed.connect(close)
	EventBus.crisis_resolved.connect(func(r): _crises.append([GameState.stats.year, r]))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	UiText.pop_in(self)


func close() -> void:
	hide()


func _refresh() -> void:
	var t := "[b]Yatırımlar[/b]\n"
	if GameState.plots.is_empty():
		t += "[color=#b8c4c2]Henüz yatırım yapılmadı.[/color]\n"
	for plot_id in GameState.plots:
		var def := Catalog.get_building(GameState.plots[plot_id])
		t += "• %s  [color=#b8c4c2](%s · gider %d/yıl)[/color]\n" % [def.display_name, plot_id, def.upkeep_per_year]

	t += "\n[b]Görevler[/b]\n"
	var stats := GameState.get_stats()
	for m in Catalog.data.missions:
		var state: StringName = GameState.missions.get(m.id, &"active")
		var tag: String = {&"done": "[color=#6bd185]Tamamlandı[/color]", &"failed": "[color=#ff8c73]Kaçtı[/color]"}.get(state,
				"[color=#fad159]Sürüyor[/color] (şu an %d, son yıl %d)" % [roundi(stats[m.stat]), m.deadline_year])
		t += "• %s — %s\n" % [m.title, tag]

	t += "\n[b]Yaşanan krizler[/b]\n"
	if _crises.is_empty():
		t += "[color=#b8c4c2]Henüz kriz yaşanmadı.[/color]\n"
	for c in _crises:
		t += "• %d: %s\n" % [c[0], c[1].summary_text]
	%Body.text = t
