extends Control
## Sahip: B. 2052 final raporu (Prompt 10A): değerlendirme, 2040 ↔ 2052 karşılaştırması, bölümler, grafikler, JSON dışa aktarma.
## Hesap yapmaz: game_over özetindeki FinalEvaluator sonucunu ve kayıtlı yıllık geçmişi gösterir.
## Final sunumu (v1.9): düğme yalnızca final_presentation_requested'i dinleyen biri varsa (Ekip A) görünür.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"

const PRESENTATION_TIMEOUT := 120.0  # A'nın sunumu bitiş sinyali göndermezse rapor yine de geri gelir

var _summary: Dictionary = {}
var _presenting := false
var _presentation_id := 0  # eski zaman aşımı yeni bir sunumu erken bitirmesin


func _ready() -> void:
	hide()
	EventBus.game_over.connect(_on_game_over)
	EventBus.final_presentation_finished.connect(_on_presentation_finished)
	%MenuButton.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	%ExportButton.pressed.connect(_export_json)
	%PresentButton.pressed.connect(_on_present_pressed)


func _on_game_over(summary: Dictionary) -> void:
	_summary = summary
	%PresentButton.visible = not EventBus.final_presentation_requested.get_connections().is_empty()
	%ExportStatus.text = ""
	_build(summary)
	UiText.pop_in(self)
	%MenuButton.grab_focus()


func _on_present_pressed() -> void:
	hide()
	_presenting = true
	_presentation_id += 1
	var id := _presentation_id
	get_tree().create_timer(PRESENTATION_TIMEOUT).timeout.connect(func(): if id == _presentation_id: _on_presentation_finished())
	EventBus.final_presentation_requested.emit(_summary)


## Sunum bitti, zaman aşımı oldu ya da oyuncu Esc'ye bastı: rapor geri gelir (ana menüye dönüş hep mümkün kalsın).
func _on_presentation_finished() -> void:
	if _presenting and not _summary.is_empty():
		_presenting = false
		UiText.pop_in(self)


func _unhandled_input(event: InputEvent) -> void:
	if _presenting and event.is_action_pressed("cancel"):
		_on_presentation_finished()
		get_viewport().set_input_as_handled()


func _rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = text
	return r


func _section(title: String, body: String) -> void:
	%Content.add_child(_rich("[font_size=22][b]%s[/b][/font_size]\n%s" % [title, body]))


func _chart(title: String, meta: String, series: Array, years: PackedStringArray, note := "") -> void:
	var box := VBoxContainer.new()
	box.add_child(_rich("[b]%s[/b]  [font_size=13][color=#b8c4c2]%s[/color][/font_size]" % [title, meta]))
	var chart := LineChart.new()
	chart.custom_minimum_size.y = 190
	chart.set_data(series, years)
	box.add_child(chart)
	if note != "":
		box.add_child(_rich("[font_size=13][color=#b8c4c2]%s[/color][/font_size]" % note))
	%Content.add_child(box)


func _series(history: Array, key: String) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for s in history:
		v.append(float(s.get(key, 0.0)))
	return v


func _build(summary: Dictionary) -> void:
	for child in %Content.get_children():
		child.free()
	var ev: Dictionary = summary.get("evaluation", {})
	var history: Array = summary.get("history", [])
	var start: Dictionary = summary.get("start_stats", {})
	var final: Dictionary = summary.get("final_stats", {})
	%Title.text = "2052 · Şehrin geleceği"
	if ev.is_empty():
		%Content.add_child(_rich("Değerlendirme verisi bulunamadı."))
		return

	# Genel değerlendirme
	var t := "[font_size=40][b]%d[/b][/font_size] / 100   [font_size=26][color=#4dd9d1][b]%s[/b][/color][/font_size]\n%s\n\n" % [ev.overall, ev.grade, ev.grade_text]
	t += "[color=#6bd185][b]En başarılı alan:[/b][/color] %s (%d) — %s\n" % [ev.best.title, ev.best.score, ev.best.why]
	t += "[color=#ffbf66][b]Geliştirilmesi gereken alan:[/b][/color] %s (%d) — %s. Öneri: %s\n" % [ev.worst.title, ev.worst.score, ev.worst.why, ev.worst.advice]
	t += "[font_size=13][color=#b8c4c2]Bu puan oyun içi bir değerlendirmedir; bilimsel bir iklim dayanıklılığı ölçümü değildir.[/color][/font_size]"
	%Content.add_child(_rich(t))
	var bars := []
	for d in ev.dimensions:
		bars.append({"label": d.title, "value": d.score, "color": UiText.status(d.score)[1]})
	var bar := BarChart.new()
	bar.label_width = 250.0
	bar.set_data(bars, "")
	%Content.add_child(_rich("[b]Alt puanlar[/b]  [font_size=13][color=#b8c4c2]0–100 · krizlere hazırlık %10, diğer altısı %15 sayılır[/color][/font_size]"))
	%Content.add_child(bar)
	var why := ""
	for d in ev.dimensions:
		why += "• %s: %d — %s\n" % [d.title, d.score, d.why]
	%Content.add_child(_rich("[font_size=14]%s[/font_size]" % why))

	# 2040 ↔ 2052
	var c := "[table=5][cell][color=#b8c4c2]Gösterge[/color][/cell][cell][color=#b8c4c2]2040[/color][/cell][cell][color=#b8c4c2]%d[/color][/cell][cell][color=#b8c4c2]Değişim[/color][/cell][cell][color=#b8c4c2]%%[/color][/cell]" % int(final.get("year", 2052))
	for row in ev.comparisons:
		var color := UiText.C_MUTED if row.better == &"neutral" else (UiText.C_GOOD if row.improved else (UiText.C_MUTED if is_zero_approx(row.delta) else UiText.C_CRIT))
		var pct: String = "—" if row.pct == null else "%+d%%" % roundi(row.pct)
		c += "[cell]%s      [/cell][cell]%s      [/cell][cell]%s      [/cell][cell][color=#%s]%s[/color]      [/cell][cell]%s[/cell]" % [
			row.title, UiText.thousands(roundi(row.start)), UiText.thousands(roundi(row.final)), color.to_html(false), UiText.format_delta(row.delta), pct]
	c += "[/table]\n[font_size=13][color=#b8c4c2]Bütçe ve nüfustaki değişim tek başına başarı ya da başarısızlık değildir; gri gösterilir. Karbonda düşüş iyidir. Başta 0 olan satırda yüzde hesaplanmaz (—).[/color][/font_size]"
	_section("2040 ve %d karşılaştırması" % int(final.get("year", 2052)), c)

	var years := PackedStringArray()
	for s in history:
		years.append(str(s.get("year", "")))
	var tot: Dictionary = ev.totals

	# Ekonomi
	_section("Para", "Yatırımlara harcanan: %s kredi (%d yapı) · bakım masrafları: %s · vergi geliri: %s\nBaşta %s kredi → sonunda %s kredi" % [
		UiText.thousands(tot.investment_cost), tot.buildings, UiText.thousands(tot.upkeep), UiText.thousands(tot.income),
		UiText.thousands(int(start.get("credits", 0))), UiText.thousands(int(final.get("credits", 0)))])
	if history.size() > 0:
		_chart("Bütçe", "kredi · yıl sonları · OYUN HESABI", [{"name": "Bütçe", "color": Color(0.98, 0.82, 0.35), "values": _series(history, "credits")}], years)

	# Enerji
	_section("Elektrik", "Sonunda temiz elektrik %d · ihtiyaç %d · temiz elektrik payı %%%d" % [
		roundi(final.get("renewable_energy", 0.0)), roundi(final.get("energy_demand", 0.0)), roundi(float(final.get("renewable_share", 0.0)) * 100)])
	if history.size() > 0:
		_chart("Elektrik: ihtiyaç ve temiz üretim", "OYUN HESABI", [
			{"name": "İhtiyaç", "color": Color(0.98, 0.75, 0.25), "values": _series(history, "energy_demand")},
			{"name": "Temiz elektrik", "color": Color(0.42, 0.82, 0.52), "values": _series(history, "renewable_energy")}], years)

	# Su
	var builds: Array = summary.get("city_2052", {}).get("builds", [])
	var water_names := PackedStringArray()
	var green_names := PackedStringArray()
	for e in builds:
		var def := Catalog.get_building(e.building_id)
		if def and def.category == &"water":
			water_names.append(def.display_name)
		if def and def.category in [&"heat", &"food", &"waste", &"coast"]:
			green_names.append(def.display_name)
	_section("Su", "Su puanı %d → %d · sonunda şehrin suyu %d (+%d yeniden kullanılan) / ihtiyaç %d\nSu yatırımları: %s" % [
		roundi(start.get("water_security", 0.0)), roundi(final.get("water_security", 0.0)), roundi(final.get("water_supply", 0.0)),
		roundi(final.get("recycled_water_used", 0.0)), roundi(final.get("water_demand", 0.0)), ", ".join(water_names) if water_names.size() > 0 else "yok"])
	if history.size() > 0:
		_chart("Su puanı", "0–100 · OYUN HESABI", [{"name": "Su puanı", "color": Color(0.3, 0.85, 0.82), "values": _series(history, "water_security")}], years)

	# Ekosistem
	_section("Doğa ve karbon", "Doğa puanı %d → %d · çöp azaltma %%%d → %%%d\nDoğa, gıda ve çöp yatırımları: %s" % [
		roundi(start.get("ecosystem_health", 0.0)), roundi(final.get("ecosystem_health", 0.0)), roundi(float(start.get("waste_recovery", 0.0)) * 100),
		roundi(float(final.get("waste_recovery", 0.0)) * 100), ", ".join(green_names) if green_names.size() > 0 else "yok"])
	if history.size() > 0:
		_chart("Doğa ve karbon salımı", "OYUN HESABI", [
			{"name": "Doğa", "color": Color(0.42, 0.82, 0.52), "values": _series(history, "ecosystem_health")},
			{"name": "Karbon salımı", "color": Color(0.85, 0.45, 0.35), "values": _series(history, "emissions_total")}], years,
			"Karbon salımı yalnızca senin şehrinin oyun puanıdır; dünyanın havasındaki CO₂ (ppm) ölçümü değildir. Tek bir şehir dünya değerini hemen değiştiremez.")

	# İklim ve afetler
	var crises: Array = GameState.crisis_log
	var ct := ""
	for r in crises:
		var event := Catalog.get_event(r.event_id)
		var response := EventManager.find_response(event, r.response_id) if event else null
		ct += "• %d · %s · ne yaptın: %s · para %s · yatırımların koruması %%%d\n" % [r.get("year", 0), event.display_name if event else str(r.event_id),
				response.label if response else str(r.response_id), UiText.format_delta(float(r.damage.get("credits", 0.0))), roundi(float(r.mitigation) * 100)]
	_section("Krizler", (ct if ct != "" else "Kriz olmadı.\n") + "Krizlerde kaybedilen toplam para: %s · sonunda tehlikelere karşı koruma %%%d" % [
		UiText.format_delta(tot.crisis_loss), roundi(float(final.get("climate_resilience", 0.0)) * 100)])

	# Yatırımlar
	var bt := ""
	for e in builds:
		var def := Catalog.get_building(e.building_id)
		bt += "• %d · %s (%s) · %s kredi\n" % [e.year, def.display_name if def else str(e.building_id), e.plot_id, UiText.thousands(int(e.cost))]
	_section("Yatırımlar (%d)" % builds.size(), bt if bt != "" else "Hiç yatırım yapılmadı.")


## JSON dışa aktarma: oyun klasörüne (user://reports/) kaydeder; ağ ya da dış servis yok.
func _export_json() -> void:
	var dir := "user://reports"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/antalya2040_rapor_%s.json" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		%ExportStatus.text = "Kaydedilemedi (hata %d)." % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(_summary, "  "))
	file.close()
	%ExportStatus.text = "Kaydedildi: %s" % ProjectSettings.globalize_path(path)
