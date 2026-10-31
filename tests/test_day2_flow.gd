extends SceneTree
## Sahip: B. Gün 2 testi: iklim hesabı, kriz uyarısı, kriz fazı, müdahale ve hasar.
## Çalıştır: <godot> --headless --path . --script res://tests/test_day2_flow.gd

var _bus: Node
var _gs: Node
var _log: Array = []
var _fail := 0
var _frame := 0


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


func _last(sig: String) -> Variant:
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == sig:
			return _log[i]
	return null


func _next_year() -> void:
	_bus.end_turn_requested.emit()
	_bus.report_closed.emit()


func _run() -> void:
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	for s in ["year_ended", "crisis_warned", "crisis_started", "crisis_resolved", "build_rejected"]:
		_bus.connect(s, func(a = null, b = null, c = null): _log.append([s, a, b, c]))

	print("İklim hesabı")
	_bus.plot_selected.emit(&"O01", &"open", true)
	_bus.build_requested.emit(&"O01", &"solar_plant")
	_bus.end_turn_requested.emit()
	var after: Dictionary = _last("year_ended")[1].stats_after
	var expected_energy: float = 40.0 * after.population / 500.0 * 0.7
	_check(is_equal_approx(after.emissions_by_sector.energy, expected_energy), "güneş enerji emisyonunu %%30 azalttı (%.2f)" % expected_energy)
	_check(after.emissions_total < 100.0, "toplam emisyon 100'ün altında (%.1f)" % after.emissions_total)
	_check(is_equal_approx(after.risks.heat, 47.0), "sıcak riski 45 + 2 = 47")
	_check(after.global_co2_ppm == -1.0, "2040 için CO2 verisi yok, -1 (uydurma değer yok)")
	_check(is_equal_approx(after.ecosystem_health, 59.0), "ekosistem 60 → 59")
	_bus.report_closed.emit()

	print("Kriz uyarısı ve hazırlık")
	_bus.plot_selected.emit(&"U01", &"urban", true)
	_bus.build_requested.emit(&"U01", &"green_park")
	_next_year()  # 2041
	_check(_last("crisis_warned") == null, "2041 sonunda uyarı yok")
	_bus.end_turn_requested.emit()  # 2042 sonu
	var warning = _last("crisis_warned")
	_check(warning != null and warning[1].event_id == &"heatwave" and warning[1].due_year == 2043, "2042 sonunda 2043 sıcak hava uyarısı")
	_check(_last("year_ended")[1].new_warnings.size() == 1, "rapor uyarıyı içeriyor")
	_check(_gs.pending_crises.size() == 1, "bekleyen kriz 1")
	_bus.report_closed.emit()

	print("Kriz ve müdahale")
	var credits_before: int = _gs.stats.credits
	var pop_before: int = _gs.stats.population
	_bus.end_turn_requested.emit()  # 2043 sonu
	_check(_gs.phase == &"crisis", "faz crisis")
	_check(_last("crisis_started") != null and _last("crisis_started")[1] == &"heatwave", "crisis_started heatwave")
	_bus.end_turn_requested.emit()
	_check(_gs.phase == &"crisis", "kriz sürerken yıl bitirilemiyor")
	_bus.build_requested.emit(&"U02", &"cooling_center")
	_check(_last("build_rejected")[3] == &"wrong_phase", "kriz sürerken inşaat reddedildi")
	_bus.crisis_response_chosen.emit(&"heatwave", &"open_cooling")
	var result: Dictionary = _last("crisis_resolved")[1]
	_check(is_equal_approx(result.mitigation, 0.25), "park sıcak hasarını %25 azalttı")
	# Prompt 7A formülü: taban × tehlike × maruziyet × hassasiyet × (1 − uyum) × müdahale; maliyet ayrıca.
	var a: Dictionary = result.assessment
	var scale: float = a.hazard * a.exposure * a.vulnerability * (1.0 - a.mitigation) * 0.6
	_check(result.damage.quality_of_life == roundf(-10.0 * scale) and result.damage.population == roundf(-10.0 * scale)
			and result.damage.credits == roundf(-100.0 * scale - 60.0) and result.damage.energy_security == roundf(-8.0 * scale),
			"hasar formülle aynı (ölçek %.3f): %s" % [scale, str(result.damage)])
	_check(_gs.stats.credits == credits_before + int(result.damage.credits) + _last("year_ended")[1].income - _last("year_ended")[1].upkeep + _last("year_ended")[1].missions.reward,
			"kriz maliyeti kasadan bir kez düştü")
	_check(_gs.pending_crises.is_empty(), "bekleyen kriz kalmadı")
	_check(_gs.phase == &"report", "kriz sonrası yıl sonu raporu")
	var report: Dictionary = _last("year_ended")[1]
	_check(report.crisis_results.size() == 1, "rapor kriz sonucunu içeriyor")
	_check(report.stats_before.credits == credits_before and report.stats_before.population == pop_before, "rapor kriz öncesi değerlerden başlıyor")

	print("Görevler (MissionTracker)")
	var missions: Array[MissionDefinition] = root.get_node("Catalog").data.missions
	var base := {"year": 2044, "water_security": 80.0, "quality_of_life": 50.0, "emissions_total": 84.0, "ecosystem_health": 60.0}
	var r := MissionTracker.evaluate(missions, base, {})
	_check(r.completed.has(&"water_75") and r.completed.has(&"emissions_85"), "su 80 ve emisyon 84 görevleri tamam")
	var expected_reward := 0
	for m in missions:
		if m.id in [&"water_75", &"emissions_85"]:
			expected_reward += m.reward_credits
	_check(r.reward == expected_reward, "ödül iki görevin ödüllerinin toplamı (%d)" % expected_reward)
	_check(not r.completed.has(&"quality_70") and r.failed.is_empty(), "yaşam görevi sürüyor, kaçan yok")
	base.year = 2045
	base.water_security = 70.0
	r = MissionTracker.evaluate(missions, base, {&"emissions_85": &"done"})
	_check(r.failed == [&"water_75"], "2045'te su 70 ise görev kaçtı")
	_check(not r.completed.has(&"emissions_85"), "tamamlanan görev tekrar ödül vermiyor")
	print("SONUÇ: ", "TAMAM" if _fail == 0 else "%d HATA" % _fail)
