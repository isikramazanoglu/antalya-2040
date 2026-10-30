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
	# taban × 0.75 × 0.6: yaşam -10 → -4.5 → -5, nüfus -10 → -5, kredi -100 → -45 → -45 - 60 müdahale
	_check(result.damage.quality_of_life == -5.0 and result.damage.population == -5.0 and result.damage.credits == -105.0,
			"hasar: yaşam -5, nüfus -5, kredi -105 (%s)" % str(result.damage))
	_check(_gs.pending_crises.is_empty(), "bekleyen kriz kalmadı")
	_check(_gs.phase == &"report", "kriz sonrası yıl sonu raporu")
	var report: Dictionary = _last("year_ended")[1]
	_check(report.crisis_results.size() == 1, "rapor kriz sonucunu içeriyor")
	_check(report.stats_before.credits == credits_before and report.stats_before.population == pop_before, "rapor kriz öncesi değerlerden başlıyor")
	print("SONUÇ: ", "TAMAM" if _fail == 0 else "%d HATA" % _fail)
