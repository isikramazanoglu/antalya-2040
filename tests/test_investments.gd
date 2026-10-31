extends SceneTree
## Sahip: B. Prompt 9A'nın 18 yatırım testi: katalog, doğrulama, arsa ve bütçe kontrolü, akışlar, kombinasyonlar, kriz ve arayüz bağlantıları.
## Çalıştır: <godot> --headless --path . --script res://tests/test_investments.gd

var bus: Node
var gs: Node
var cat: Node
var fails := 0
var frame := 0
var log: Array = []


func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		_run()
		quit(1 if fails else 0)
		return true
	return false


func _build(plot: StringName, kind: StringName, id: StringName) -> void:
	bus.plot_selected.emit(plot, kind, true)
	bus.build_requested.emit(plot, id)


func _defs(ids: Array) -> Array[BuildingDefinition]:
	var out: Array[BuildingDefinition] = []
	for id in ids:
		out.append(cat.get_building(id))
	return out


func _run() -> void:
	bus = root.get_node("EventBus")
	gs = root.get_node("GameState")
	cat = root.get_node("Catalog")
	var b: BalanceConfig = cat.data.balance
	bus.build_rejected.connect(func(_p, _b, r): log.append(r))

	print("Katalog ve doğrulama")
	var ids: Array = cat.data.buildings.map(func(d): return d.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	_check(ids.size() == 12 and unique.size() == 12, "1/2) 12 yatırım, hepsi benzersiz kimlikli")
	_check(cat.data.buildings.all(func(d): return d.cost > 0 and d.upkeep_per_year >= 0), "3) hepsinin maliyeti ve gideri tanımlı")
	_check(cat.data.buildings.all(func(d): return not d.allowed_plot_kinds.is_empty() and d.scene != null and d.icon != null), "4) hepsinin arsa türü, 3D sahnesi ve önizleme görseli var")
	_check(cat.validate().is_empty(), "veri doğrulaması sorun bulmadı")
	var broken := BuildingDefinition.new()
	broken.id = &"broken"
	cat.data.buildings.append(broken)
	var problems: PackedStringArray = cat.validate()
	cat.data.buildings.pop_back()
	_check(problems.size() == 4, "doğrulama eksik maliyet, sahne, arsa türü ve kartı yakalıyor (%d sorun)" % problems.size())
	var costs: Array = cat.data.buildings.map(func(d): return d.cost)
	var total := 0
	for c in costs:
		total += c
	_check(total > b.start_credits * 3, "12 yatırımın toplamı (%d) başlangıç bütçesinin 3 katından fazla; hepsi ilk yıllarda alınamaz" % total)

	print("Arsa ve bütçe")
	_build(&"U01", &"urban", &"solar_plant")
	_check(log[-1] == &"wrong_plot_kind" and gs.plots.is_empty(), "5) güneş kent arsasına yerleştirilemedi")
	gs.stats.credits = 50
	_build(&"O01", &"open", &"solar_plant")
	_check(log[-1] == &"not_enough_credits" and gs.plots.is_empty(), "6) yetersiz bütçeyle inşaat reddedildi")
	gs.stats.credits = 5000

	print("Akışlar")
	var demand0: float = gs.stats.energy_demand
	_build(&"O01", &"open", &"solar_plant")
	_build(&"U01", &"urban", &"public_efficiency")
	_check(gs.stats.renewable_energy == 20.0 and gs.stats.energy_demand < demand0, "8) güneş üretimi artırdı, kamu verimliliği talebi düşürdü (%d → %d)" % [demand0, gs.stats.energy_demand])
	var smart: float = demand0 - 5.0 - 4.0
	_check(is_equal_approx(gs.stats.energy_demand, smart), "13) güneş + verimlilik kombinasyonu talebi ek 4 düşürdü (%.0f)" % gs.stats.energy_demand)
	var supply0: float = gs.stats.water_supply
	_build(&"O02", &"open", &"water_reuse")
	_check(gs.stats.water_supply == supply0 and gs.stats.recycled_water == 15.0 and gs.stats.recycled_water_used <= gs.stats.water_demand * b.non_potable_water_share,
			"9) geri kazanılmış su içme suyu arzına eklenmedi; yalnızca içme dışı talebi karşılıyor (%d / %d kullanılıyor)" % [gs.stats.recycled_water_used, gs.stats.recycled_water])
	_build(&"O03", &"open", &"water_storage")
	_check(gs.stats.water_supply == supply0 + 10.0 and gs.stats.recycled_water == 20.0, "9/13) su deposu arzı artırdı; depo + geri kazanım kombinasyonu geri kazanılmış suyu 20'ye çıkardı")
	var waste0: float = gs.stats.emissions_by_sector.waste
	_build(&"U02", &"urban", &"food_rescue")
	var after_food: float = gs.stats.emissions_by_sector.waste
	_build(&"O04", &"open", &"recycling_compost")
	var pop_factor: float = gs.stats.population / 500.0
	var expected_waste: float = b.base_emissions.waste * pop_factor * (1.0 - 0.10 - 0.35 - 0.10)
	_check(after_food < waste0 and is_equal_approx(gs.stats.emissions_by_sector.waste, expected_waste),
			"10/13/14) gıda kurtarma ve kompost atık emisyonunu düşürdü; kombinasyon −%%10 bir kez eklendi (%.2f)" % expected_waste)
	var tr0: float = gs.stats.emissions_by_sector.transport
	_build(&"U03", &"urban", &"transit_hub")
	_check(is_equal_approx(gs.stats.emissions_by_sector.transport, tr0 * (1.0 - 0.35 - 0.05)), "11) toplu taşıma ulaşım emisyonunu düşürdü (+ kombinasyon −%5)")

	print("Kombinasyonların tek kez sayılması")
	var syn_count: int = gs.built_definitions().filter(func(d): return d is SynergyDefinition).size()
	_check(syn_count == 4, "14) etkin kombinasyonlar listede birer kez (%d)" % syn_count)
	var eco_before: float = gs.stats.ecosystem_health
	var eco: Dictionary = EconomySimulator.compute_year(gs.get_stats(), gs.built_definitions(), b)
	_check(not eco.deltas.has("ecosystem_health") or eco.deltas.ecosystem_health == 0.0, "14) kent tarımı yokken toprak döngüsü kombinasyonu etkisiz")

	print("Krizler")
	var flood: EventDefinition = cat.get_event(&"coastal_flood")
	var none: Array[BuildingDefinition] = []
	var with_coast: Dictionary = EventManager.assess(flood, 0.6, gs.get_stats(), _defs([&"coastal_restoration"]), b)
	_check(with_coast.mitigation == 0.45 and EventManager.assess(flood, 0.6, gs.get_stats(), none, b).mitigation == 0.0, "12) kıyı yatırımı taşkın hazırlığını %45 artırıyor")
	_check(cat.get_building(&"coastal_restoration").components.size() == 2, "12) restorasyon ve erken uyarı bileşenleri ayrı tanımlı")
	var heat: EventDefinition = cat.get_event(&"heatwave")
	var heat_a: Dictionary = EventManager.assess(heat, 0.6, gs.get_stats(), gs.built_definitions(), b)
	_check(heat_a.advantages.has(&"public_efficiency") and not heat_a.advantages.any(func(id): return String(id).begins_with("syn_")),
			"16) EventManager kamu verimliliğinin sıcak avantajını görüyor; kombinasyonlar bina listesine karışmıyor")
	var cool: Dictionary = EventManager.assess(heat, 0.6, gs.get_stats(), _defs([&"green_park", &"cooling_center"]), b)
	var cool_with_syn: Array[BuildingDefinition] = _defs([&"green_park", &"cooling_center"])
	cool_with_syn.append(cat.data.synergies.filter(func(s): return s.id == &"syn_cool_city")[0])
	_check(is_equal_approx(EventManager.assess(heat, 0.6, gs.get_stats(), cool_with_syn, b).mitigation, cool.mitigation + 0.10), "13) park + serinleme kombinasyonu sıcak korumasına +%10")

	print("Arayüz")
	var ui := current_scene.get_node("UI")
	var panel := ui.get_node("BuildPanel")
	panel.open()
	var live: Array = panel.find_child("Cards", true, false).get_children().filter(func(c): return not c.is_queued_for_deletion())
	_check(live.size() == 12, "18) BuildPanel arsa seçmeden 12 yatırımı listeliyor (%d)" % live.size())
	panel.close()
	var hud_texts: Array = ui.get_node("HUD").find_child("ResourceList", true, false).find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(hud_texts.any(func(t): return t.contains("geri kazanılmış")) and hud_texts.has(str(roundi(gs.stats.emissions_total))), "17) HUD geri kazanılmış suyu ve güncel emisyonu gösteriyor")
	var lab := ui.get_node("ClimateLab")
	lab.open_tab("C · Kaynaklar")
	var lab_text := ""
	for r in lab.find_children("*", "RichTextLabel", true, false):
		lab_text += r.get_parsed_text()
	_check(lab_text.contains("Geri kazanılmış su: 20") and lab_text.contains("Gıda kurtarma merkezi") and lab_text.contains("Etkin Toplu taşıma") == false and lab_text.contains("Etkin Düşük emisyonlu toplu taşıma merkezi + Kamu binalarında enerji verimliliği"),
			"15) İklim Laboratuvarı yeni yatırımları ve etkin kombinasyonları tanıyor")
	lab.close()

	print("İşletme gideri")
	var upkeep := b.city_base_upkeep
	for id in gs.plots.values():
		upkeep += cat.get_building(id).upkeep_per_year
	var rep := {}
	bus.year_ended.connect(func(r): rep.merge(r), CONNECT_ONE_SHOT)
	bus.end_turn_requested.emit()
	_check(rep.upkeep == upkeep, "7) yıllık işletme gideri %d (şehir %d + %d bina; kombinasyonların gideri yok)" % [upkeep, b.city_base_upkeep, gs.plots.size()])
	print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
