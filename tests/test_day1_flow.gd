extends SceneTree
## Sahip: B. Gün 1 akış testi: inşaat kontrol zinciri, yıl geçişi, oyun sonu.
## Çalıştır: <godot> --headless --path . --script res://tests/test_day1_flow.gd

var _bus: Node
var _gs: Node
var _log: Array = []
var _fail := 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  HATA ") + msg)
	if not cond:
		_fail += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")


var _frame := 0
func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run()
		quit(1 if _fail else 0)
		return true
	return false


func _run() -> void:
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	for s in ["build_approved", "build_rejected", "year_started", "year_ended", "phase_changed", "game_over"]:
		_bus.connect(s, func(a = null, b = null, c = null): _log.append([s, a, b, c]))

	print("İnşaat kontrol zinciri")
	_check(_gs.phase == &"build", "başlangıç fazı build")
	_bus.plot_selected.emit(&"O01", &"open", true)
	_bus.build_requested.emit(&"O01", &"solar_plant")
	_check(_last("build_approved") != null, "güneş O01'e onaylandı")
	_check(_gs.stats.credits == 600 and is_equal_approx(_gs.stats.energy_security, 70.0), "kredi 600, enerji 70")
	_bus.build_requested.emit(&"O01", &"water_storage")
	_check(_last_reason() == &"plot_occupied", "dolu arsa reddedildi")
	_bus.plot_selected.emit(&"U01", &"urban", true)
	_bus.build_requested.emit(&"U01", &"water_storage")
	_check(_last_reason() == &"wrong_plot_kind", "yanlış arsa türü reddedildi")
	_bus.plot_selected.emit(&"O02", &"open", true)
	_bus.build_requested.emit(&"O02", &"solar_plant")
	_check(_last_reason() == &"max_count_reached", "ikinci güneş reddedildi")
	_bus.build_requested.emit(&"O02", &"nope")
	_check(_last_reason() == &"unknown_building", "tanımsız bina reddedildi")
	_gs.stats.credits = 100
	_bus.build_requested.emit(&"U01", &"green_park")
	_check(_last_reason() == &"not_enough_credits", "bütçe yetersiz reddedildi")
	_gs.stats.credits = 600
	_bus.build_requested.emit(&"U01", &"green_park")
	_check(_gs.get_building_on(&"U01") == &"green_park" and _gs.stats.credits == 450, "park U01'e, kredi 450")

	print("Yıl geçişi")
	_bus.end_turn_requested.emit()
	var report = _last("year_ended")
	_check(_gs.phase == &"report", "faz report")
	_check(report != null and report.income == 250 and report.upkeep == 120, "gelir 250, gider 100+10+10")
	_check(report.built_this_year.size() == 2, "rapor bu yıl 2 bina listeliyor")
	_check(_gs.stats.credits == 580, "kredi 450+130 = 580")
	_check(_gs.stats.population == 507, "nüfus 500 → 507 (yaşam 58)")
	_bus.build_requested.emit(&"O02", &"water_storage")
	_check(_last_reason() == &"wrong_phase", "rapor açıkken inşaat reddedildi")
	_bus.report_closed.emit()
	_check(_gs.stats.year == 2041 and _gs.phase == &"build", "2041, faz build")

	print("Oyun sonu")
	# Gün 2'den beri krizler geliyor; bu testte hepsine "müdahale etme" denir.
	_bus.crisis_started.connect(func(id, _r, _s): _bus.crisis_response_chosen.emit(id, &"do_nothing"))
	while _gs.phase == &"build":
		_bus.end_turn_requested.emit()
		_bus.report_closed.emit()
	var summary = _last("game_over")
	_check(_gs.phase == &"game_over" and _gs.stats.year == 2052, "2052'de oyun bitti")
	_check(summary != null and summary.history.size() == 13, "13 yıl sonu geçmişte")
	_check(summary.score > 0 and summary.grade != "", "puan %d, not %s" % [summary.score, summary.grade])
	print("SONUÇ: ", "TAMAM" if _fail == 0 else "%d HATA" % _fail)


func _last(sig: String):
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == sig:
			return _log[i][1]
	return null


func _last_reason():
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == "build_rejected":
			return _log[i][3]
	return null
