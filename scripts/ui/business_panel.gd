extends PanelContainer
## Sahip: B. İşletmeler ve çevre denetimi paneli (Prompt 13 §12): liste, ayrıntı, denetim, ceza, kararlar.
## Yalnızca okur; istekleri GameController'a iletir (GameState'e yazmaz). Açıkken takvim durur (ui_panel).

const REASONS := {
	&"wrong_phase": "Şu an yapılamaz.",
	&"unknown_business": "İşletme bulunamadı.",
	&"closed": "İşletme kapandı.",
	&"cooldown": "Bu işletme yakın zamanda denetlendi; birkaç ay sonra yeniden denetlenebilir.",
	&"not_enough_credits": "Ek denetim için bütçen yetmiyor. Gelecek ay ücretsiz denetim hakların yenilenir.",
	&"no_inspection": "Önce denetle.",
	&"no_violation": "Son denetimde ihlal yok; ceza ya da yaptırım uygulanamaz.",
	&"already_fined": "Bu ihlal için zaten ceza kesildi.",
	&"yearly_fine_limit": "Bu işletmeye bu yıl zaten ceza kesildi. Kirliliği azaltmak için bir iyileştirme kararı ver.",
	&"already_ordered": "Bu denetim için zaten bir karar verildi.",
	&"already_upgraded": "İşletmede bu sistem zaten var.",
	&"already_suspended": "İşletme zaten durduruldu.",
	&"not_suspended": "İşletme çalışıyor.",
}
## [karar, düğme yazısı, açıklama]
const ORDER_BUTTONS := [
	[&"filter", "Filtre taktır", "Bacaya filtre takılır: birkaç ay sonra hava kirliliği azalır (sıfırlanmaz). Dönüşüm sürerken işletmenin katkısı düşer."],
	[&"clean_energy", "Temiz enerjiye geçir", "İşletme elektriğini temiz kaynaklardan alır: enerjiden gelen karbon azalır. Daha uzun sürer."],
	[&"treatment", "Atık arıtma kurdur", "Atık ve atık su arıtılır: doğaya zarar azalır."],
	[&"grace", "Süre ver", "İşletmeye birkaç ay tanınır. Süre sonunda iyileştirme yapmamışsa yeniden denetle; ceza ağırlaşır."],
	[&"suspend", "Faaliyeti durdur", "Kirlilik hemen düşer ama işletme gelir getirmez ve çalışanlar işsiz kalır (yaşam kalitesi düşer)."],
]

var _selected: StringName = &""


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("business_panel")
	hide()
	%CloseButton.pressed.connect(close)
	for sig in [EventBus.business_spawned, EventBus.business_updated]:
		sig.connect(func(_info): _refresh_if_open())
	EventBus.business_removed.connect(func(_id, _site): _refresh_if_open())
	EventBus.stats_changed.connect(func(_s): _refresh_if_open())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	%Status.text = ""
	_refresh()
	UiText.pop_in(self)


func close() -> void:
	hide()


func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _controller() -> Node:
	return get_tree().get_first_node_in_group("game_controller")


func _type(b: Dictionary) -> BusinessType:
	return BusinessSimulator.get_type(Catalog.data.business_types, b.business_type)


func _refresh() -> void:
	var bal := Catalog.data.balance
	var stats := GameState.get_stats()
	var gc := _controller()
	var free_left := maxi(bal.inspections_per_month - GameState.inspections_used, 0)
	%Summary.text = ("Şehirde [b]%d[/b] işletme var. Hava kirliliği [b]%d[/b]/100 · atık kirliliği [b]%d[/b]/100 (az olması iyi) · "
			+ "bu ay [b]%d[/b] ücretsiz denetim hakkın kaldı%s.\n[font_size=12][color=#b8c4c2]İşletmeleri sen kurmazsın; şehir büyüdükçe sanayi bölgesine kendiliğinden gelirler. "
			+ "Sayılar oyun puanıdır; gerçek çevre mevzuatı ya da ölçüm değildir.[/color][/font_size]") % [
			GameState.businesses.size(), roundi(stats.get("air_pollution", 0.0)), roundi(stats.get("waste_pollution", 0.0)), free_left,
			"" if free_left > 0 else " (ek denetim %d kredi)" % bal.extra_inspection_cost]

	for child in %List.get_children():
		child.queue_free()
	_vehicle_box(gc)
	if GameState.businesses.is_empty():
		var empty := Label.new()
		empty.text = "Henüz işletme yok. Şehir büyüdükçe sanayi bölgesine fabrikalar ve depolar gelecek."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", UiText.C_MUTED)
		%List.add_child(empty)
	var group := ButtonGroup.new()
	for b in GameState.businesses:
		var t := _type(b)
		var eff := BusinessSimulator.effective(b, t, bal)
		var level := BusinessSimulator.violation_level(eff, bal)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(300, 0)
		btn.text = "%s\n%s · %s · %s" % [b.business_name, t.display_name, b.site_id, _status_text(b, level)]
		btn.add_theme_font_size_override("font_size", 14)
		if level >= 2 and b.operational_status == &"active":
			btn.add_theme_color_override("font_color", UiText.C_HIGH)
		btn.button_pressed = b.business_id == _selected
		btn.pressed.connect(func(): _selected = b.business_id; %Status.text = ""; _refresh())
		%List.add_child(btn)
	if _selected == &"" and not GameState.businesses.is_empty():
		_selected = GameState.businesses[0].business_id
	_render_detail(gc)


## Yol kenarı araç denetimi (teslim MVP): trafikten araç durdur, egzoz emisyonunu gör, yüksekse ceza kes.
func _vehicle_box(gc: Node) -> void:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Yol kenarı araç denetimi"
	title.add_theme_color_override("font_color", UiText.C_ACCENT)
	box.add_child(title)
	var v: Dictionary = GameState.vehicle_check
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 14)
	info.text = "Trafikten bir aracı durdurup egzozunu ölç." if v.is_empty() else "%s · %s · egzoz emisyonu: %s" % [v.plate, v.model, gc.VEHICLE_LEVELS[v.level] if gc else ""]
	box.add_child(info)
	var row := HBoxContainer.new()
	var stop := Button.new()
	stop.text = "Araç durdur"
	stop.add_theme_font_size_override("font_size", 14)
	stop.disabled = gc == null or GameState.phase != &"build"
	stop.pressed.connect(func(): gc.inspect_vehicle(); %Status.text = ""; _refresh())
	row.add_child(stop)
	var fine := Button.new()
	fine.text = "Egzoz cezası (+%d kredi)" % (gc.VEHICLE_FINE if gc else 0)
	fine.add_theme_font_size_override("font_size", 14)
	fine.disabled = gc == null or v.is_empty() or v.level < 2
	fine.tooltip_text = "Yalnızca yüksek emisyonlu araca; aynı araca aynı ay bir kez."
	fine.pressed.connect(func():
		var r: StringName = gc.fine_vehicle()
		%Status.text = REASONS.get(r, "") if r != &"" else ""
		_refresh())
	row.add_child(fine)
	box.add_child(row)
	%List.add_child(box)
	%List.add_child(HSeparator.new())


func _status_text(b: Dictionary, level: int) -> String:
	match b.operational_status:
		&"suspended":
			return "durduruldu"
		&"closed":
			return "kapandı"
	if not (b.pending_improvements as Array).is_empty():
		return "dönüşümde"
	if (b.inspection_history as Array).is_empty():
		return "denetlenmedi"
	return BusinessSimulator.LEVEL_NAMES[level].to_lower()


func _render_detail(gc: Node) -> void:
	for child in %Actions.get_children():
		child.queue_free()
	var b := GameState.get_business(_selected)
	if b.is_empty():
		%Detail.text = "[color=#b8c4c2]Bir işletme seç.[/color]"
		return
	var bal := Catalog.data.balance
	var t := _type(b)
	var eff := BusinessSimulator.effective(b, t, bal)
	var d := "[b][font_size=20]%s[/font_size][/b]\n%s · sanayi yeri %s · %d yılında kuruldu\n[color=#b8c4c2]%s[/color]\n\n" % [
			b.business_name, t.display_name, b.site_id, b.established_year, t.description]
	d += "[b]Ekonomi[/b]  belediyeye yılda [color=#6bd185]+%d kredi[/color] · %d çalışan · üretim %%%d\n" % [roundi(eff.contribution), eff.employees, roundi(b.production * 100)]
	d += "[b]Kaynak[/b]  elektrik %.1f · su %.1f (şehrin ihtiyacına eklenir)\n" % [eff.energy, eff.water]
	d += "[b]Çevre[/b]  hava kirliliği %.1f (sınır %.0f) · atık %.1f (sınır %.0f) · karbon %.1f (%s)\n" % [
			eff.air, bal.air_standard, eff.waste, bal.waste_standard, eff.ghg, BusinessSimulator.GHG_NAMES[BusinessSimulator.ghg_level(eff)].to_lower()]
	var ups := PackedStringArray()
	for k in ["filter", "clean_energy", "treatment"]:
		if b.upgrades[k]:
			ups.append({"filter": "filtre", "clean_energy": "temiz enerji", "treatment": "atık arıtma"}[k])
	d += "[b]Çevre sistemleri[/b]  %s\n" % (", ".join(ups) if ups.size() > 0 else "yok")
	for o in b.pending_improvements:
		d += "[color=#fad159]Süren karar: %s · %d ay kaldı[/color]\n" % [_order_name(o.order), o.months_left]
	if b.operational_status == &"suspended":
		d += "[color=#ff8c73]Faaliyet durduruldu (%d ay). %d ay kapalı kalırsa işletme kapanır.[/color]\n" % [b.suspended_months, bal.closure_after_suspended_months]
	var hist: Array = b.inspection_history
	d += "\n[b]Denetimler[/b]\n"
	if hist.is_empty():
		d += "[color=#b8c4c2]Henüz denetlenmedi.[/color]\n"
	for i in range(hist.size() - 1, maxi(hist.size() - 4, -1), -1):
		var r: Dictionary = hist[i]
		d += "• %s %d · %s · hava %.1f · atık %.1f%s%s\n" % [UiText.MONTHS[r.month - 1], r.year, BusinessSimulator.LEVEL_NAMES[r.level], r.air, r.waste,
				" · ceza %d kredi" % r.fine_paid if r.fined else (" · önerilen ceza %d kredi" % r.suggested_fine if r.level > 0 else ""),
				" · karar: %s" % _order_name(r.order) if r.order != &"" else ""]
	var next: Dictionary = b.last_inspection
	if not next.is_empty():
		var m: int = next.month - 1 + bal.inspection_cooldown_months
		d += "[color=#b8c4c2]Yeniden denetim: %s %d ve sonrası[/color]\n" % [UiText.MONTHS[m % 12], next.year + m / 12]
	%Detail.text = d

	if gc == null or GameState.phase != &"build":
		return
	var cost: int = gc.inspection_cost()
	_action("Denetle" + (" (ücretsiz)" if cost == 0 else " (%d kredi)" % cost), "Veriler kontrol edilir: hava, atık, filtre durumu ve önceki ihlaller.",
			func(): return gc.inspect_business(b.business_id), BusinessSimulator.inspect_block_reason(b, GameState.stats.year, GameState.month, bal))
	var fine_reason := BusinessSimulator.fine_block_reason(b, GameState.stats.year, bal)
	var fine: int = 0 if fine_reason != &"" else BusinessSimulator.fine_amount(b, t, hist[-1].level, bal)
	_action("Ceza kes" + (" (+%d kredi)" % fine if fine > 0 else ""), "Ceza kasana girer ama kirliliği azaltmaz. Aynı ihlal için bir kez kesilir.",
			func(): return gc.fine_business(b.business_id), fine_reason)
	for ob in ORDER_BUTTONS:
		_action(ob[1], ob[2], func(): return gc.order_business(b.business_id, ob[0]), BusinessSimulator.order_block_reason(b, ob[0]))
	if b.operational_status == &"suspended":
		_action("Yeniden aç", "Çalışanlar işe döner, gelir ve kirlilik de geri gelir.", func(): return gc.resume_business(b.business_id), &"")


func _order_name(order: StringName) -> String:
	for ob in ORDER_BUTTONS:
		if ob[0] == order:
			return ob[1].to_lower()
	return str(order)


func _action(text: String, tip: String, call: Callable, block: StringName) -> void:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tip + ("\n" + REASONS.get(block, "") if block != &"" else "")
	btn.disabled = block != &""
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func():
		var reason: StringName = call.call()
		%Status.text = REASONS.get(reason, str(reason)) if reason != &"" else ""
		%Status.add_theme_color_override("font_color", UiText.C_HIGH)
		_refresh())
	%Actions.add_child(btn)
