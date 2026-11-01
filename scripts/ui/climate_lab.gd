extends PanelContainer
## Sahip: B. İklim Laboratuvarı (Prompt 8): A emisyonlar, B küresel CO₂, C kaynaklar, D riskler ve dayanıklılık, Sözlük, Öğrenme.
## Hesap yapmaz: GameState, ClimateSimulator ve EventManager'ın değerlerini ve salt okunur fonksiyonlarını gösterir.
## İçerik panel açılınca ve sekme değişince yeniden kurulur; arka planda güncellenmez.

const SECTORS := {"energy": ["Elektrik", Color(0.98, 0.75, 0.25)], "transport": ["Ulaşım", Color(0.45, 0.72, 1.0)],
		"buildings": ["Binalar", Color(0.85, 0.45, 0.35)], "waste": ["Çöp", Color(0.55, 0.85, 0.5)]}
const RISKS := {"drought": "Kuraklık", "heat": "Sıcak hava dalgası", "coastal_flood": "Kıyı taşkını"}
const SECTIONS := ["Karbon", "Dünyanın havası", "Su ve elektrik", "Tehlikeler", "Sözlük", "Öğrendiklerim"]
## Her sayfanın başında hiç bilmeyen birinin de anlayacağı tek cümle.
const INTROS := {
	"Karbon": "Elektrik üretirken, araba kullanırken, binaları ısıtırken ve çöpten havaya [b]karbon[/b] (karbondioksit gibi gazlar) çıkar. Bu gazlar Dünya'yı ısıtır. Burada senin şehrinin ne kadar karbon çıkardığını görürsün: [b]az olması iyidir.[/b]",
	"Dünyanın havası": "Bütün dünyanın havasındaki karbondioksit yıllardır artıyor. Bu grafik gerçek ölçümdür. Tek bir şehir bu eğriyi değiştiremez ama her şehrin payı vardır.",
	"Su ve elektrik": "Şehrinin ne kadar su ve elektriğe ihtiyacı olduğunu, bunun ne kadarını temiz yollarla karşıladığını burada görürsün.",
	"Tehlikeler": "İklim ısındıkça kuraklık, sıcak hava dalgası ve kıyı taşkını daha sık olur. Burada her tehlikenin ne kadar büyük olduğunu ve şehrinin ne kadar hazır olduğunu görürsün.",
	"Sözlük": "Oyunda geçen kelimelerin kısa ve kolay anlamları.",
	"Öğrendiklerim": "Yaptığın yatırımlarla neler öğrendiğini burada görürsün.",
}
const TAG_SIM := "[color=#4dd9d1]OYUN HESABI[/color]"
const TAG_SCI := "[color=#73b8ff]GERÇEK ÖLÇÜM[/color]"

var _tabs: TabContainer
var _pages: Dictionary = {}  # bölüm adı -> VBoxContainer
var _selected_term: GlossaryTerm


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("climate_lab")
	hide()
	%CloseButton.pressed.connect(close)
	_tabs = %Tabs
	for title in SECTIONS:
		var scroll := ScrollContainer.new()
		scroll.name = title
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 14)
		scroll.add_child(page)
		_tabs.add_child(scroll)
		_pages[title] = page
	_tabs.tab_changed.connect(func(_i): if visible: _refresh())
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


## HUD "Bilgi arşivi": Laboratuvarı istenen sekmede açar.
func open_tab(title: String) -> void:
	_tabs.current_tab = SECTIONS.find(title)
	open()


func close() -> void:
	hide()


func _education() -> Node:
	return get_tree().get_first_node_in_group("education")


func _refresh() -> void:
	var title: String = SECTIONS[_tabs.current_tab]
	var page: VBoxContainer = _pages[title]
	for child in page.get_children():
		child.free()
	if _tabs.current_tab < 4 and _education():
		_education().mark_section(title)
	_card(page, _rich(INTROS.get(title, "")))
	match _tabs.current_tab:
		0: _build_emissions(page)
		1: _build_co2(page)
		2: _build_resources(page)
		3: _build_risks(page)
		4: _build_glossary(page)
		5: _build_learning(page)


# --- Ortak parçalar ---

func _timeline() -> Array:
	var t: Array = GameState.history.duplicate()
	t.append(GameState.get_stats())
	return t


func _years(timeline: Array) -> PackedStringArray:
	var y := PackedStringArray()
	for s in timeline:
		y.append(str(s.year))
	return y


func _rich(text: String, min_h := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = text
	r.custom_minimum_size.y = min_h
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _card(parent: Control, body: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(body)
	parent.add_child(p)
	return p


## Grafik kartı: başlık, birim · dönem · veri türü, grafik, açıklama/kaynak.
func _chart_card(parent: Control, title: String, meta: String, chart: Control, note := "", chart_name := "") -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_rich("[b]%s[/b]\n[font_size=13][color=#b8c4c2]%s[/color][/font_size]" % [title, meta]))
	if chart_name != "":
		chart.name = chart_name
	chart.custom_minimum_size.y = maxf(chart.custom_minimum_size.y, 220.0)
	box.add_child(chart)
	if note != "":
		box.add_child(_rich("[font_size=13][color=#b8c4c2]%s[/color][/font_size]" % note))
	_card(parent, box)


func _kpis(parent: Control, items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for it in items:
		var box := VBoxContainer.new()
		box.add_child(_rich("[font_size=13][color=#b8c4c2]%s[/color][/font_size]" % it[0]))
		box.add_child(_rich("[font_size=24][b]%s[/b][/font_size]" % it[1]))
		if it.size() > 2:
			box.add_child(_rich("[font_size=13]%s[/font_size]" % it[2]))
		_card(row, box)
	parent.add_child(row)


func _delta_text(value: float, higher_is_better: bool, unit := "") -> String:
	return "[color=#%s]%s%s[/color]" % [UiText.delta_color(roundf(value), higher_is_better).to_html(false), UiText.format_delta(value), unit]


## Son tamamlanan iki yıl sonu arasındaki fark; tek yıl varsa "—".
func _last_year_change(key: String, higher_is_better: bool) -> String:
	var h := GameState.history
	if h.size() < 2:
		return "—"
	return _delta_text(float(h[-1][key]) - float(h[-2][key]), higher_is_better)


func _start_total() -> float:
	var total := 0.0
	for v in Catalog.data.balance.base_emissions.values():
		total += v
	return total


# --- A · Emisyonlar ---

func _build_emissions(page: VBoxContainer) -> void:
	var timeline := _timeline()
	var now: Dictionary = timeline[-1]
	var start := _start_total()
	var cumulative := 0.0  # başlangıç düzeyine göre yıllar boyunca biriken fark (birim·yıl)
	for s in GameState.history:
		cumulative += start - s.emissions_total
	_kpis(page, [
		["Şehrin karbon salımı", str(roundi(now.emissions_total)), "başta %d · az olması iyi" % roundi(start)],
		["Geçen yıla göre", _last_year_change("emissions_total", false), "artı kötü, eksi iyi"],
		["Başlangıca göre", _delta_text((now.emissions_total - start) / start * 100.0, false, "%"), "%d yılından bu yana" % Catalog.data.balance.start_year],
		["Temiz elektrik payı", "%%%d" % roundi(now.renewable_share * 100), "elektriğin ne kadarı temiz"],
		["Toplam tasarruf", _delta_text(cumulative, true), "yıllar boyunca az çıkan karbon"],
	])
	var series := []
	for sector in SECTORS:
		var values := PackedFloat32Array()
		for s in timeline:
			values.append(s.emissions_by_sector[sector])
		series.append({"name": SECTORS[sector][0], "color": SECTORS[sector][1], "values": values})
	var chart := LineChart.new()
	chart.set_data(series, _years(timeline))
	_chart_card(page, "Karbon nereden geliyor?", "yıllara göre · %s–%d · %s" % [_years(timeline)[0], now.year, TAG_SIM], chart,
			"Bu sayılar oyun puanıdır; gerçek ton ölçümü (tCO₂e) değildir.", "EmissionChart")
	var bars := []
	for sector in SECTORS:
		bars.append({"label": SECTORS[sector][0], "value": now.emissions_by_sector[sector] / now.emissions_total * 100.0, "color": SECTORS[sector][1]})
	var bar := BarChart.new()
	bar.set_data(bars, "%")
	_chart_card(page, "Karbonun yüzde kaçı nereden?", "%d · %s" % [now.year, TAG_SIM], bar)
	var why := "[b]Karbon neden değişti?[/b]\n"
	why += "• Şehirde insan arttıkça karbon da artar (şu an %d kişi, başta 500).\n" % now.population
	var any := false
	for def in GameState.built_definitions():
		for sector in def.emission_multipliers:
			any = true
			why += "• %s: %s kaynaklı karbon %+d%%. %s\n" % [def.display_name, SECTORS[sector][0], roundi(def.emission_multipliers[sector] * 100),
					def.info_card.climate_link if def.info_card else ""]
	if not any:
		why += "• Henüz karbonu azaltan bir yatırımın yok. Güneş enerjisi, toplu taşıma, kompost ve verimli binalar karbonu azaltır.\n"
	_card(page, _rich(why))


# --- B · Küresel CO₂ ---

func _build_co2(page: VBoxContainer) -> void:
	var co2: Co2Scenario = Catalog.data.co2
	if co2 and co2.years.size() > 1:
		var chart := LineChart.new()
		chart.set_data([{"name": "Havadaki CO₂", "color": Color(0.45, 0.72, 1.0), "values": co2.ppm}],
				PackedStringArray([str(co2.years[0]), str(co2.years[-1])]), "")
		_chart_card(page, "Dünyanın havasındaki karbondioksit (CO₂)", "ppm (milyonda bir) · %d–%d · %s · %s" % [co2.years[0], co2.years[-1], TAG_SCI, co2.scenario_name], chart,
				"Son ölçüm: %.2f ppm (%d). Kaynak: %s" % [co2.ppm[-1], co2.years[-1], co2.source], "Co2Chart")
	else:
		_card(page, _rich("[b]Atmosferik CO₂[/b]\nVeri yok: ölçüm dosyası yüklenemedi."))
	_card(page, _rich("[b]Gelecek tahmini yok.[/b]\n%d–%d yılları için tahmin göstermiyoruz; yalnızca bugüne kadar yapılmış gerçek ölçümleri gösteriyoruz." % [
			Catalog.data.balance.start_year, Catalog.data.balance.end_year]))
	_card(page, _rich("[b]Benim şehrim bu eğriyi neden hemen değiştirmiyor?[/b]\nŞehrinin karbon puanı yalnızca senin şehrini gösterir. Havadaki karbondioksit ise bütün dünyadan yıllarca birikir. Güneş tesisi kurunca şehrinin puanı düşer ama dünya eğrisi anında değişmez; çok sayıda şehir ve ülke birlikte azaltınca değişir."))
	for id in [&"carbon_dioxide", &"greenhouse_gases", &"greenhouse_effect", &"ppm", &"co2e", &"carbon_footprint", &"climate_change"]:
		var g := _term(id)
		if g:
			_card(page, _rich(_term_text(g, false)))


# --- C · Kaynaklar ---

func _build_resources(page: VBoxContainer) -> void:
	var timeline := _timeline()
	var now: Dictionary = timeline[-1]
	var grid: float = maxf(now.energy_demand - now.renewable_energy, 0.0)
	_card(page, _rich("[b]Enerji[/b]  " + TAG_SIM))
	_kpis(page, [
		["Toplam elektrik", str(roundi(now.renewable_energy + grid)), "temiz + kömür ve doğalgaz"],
		["İhtiyaç", str(roundi(now.energy_demand)), "geçen yıla göre %s" % _last_year_change("energy_demand", false)],
		["Temiz elektrik", str(roundi(now.renewable_energy)), "güneş gibi; geçen yıla göre %s" % _last_year_change("renewable_energy", true)],
		["Temiz elektrik payı", "%%%d" % roundi(now.renewable_share * 100), ""],
		["Temiz elektrik farkı", _delta_text(now.renewable_energy - now.energy_demand, true), "eksik kısım kömür ve doğalgazdan gelir"],
	])
	var e_demand := PackedFloat32Array()
	var e_ren := PackedFloat32Array()
	var e_grid := PackedFloat32Array()
	var w_sup := PackedFloat32Array()
	var w_dem := PackedFloat32Array()
	var eco := PackedFloat32Array()
	for s in timeline:
		e_demand.append(s.energy_demand)
		e_ren.append(s.renewable_energy)
		e_grid.append(maxf(s.energy_demand - s.renewable_energy, 0.0))
		w_sup.append(s.water_supply)
		w_dem.append(s.water_demand)
		eco.append(s.ecosystem_health)
	var years := _years(timeline)
	var range_text := "%s–%d" % [years[0], now.year]
	var ec := LineChart.new()
	ec.set_data([{"name": "İhtiyaç", "color": Color(0.98, 0.75, 0.25), "values": e_demand},
			{"name": "Temiz elektrik", "color": Color(0.42, 0.82, 0.52), "values": e_ren},
			{"name": "Kömür ve doğalgaz", "color": Color(0.7, 0.7, 0.75), "values": e_grid}], years)
	_chart_card(page, "Elektrik: ihtiyaç ve üretim", "%s · %s" % [range_text, TAG_SIM], ec,
			"Temiz elektrik yetmezse eksik kısım kömür ve doğalgaz santrallerinden gelir.", "ResourceChart")
	_card(page, _rich("[b]Su[/b]  %s\nŞehrin suyu %d · ihtiyaç %d · fark %s · su puanı %d/100\nTemizlenip yeniden kullanılan su: %d üretiliyor, %d kullanılıyor (sulama ve temizlik için; içilmez)\nKuraklığa hazırlık: yatırımların kuraklık zararını %%%d azaltır." % [
			TAG_SIM, roundi(now.water_supply), roundi(now.water_demand), _delta_text(now.water_supply + now.recycled_water_used - now.water_demand, true), roundi(now.water_security),
			roundi(now.recycled_water), roundi(now.recycled_water_used),
			roundi(ClimateSimulator.mitigation(GameState.built_definitions(), &"drought", Catalog.data.balance) * 100)]))
	var wc := LineChart.new()
	wc.set_data([{"name": "Su arzı", "color": Color(0.3, 0.85, 0.82), "values": w_sup}, {"name": "Su talebi", "color": Color(0.45, 0.72, 1.0), "values": w_dem}], years)
	_chart_card(page, "Su arzı ve talebi", "oyun birimi/yıl · %s · %s" % [range_text, TAG_SIM], wc)
	# Kontrol ve testler için tek satırlık özet (aynı değerler).
	var summary := _rich("[b]Özet:[/b] temiz elektrik %d · ihtiyaç %d · [b]temiz elektrik payı %%%d[/b] · su %d / ihtiyaç %d" % [
			roundi(now.renewable_energy), roundi(now.energy_demand), roundi(now.renewable_share * 100), roundi(now.water_supply), roundi(now.water_demand)])
	summary.name = "ResourceText"
	_card(page, summary)

	var waste_cut := 0.0
	var waste_built := PackedStringArray()
	for def in GameState.built_definitions():
		var m: float = def.emission_multipliers.get("waste", 0.0)
		if m < 0.0:
			waste_cut -= m
			waste_built.append(def.display_name)
	var start_waste: float = Catalog.data.balance.base_emissions.waste
	_card(page, _rich("[b]Çöp[/b]  %s\nÇöpten çıkan karbon: %d (başta %d)\nÇöp azaltma: %%%d\nKompost / geri dönüşüm / gıda kurtarma: %s\n[color=#b8c4c2]Oyun çöpün kaç ton olduğunu değil, çöpten çıkan karbonu hesaplar.[/color]" % [
			TAG_SIM, roundi(now.emissions_by_sector.waste), roundi(start_waste), roundi(minf(waste_cut, 1.0) * 100), ", ".join(waste_built) if waste_built.size() > 0 else "henüz yok"]))

	var syn_text := "[b]Birlikte daha güçlü yatırımlar[/b]  %s\n" % TAG_SIM
	var built_ids := GameState.plots.values()
	for syn in Catalog.data.synergies:
		var active := syn.requires.all(func(id): return built_ids.has(id))
		var names := syn.requires.map(func(id): return Catalog.get_building(id).display_name)
		syn_text += "[color=#%s]%s[/color] %s — %s\n" % [("6bd185" if active else "b8c4c2"), "Çalışıyor" if active else "Henüz yok", " + ".join(names), syn.short_description]
	_card(page, _rich(syn_text))

	var built := GameState.built_definitions()
	var green := built.filter(func(d): return d.id in [&"green_park", &"urban_farming"]).map(func(d): return d.display_name)
	var st := UiText.status(now.ecosystem_health)
	var eco_chart := LineChart.new()
	eco_chart.set_data([{"name": "Doğa", "color": Color(0.42, 0.82, 0.52), "values": eco}], years)
	_chart_card(page, "Doğa (parklar, kıyı, bitkiler)", "0–100 · %s · %s" % [range_text, TAG_SIM], eco_chart,
			"Şu an %d/100 (%s) · Yeşil alanlar: %s · Kıyı: %s · Sıcağa hazırlık: %%%d" % [
			roundi(now.ecosystem_health), st[0], ", ".join(green) if green.size() > 0 else "yok",
			"onarıldı" if built.any(func(d): return d.id == &"coastal_restoration") else "korumasız",
			roundi(ClimateSimulator.mitigation(built, &"heat", Catalog.data.balance) * 100)], "EcoChart")


# --- D · Riskler ve dayanıklılık ---

func _build_risks(page: VBoxContainer) -> void:
	var now := GameState.get_stats()
	var b: BalanceConfig = Catalog.data.balance
	var built := GameState.built_definitions()
	var built_ids := built.map(func(d): return d.id)
	_card(page, _rich("Tehlike puanı 0–100 arasıdır: büyükse tehlike büyüktür. Bu bir oyun puanıdır, gerçek bir tahmin değildir. %s" % TAG_SIM))
	for risk_type in RISKS:
		var raw := ClimateSimulator.raw_risk(risk_type, now.year, b)
		var mit := ClimateSimulator.mitigation(built, risk_type, b)
		var st := UiText.status(100.0 - float(now.risks[risk_type]))
		var t := "[b][font_size=20]%s[/font_size][/b]\n" % RISKS[risk_type]
		t += "Durum: [color=#%s]%s[/color] · tehlike %d · hazırlığın %%%d · kalan tehlike %d\n" % [st[1].to_html(false), st[0], roundi(raw), roundi(mit * 100), roundi(now.risks[risk_type])]
		var missing := PackedStringArray()
		t += "Koruyan yatırımlar: "
		var parts := PackedStringArray()
		for def in Catalog.data.buildings:
			if def.risk_reduction.get(risk_type, 0.0) > 0.0:
				var has := built_ids.has(def.id)
				parts.append("%s [color=#%s](%s)[/color]" % [def.display_name, (UiText.C_GOOD if has else UiText.C_MUTED).to_html(false), "var" if has else "yok"])
				if not has:
					missing.append(def.display_name)
		t += ", ".join(parts) + "\n"
		var event := _event_for(risk_type)
		if event:
			var unlocked := EventManager.available_responses(event, built).filter(func(r): return r.required_building != &"").map(func(r): return r.label)
			t += "Krizde açılan seçenekler: %s\n" % (", ".join(unlocked) if unlocked.size() > 0 else "yok")
			var pending := GameState.pending_crises.filter(func(w): return w.event_id == event.id)
			t += "Uyarı: %s\n" % ("[color=#ffbf66]%s · %s %d[/color]" % [event.display_name, UiText.MONTHS[event.month - 1], pending[0].due_year] if pending.size() > 0 else "yok")
			var past := GameState.crisis_log.filter(func(r): return r.event_id == event.id)
			if past.size() > 0:
				var last: Dictionary = past[-1]
				var response := EventManager.find_response(event, last.response_id)
				t += "Son kriz: %d · ne yaptın: %s · yatırımların zararı %%%d azalttı\n" % [last.year, response.label if response else str(last.response_id), roundi(last.mitigation * 100)]
			else:
				t += "Son kriz: henüz olmadı\n"
		if missing.size() > 0:
			t += "[color=#4dd9d1]Öneri:[/color] korunmak için şunları kurabilirsin: %s." % ", ".join(missing)
		else:
			t += "[color=#6bd185]Bu tehlikeye karşı bütün koruyucu yatırımları kurdun![/color]"
		_card(page, _rich(t))


func _event_for(risk_type: StringName) -> EventDefinition:
	for e in Catalog.data.events:
		if e.risk_type == risk_type:
			return e
	return null


# --- Sözlük ---

func _term(id: StringName) -> GlossaryTerm:
	for g in Catalog.data.glossary:
		if g.id == id:
			return g
	return null


func _term_text(g: GlossaryTerm, full := true) -> String:
	var t := "[b]%s[/b]\n%s\n[color=#b8c4c2]Örnek:[/color] %s\n" % [g.title, g.definition, g.example]
	if full:
		t += "[color=#4dd9d1]Oyunda:[/color] %s\n" % g.game_link
	for s in g.sources:
		t += "[font_size=12][color=#b8c4c2]Kaynak: %s[/color][/font_size]\n" % s
	return t


func _build_glossary(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 300
	var detail := _rich("", 300)
	detail.name = "GlossaryDetail"
	for g in Catalog.data.glossary:
		var button := Button.new()
		button.text = g.title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_term.bind(g, detail))
		list.add_child(button)
	row.add_child(list)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(detail)
	_card(row, box)
	page.add_child(row)
	if Catalog.data.glossary.is_empty():
		detail.text = "Sözlük verisi yüklenemedi."
	else:
		_show_term(_selected_term if _selected_term else Catalog.data.glossary[0], detail)


func _show_term(g: GlossaryTerm, detail: RichTextLabel) -> void:
	_selected_term = g
	detail.text = _term_text(g)
	if _education():
		_education().mark_term(g.id)


# --- Öğrenme ---

func _build_learning(page: VBoxContainer) -> void:
	var t := "[b]Öğrenme görevleri[/b]  [color=#b8c4c2](yatırım yaparak tamamlanır)[/color]\n"
	for m in Catalog.data.missions:
		if m.category != &"learning":
			continue
		var done: bool = GameState.missions.get(m.id) == &"done"
		t += "%s [b]%s[/b]%s\n    %s\n" % ["[color=#6bd185]✓ Tamam ·[/color]" if done else "[color=#fad159]Sırada ·[/color]", m.title, " · ödül %d kredi" % m.reward_credits if m.reward_credits > 0 else "", m.description]
		if m.info_card:
			t += "    [color=#b8c4c2]İlgili bilgi kartı: %s[/color]\n" % m.info_card.title
	t += "[font_size=13][color=#b8c4c2]Görevler her yılın sonunda kontrol edilir. Öğrenme görevleri para vermez; öğrenmeyi ödüllendirir.[/color][/font_size]"
	_card(page, _rich(t))
	var p: Dictionary = _education().progress() if _education() else {}
	if p.is_empty():
		return
	_kpis(page, [
		["Biten görev", "%d / %d" % [p.tasks_done, p.tasks_total]],
		["Okunan bilgi kartı", "%d / %d" % [p.cards_seen, p.cards_total]],
		["Bakılan kelime", "%d / %d" % [p.terms_viewed, p.terms_total]],
		["Gezilen sayfa", "%d / %d" % [p.sections_viewed, p.sections_total]],
	])
	_card(page, _rich("[color=#b8c4c2]Bu sayılar neleri açıp baktığını gösterir; ne kadar öğrendiğini ölçmez.[/color]"))
