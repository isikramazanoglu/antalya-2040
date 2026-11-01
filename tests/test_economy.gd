extends SceneTree
## Sahip: B. Prompt 4'teki 12 ekonomi/simülasyon testi, mevcut sistem ve gerçek denge değerleriyle.
## Çalıştır: <godot> --headless --path . --script res://tests/test_economy.gd

var _bus: Node
var _gs: Node
var _cat: Node
var _ctrl: Node
var _fail := 0
var _frame := 0
var _log: Array = []


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  HATA ") + msg)
	if not cond:
		_fail += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run()
		quit(1 if _fail else 0)
		return true
	return false


func _build(plot: StringName, kind: StringName, id: StringName) -> void:
	_bus.plot_selected.emit(plot, kind, true)
	_bus.build_requested.emit(plot, id)


func _last_reason() -> Variant:
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == "rejected":
			return _log[i][1]
	return null


func _run() -> void:
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	_cat = root.get_node("Catalog")
	_ctrl = current_scene.get_node("GameController")
	_bus.build_rejected.connect(func(_p, _b, r): _log.append(["rejected", r]))
	_bus.year_ended.connect(func(r): _log.append(["year_ended", r]))
	var solar: BuildingDefinition = _cat.get_building(&"solar_plant")
	var balance: BalanceConfig = _cat.data.balance

	print("TEST 1-3: güneş enerjisi")
	var energy_before: float = _gs.stats.renewable_energy
	_build(&"O01", &"open", &"solar_plant")
	_check(_gs.stats.credits == 1000 - solar.cost, "1) bütçe 1000 - %d = %d" % [solar.cost, 1000 - solar.cost])
	_check(_gs.stats.renewable_energy > energy_before and _gs.stats.renewable_share > 0.0,
			"2) yenilenebilir üretim %d → %d, pay %%%d" % [energy_before, _gs.stats.renewable_energy, roundi(_gs.stats.renewable_share * 100)])
	_check(solar.emission_multipliers.get("energy", 0.0) < 0.0, "3) emisyon etkisi tanımlı (enerji %+d%%)" % roundi(solar.emission_multipliers.energy * 100))

	print("TEST 5-7: ret durumları")
	var snapshot: Dictionary = _gs.get_stats()
	var plots_before: Dictionary = _gs.plots.duplicate()
	_build(&"O01", &"open", &"water_storage")
	_check(_last_reason() == &"plot_occupied", "7) aynı arsa ikinci kez reddedildi")
	_gs.stats.credits = 100
	snapshot.credits = 100
	_build(&"O02", &"open", &"water_storage")
	_check(_last_reason() == &"not_enough_credits", "5) yetersiz bütçe reddedildi")
	_check(_gs.get_stats() == snapshot and _gs.plots == plots_before, "6) reddedilen yatırımlarda hiçbir değer değişmedi")
	_gs.stats.credits = 1000 - solar.cost

	print("TEST 8-9: su ve park")
	var water_before: float = _gs.stats.water_security
	var supply_before: float = _gs.stats.water_supply
	_build(&"O02", &"open", &"water_storage")
	_check(_gs.stats.water_security > water_before and _gs.stats.water_supply > supply_before,
			"8) su güvenliği %d → %d, su arzı %d → %d" % [water_before, _gs.stats.water_security, supply_before, _gs.stats.water_supply])
	var eco_before: float = _gs.stats.ecosystem_health
	_build(&"U01", &"urban", &"green_park")
	var heat_mit: float = ClimateSimulator.mitigation(_gs.built_definitions(), &"heat", balance)
	_check(_gs.stats.ecosystem_health > eco_before and heat_mit > 0.0,
			"9) ekosistem %d → %d, sıcak dayanıklılığı %%%d" % [eco_before, _gs.stats.ecosystem_health, roundi(heat_mit * 100)])

	print("TEST 4 ve 12: yıllık hesap")
	var credits_before: int = _gs.stats.credits
	var expected_upkeep: int = balance.city_base_upkeep + solar.upkeep_per_year + _cat.get_building(&"water_storage").upkeep_per_year + _cat.get_building(&"green_park").upkeep_per_year
	_bus.end_turn_requested.emit()
	_bus.end_turn_requested.emit()  # aynı turda ikinci kez
	var reports := _log.filter(func(l): return l[0] == "year_ended")
	_check(reports.size() == 1, "12) aynı turda yıllık hesap bir kez çalıştı")
	var r: Dictionary = reports[0][1]
	_check(r.upkeep == expected_upkeep, "4) işletme gideri bir kez: %d" % r.upkeep)
	# Aynı yıl tamamlanan görevin ödülü de kasaya girer (su 75 → +100).
	_check(_gs.stats.credits == credits_before + r.income - r.upkeep + r.missions.reward,
			"4) kredi %d + %d gelir - %d gider + %d görev ödülü = %d" % [credits_before, r.income, r.upkeep, r.missions.reward, _gs.stats.credits])

	print("TEST 10: küresel CO2")
	var co2 := Co2Scenario.new()
	co2.years = PackedInt32Array([2040])
	co2.ppm = PackedFloat32Array([450.0])
	var stats_2040: Dictionary = _gs.get_stats()
	stats_2040.year = 2040
	var none: Array[BuildingDefinition] = []
	var with_buildings: Dictionary = ClimateSimulator.compute_year(stats_2040, _gs.built_definitions(), balance, co2)
	var without: Dictionary = ClimateSimulator.compute_year(stats_2040, none, balance, co2)
	_check(with_buildings.global_co2_ppm == without.global_co2_ppm and with_buildings.global_co2_ppm == 450.0,
			"10) yatırımlar ppm'i değiştirmiyor (iki durumda da 450)")
	_check(with_buildings.emissions_total < without.emissions_total, "10) ama yerel emisyon düşüyor (%.1f < %.1f)" % [with_buildings.emissions_total, without.emissions_total])

	print("TEST 11: sınırlar")
	_ctrl.apply_deltas({"water_security": 500.0, "ecosystem_health": -500.0, "population": -999999})
	_check(_gs.stats.water_security == 100.0 and _gs.stats.ecosystem_health == 0.0 and _gs.stats.population == 0,
			"11) endeksler 0-100 arasında, nüfus 0'ın altına inmiyor")
	_ctrl.refresh_resources()
	_check(_gs.stats.renewable_share >= 0.0 and _gs.stats.renewable_share <= 1.0, "11) nüfus 0 iken yenilenebilir payı 0-1 arasında (%.2f)" % _gs.stats.renewable_share)
	print("SONUÇ: ", "TAMAM" if _fail == 0 else "%d HATA" % _fail)
