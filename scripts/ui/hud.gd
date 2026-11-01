extends Control
## Sahip: B. Ana HUD (Prompt 5 §3): üst bilgi çubuğu, sol kaynak paneli, alt menü.
## Yalnızca GameState'i okur; yazmaz. Paneller "ui_panel" grubundadır, aynı anda biri açık kalır.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
## [anahtar, başlık, ikon]
const RESOURCES := [
	["water_security", "Su", "water"],
	["energy_security", "Elektrik", "energy"],
	["quality_of_life", "Yaşam kalitesi", "quality"],
	["ecosystem_health", "Doğa", "ecosystem"],
]

var _cards: Dictionary = {}  # anahtar -> {"value": Label, "status": Label, "bar": ProgressBar, "detail": Label}
var _shown_credits := 0.0
var _credits_tween: Tween
var _last_net := 0  # son yıl sonu net bakiyesi (gelir - gider)
var _has_report := false  # "Son rapor" ilk yıl sonundan önce kapalı
var _speed_buttons: Array[Button] = []
var _shown_month := 0  # uyarılardaki "kaç ay kaldı" her ay yenilensin


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_cards()
	%EndTurnButton.pressed.connect(EventBus.end_turn_requested.emit)
	%BuildMenuButton.pressed.connect(_open_panel.bind("build_panel"))
	%LabButton.pressed.connect(_open_panel.bind("climate_lab"))
	%CityInfoButton.pressed.connect(_open_panel.bind("city_info"))
	%BusinessButton.pressed.connect(_open_panel.bind("business_panel"))
	%GlossaryButton.pressed.connect(func():
		get_tree().call_group("ui_panel", "close")
		get_tree().call_group("climate_lab", "open_tab", "Sözlük"))
	%ReportButton.pressed.connect(_open_panel.bind("year_report"))
	%SettingsButton.pressed.connect(_open_panel.bind("settings"))
	%MenuButton.pressed.connect(%QuitConfirm.popup_centered)
	%QuitConfirm.confirmed.connect(func():
		get_tree().call_group("game_controller", "save_game")
		get_tree().change_scene_to_file(MAIN_MENU))
	%CollapseButton.pressed.connect(_toggle_resources)
	_build_speed_buttons()
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.year_ended.connect(_on_year_ended)
	EventBus.crisis_warned.connect(func(_w): _refresh_warnings())
	EventBus.crisis_resolved.connect(func(_r): _refresh_warnings())
	EventBus.year_started.connect(func(_y): _refresh_missions(); _refresh_warnings())
	EventBus.stats_changed.connect(func(_s): _refresh_missions())  # "şu an" değerleri inşaattan hemen sonra da doğru olsun
	_shown_credits = GameState.stats.credits
	_on_stats_changed(GameState.get_stats())
	_refresh_warnings()
	_refresh_missions()


## Takvim hız düğmeleri (Durdur, 1×, 2×, 3×): YearProgress'in sağına, kodla.
func _build_speed_buttons() -> void:
	var group := ButtonGroup.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var labels := ["Durdur", "1×", "2×", "3×"]
	var tips := ["Zamanı durdur (Boşluk)", "Normal hız", "İki kat hızlı", "Üç kat hızlı"]
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tips[i]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): _clock_call("set_speed", i))
		box.add_child(b)
		_speed_buttons.append(b)
	%YearProgress.add_sibling(box)


func _clock() -> MonthClock:
	return get_tree().get_first_node_in_group("month_clock") as MonthClock


func _clock_call(method: String, arg = null) -> void:
	var c := _clock()
	if c:
		c.call(method, arg) if arg != null else c.call(method)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_clock_call("toggle_pause")
		get_viewport().set_input_as_handled()


## Tarih ve ay çubuğu her karede (ay değişimi stats_changed yaymaz; çubuk ay içinde de akar).
func _process(_delta: float) -> void:
	var b: BalanceConfig = Catalog.data.balance
	var year: int = GameState.stats.year
	if GameState.month != _shown_month:
		_shown_month = GameState.month
		_refresh_warnings()
	%YearValue.text = "%s %d" % [UiText.MONTHS[GameState.month - 1], year]
	var c := _clock()
	var total := float((b.end_year - b.start_year + 1) * 12)
	var done := (year - b.start_year) * 12 + GameState.month - 1 + (c.progress if c else 0.0)
	%YearProgress.max_value = total
	%YearProgress.value = done
	%YearProgress.tooltip_text = "%d. yıl / %d · %d. ay" % [year - b.start_year + 1, b.end_year - b.start_year + 1, GameState.month]
	if c:
		for i in _speed_buttons.size():
			_speed_buttons[i].set_pressed_no_signal(i == c.speed)


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
	_cards["economy"] = _make_card("Para", "economy")
	_cards["emissions_total"] = _make_card("Karbon salımı", "emission")


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
	%PopulationValue.text = UiText.thousands(stats.population)
	_animate_credits(stats.credits)

	for r in RESOURCES:
		var detail := ""
		if r[0] == "energy_security":
			var need := roundi(stats.energy_demand)
			var clean := roundi(stats.renewable_energy)
			detail = "İhtiyaç %d · temiz enerji %d" % [need, clean] + (" · hepsi temiz" if clean >= need else " · %d kömür ve doğalgazdan" % (need - clean))
		elif r[0] == "water_security":
			var have := roundi(stats.water_supply + stats.recycled_water_used)
			var want := roundi(stats.water_demand)
			detail = "Su %d%s · ihtiyaç %d · %s" % [have, " (%d geri kazanılmış)" % roundi(stats.recycled_water_used) if stats.recycled_water_used > 0.0 else "",
					want, "%d fazla" % (have - want) if have >= want else "%d eksik" % (want - have)]
		_set_card(r[0], stats[r[0]], str(roundi(stats[r[0]])), detail)

	# Ekonomik durum: kasanın en ucuz yatırıma yetmesi ve son yılın net bakiyesi.
	var cheapest := _cheapest_available_cost()
	var econ := 80.0 if stats.credits >= cheapest else (40.0 if stats.credits >= 0 else 10.0)
	_set_card("economy", econ, UiText.thousands(stats.credits),
			("Geçen yıl %s kredi · " % UiText.format_delta(_last_net) if _has_report else "") + ("en ucuz yatırım %d kredi" % cheapest if cheapest > 0 else "bütün yatırımlar yapıldı"))


	# Emisyonda düşük iyidir: 80 ve altı iyi, 120 üstü kritik olacak şekilde 0-100 ölçeğine çevrilip durum rengi alınır.
	var start_total := 0.0
	for v in Catalog.data.balance.base_emissions.values():
		start_total += v
	var em: float = stats.emissions_total
	_set_card("emissions_total", clampf(150.0 - em, 0.0, 100.0), str(roundi(em)),
			"Başta %d · %s · az olması iyi" % [roundi(start_total), "%d azaldı" % roundi(start_total - em) if em < start_total - 0.5
					else ("%d arttı" % roundi(em - start_total) if em > start_total + 0.5 else "değişmedi")])


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
		var month: int = def.month if def else 12
		var left: int = (w.due_year - GameState.stats.year) * 12 + month - GameState.month
		var when := "%s %d · %s" % [UiText.MONTHS[month - 1], w.due_year, "şimdi" if left <= 0 else "%d ay kaldı" % left]
		var label := _side_label("Uyarı · %s · %s" % [def.display_name if def else str(w.event_id), when], UiText.C_HIGH)
		label.tooltip_text = def.warning_text if def else ""
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		%Warnings.add_child(label)
		var t := label.create_tween().set_loops(3)
		t.tween_property(label, "modulate:a", 0.45, 0.35)
		t.tween_property(label, "modulate:a", 1.0, 0.35)


func _refresh_missions() -> void:
	for child in %Missions.get_children():
		child.queue_free()
	var stats := GameState.get_stats()
	var rows: Array = []
	for m in Catalog.data.missions:
		if m.category == &"goal" and GameState.missions.get(m.id, &"active") == &"active":
			rows.append(m)
	if rows.is_empty():
		return
	# Kaynak paneliyle aynı görünümde kart: başlık, ilerleme çubuğu, şu an / hedef, son tarih, ödül.
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := Label.new()
	head.text = "Görevler"
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiText.C_ACCENT)
	box.add_child(head)
	for m in rows:
		var current: float = stats[m.stat]
		var reached: bool = current <= m.target if m.at_most else current >= m.target
		# "En çok" görevde çubuk hedefe yaklaştıkça dolar (hedef / şu an).
		var ratio := clampf(m.target / maxf(current, 0.01) if m.at_most else current / maxf(m.target, 0.01), 0.0, 1.0)
		var title := Label.new()
		title.text = ("✓ " if reached else "") + m.title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 15)
		title.tooltip_text = m.description
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(title)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 1.0
		bar.value = ratio
		bar.add_theme_stylebox_override("fill", _bar_fill(UiText.C_GOOD if reached else UiText.C_WARN))
		box.add_child(bar)
		var info := Label.new()
		info.text = "Şu an %d · hedef %s%d · %d sonuna kadar · ödül +%d" % [
				roundi(current), "en çok " if m.at_most else "", roundi(m.target), m.deadline_year, m.reward_credits]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", UiText.C_MUTED)
		box.add_child(info)
	%Missions.add_child(card)


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
