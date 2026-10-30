extends PanelContainer
## Sahip: B. İklim Laboratuvarı: yerel emisyonlar, küresel CO2, yerel riskler, bilgi kartları.
## Hesap yapmaz; GameState geçmişi, Catalog verisi ve ClimateSimulator'ın salt okunur fonksiyonlarını gösterir.

const SECTORS := {"energy": ["Enerji", Color(0.98, 0.75, 0.25)], "transport": ["Ulaşım", Color(0.4, 0.7, 1.0)],
		"buildings": ["Binalar", Color(0.85, 0.45, 0.35)], "waste": ["Atık", Color(0.55, 0.85, 0.5)]}
const RISKS := {"drought": "Kuraklık", "heat": "Aşırı sıcak", "coastal_flood": "Kıyı taşkını"}


func _ready() -> void:
	add_to_group("climate_lab")
	%Cards.get_parent().set_tab_title(3, "Bilgi kartları")
	hide()
	%CloseButton.pressed.connect(hide)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: StringName) -> void:
	if phase != &"build":
		hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	var timeline: Array = GameState.history.duplicate()
	timeline.append(GameState.get_stats())
	var years := PackedStringArray()
	for s in timeline:
		years.append(str(s.year))

	# Yerel emisyonlar
	var series := []
	for sector in SECTORS:
		var values := PackedFloat32Array()
		for s in timeline:
			values.append(s.emissions_by_sector[sector])
		series.append({"name": SECTORS[sector][0], "color": SECTORS[sector][1], "values": values})
	%EmissionChart.set_data(series, years)
	var now := GameState.get_stats()
	var text := "Toplam: [b]%d[/b] (oyun birimi; gerçek ton değeri değildir)\n" % roundi(now.emissions_total)
	for sector in SECTORS:
		text += "%s: %d   " % [SECTORS[sector][0], roundi(now.emissions_by_sector[sector])]
	%EmissionText.text = text

	# Küresel CO2
	var co2: Co2Scenario = Catalog.data.co2
	if co2 and co2.years.size() > 0:
		var labels := PackedStringArray([str(co2.years[0]), str(co2.years[-1])])
		%Co2Chart.set_data([{"name": "Atmosferik CO2 (ppm)", "color": Color(0.3, 0.85, 0.82), "values": co2.ppm}], labels, "")
		%Co2Text.text = ("Son ölçüm: [b]%.2f ppm[/b] (%d)\n" % [co2.ppm[-1], co2.years[-1]]
				+ "Şehrinin yatırımları bu eğriyi doğrudan değiştirmez. Atmosferdeki CO2, dünyadaki bütün kaynakların toplamıyla belirlenir; "
				+ "tek bir şehrin payı çok küçüktür. Etki, birçok şehir aynı yönde adım attığında oluşur.\n"
				+ "%s yılları için doğrulanmış senaryo verisi eklenmediğinden tahmin gösterilmiyor.\n[font_size=12]Kaynak: %s[/font_size]" % [
					"%d sonrası" % co2.years[-1], co2.source])
	else:
		%Co2Chart.set_data([], PackedStringArray())
		%Co2Text.text = "Veri yok."

	# Yerel riskler
	for child in %Risks.get_children():
		child.queue_free()
	var buildings := GameState.built_definitions()
	var b: BalanceConfig = Catalog.data.balance
	for risk_type in RISKS:
		var raw := ClimateSimulator.raw_risk(risk_type, now.year, b)
		var mit := ClimateSimulator.mitigation(buildings, risk_type, b)
		var label := Label.new()
		label.text = "%s · ham risk %d · yatırım koruması %%%d · kalan risk %d" % [RISKS[risk_type], roundi(raw), roundi(mit * 100), roundi(now.risks[risk_type])]
		var bar := ProgressBar.new()
		bar.value = now.risks[risk_type]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		%Risks.add_child(label)
		%Risks.add_child(bar)
	var note := Label.new()
	note.text = "Risk değerleri oyun ölçeğidir (0-100), bilimsel tahmin değildir. Yatırımlar riski değil, krizin hasarını azaltır."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = 0.7
	%Risks.add_child(note)

	# Bilgi kartları
	var cards := ""
	for card in Catalog.data.lab_cards:
		cards += _card_text(card)
	for def in Catalog.data.buildings:
		if def.info_card:
			cards += _card_text(def.info_card)
	for def in Catalog.data.events:
		if def.info_card:
			cards += _card_text(def.info_card)
	%Cards.text = cards


func _card_text(card: InfoCard) -> String:
	var t := "[b]%s[/b]\n%s\n" % [card.title, card.body]
	for source in card.sources:
		t += "[font_size=12]Kaynak: %s[/font_size]\n" % source
	return t + "\n"
