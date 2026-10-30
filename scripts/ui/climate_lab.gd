extends PanelContainer
## Sahip: B. İklim Laboratuvarı: yerel emisyonlar, küresel CO2, yerel riskler, bilgi kartları.
## Hesap yapmaz; GameState geçmişi, Catalog verisi ve ClimateSimulator'ın salt okunur fonksiyonlarını gösterir.

const SECTORS := {"energy": ["Enerji", Color(0.98, 0.75, 0.25)], "transport": ["Ulaşım", Color(0.4, 0.7, 1.0)],
		"buildings": ["Binalar", Color(0.85, 0.45, 0.35)], "waste": ["Atık", Color(0.55, 0.85, 0.5)]}
const RISKS := {"drought": "Kuraklık", "heat": "Aşırı sıcak", "coastal_flood": "Kıyı taşkını"}


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("climate_lab")
	var tabs: TabContainer = %Cards.get_parent()
	tabs.set_tab_title(tabs.get_tab_idx_from_control(%Cards), "Bilgi kartları")
	hide()
	%CloseButton.pressed.connect(hide)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: StringName) -> void:
	if phase != &"build":
		hide()


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
	var text := "Toplam: [b]%d[/b] (oyun birimi; gerçek ton değeri değildir)" % roundi(now.emissions_total)
	if timeline.size() >= 2:
		var change: float = now.emissions_total - timeline[-2].emissions_total
		text += "   [color=#%s]önceki yıla göre %+d[/color]" % [UiText.delta_color(change, false).to_html(false), roundi(change)]
	text += "\n"
	for sector in SECTORS:
		text += "%s: %d   " % [SECTORS[sector][0], roundi(now.emissions_by_sector[sector])]
	var effects := PackedStringArray()
	for def in GameState.built_definitions():
		for sector in def.emission_multipliers:
			effects.append("%s: %s %+d%%" % [def.display_name, UiText.SECTOR_NAMES.get(sector, sector), roundi(def.emission_multipliers[sector] * 100)])
	text += "\n[b]Yatırımların etkisi:[/b] " + (", ".join(effects) if effects.size() > 0 else "henüz emisyon azaltan yatırım yok")
	%EmissionText.text = text

	# Enerji ve su
	var e_demand := PackedFloat32Array()
	var e_renew := PackedFloat32Array()
	var w_demand := PackedFloat32Array()
	var w_supply := PackedFloat32Array()
	for s in timeline:
		e_demand.append(s.energy_demand)
		e_renew.append(s.renewable_energy)
		w_demand.append(s.water_demand)
		w_supply.append(s.water_supply)
	%ResourceChart.set_data([
		{"name": "Enerji talebi", "color": Color(0.98, 0.75, 0.25), "values": e_demand},
		{"name": "Yenilenebilir üretim", "color": Color(0.42, 0.82, 0.52), "values": e_renew},
		{"name": "Su talebi", "color": Color(0.45, 0.72, 1.0), "values": w_demand},
		{"name": "Su arzı", "color": Color(0.3, 0.85, 0.82), "values": w_supply}], years)
	%ResourceText.text = ("[b]Enerji[/b] · üretim (yenilenebilir) %d · tüketim %d · denge %+d · [b]yenilenebilir payı %%%d[/b] (kalanı şebekeden, fosil kaynaklı)\n" % [
			roundi(now.renewable_energy), roundi(now.energy_demand), roundi(now.renewable_energy - now.energy_demand), roundi(now.renewable_share * 100)]
			+ "[b]Su[/b] · arz %d · talep %d · denge %+d · su güvenliği %d/100\n" % [
			roundi(now.water_supply), roundi(now.water_demand), roundi(now.water_supply - now.water_demand), roundi(now.water_security)]
			+ "[color=#b8c4c2]Oyun birimi; şebekeden gelen enerji yenilenebilir üretimin karşılamadığı talebi kapatır.[/color]")

	# Ekosistem
	var eco := PackedFloat32Array()
	for s in timeline:
		eco.append(s.ecosystem_health)
	%EcoChart.set_data([{"name": "Ekosistem sağlığı", "color": Color(0.42, 0.82, 0.52), "values": eco}], years)
	var built := GameState.built_definitions()
	var green := built.filter(func(d): return d.id in [&"green_park", &"urban_farming"]).map(func(d): return d.display_name)
	var coast := built.any(func(d): return d.id == &"coastal_restoration")
	var waste_cut := 0.0
	for def in built:
		waste_cut -= def.emission_multipliers.get("waste", 0.0)
	var st := UiText.status(now.ecosystem_health)
	%EcoText.text = ("Ekosistem sağlığı [b]%d/100[/b] · [color=#%s]%s[/color]\n" % [roundi(now.ecosystem_health), st[1].to_html(false), st[0]]
			+ "Yeşil alanlar: %s\n" % (", ".join(green) if green.size() > 0 else "yok")
			+ "Kıyı ekosistemi: %s\n" % ("restore edildi" if coast else "korumasız")
			+ "Atık geri kazanım / azaltma oranı: %%%d (oyun parametresi)" % roundi(minf(waste_cut, 1.0) * 100))

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
