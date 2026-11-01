extends SceneTree
## Sahip: B. Aylık takvim testi: ay ilerlemesi, aylık bütçe, yıl ortası kriz, yıl sonu raporunun tutarlılığı,
## gerçek zamanlı saat (hız, durdurma, panel açıkken durma).
## Çalıştır: <godot> --headless --path . --script res://tests/test_months.gd

var _bus: Node
var _gs: Node
var _tm: Node
var _clock: Node
var _fail := 0
var _frame := 0
var _crises: Array = []
var _reports: Array = []
var _t0 := 0


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
		# Gerçek zamanlı saat: hız 3, ay 0,5 sn (yıl sonuna varmadan birkaç ay).
		print("Gerçek zamanlı saat")
		_check(not _clock.enabled, "--script ile çalışırken saat kendiliğinden kapalı")
		root.get_node("Catalog").data.balance.seconds_per_month = 0.5
		_clock.enabled = true
		_clock.set_speed(3)
		_t0 = _gs.month
	if _frame == 40:
		_check(_gs.month > _t0 and _gs.phase == &"build", "saat ayları kendiliğinden ilerletiyor (%d → %d)" % [_t0, _gs.month])
		_clock.set_speed(0)
		_t0 = _gs.month
	if _frame == 70:
		_check(_gs.month == _t0 and _gs.phase == &"build", "Durdur'da ay ilerlemiyor")
		_clock.set_speed(3)  # açık panel olmasaydı bu sürede ay ilerlerdi (yukarıdaki kontrol)
		var panel := Control.new()
		panel.add_to_group("ui_panel")
		current_scene.add_child(panel)
		_t0 = _gs.month
	if _frame == 110:
		_check(_gs.month == _t0 and _gs.phase == &"build", "panel açıkken zaman duruyor")
		print("SONUÇ: " + ("TAMAM" if _fail == 0 else "%d HATA" % _fail))
		quit(1 if _fail else 0)
		return true
	return false


func _months(n: int) -> void:
	for i in n:
		_tm.advance_month()


func _run() -> void:
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	var gc: Node = current_scene.find_child("GameController", true, false)
	_tm = gc.turn_manager
	_clock = gc.get_node("MonthClock")
	_bus.crisis_started.connect(func(id, _r, _s): _crises.append([id, _gs.stats.year, _gs.month]))
	_bus.year_ended.connect(func(r): _reports.append(r))

	print("Ay ilerlemesi ve aylık bütçe")
	_check(_gs.month == 1 and _gs.stats.year == 2040, "oyun Ocak 2040'ta başlıyor")
	var c0: int = _gs.stats.credits
	_months(1)
	_check(_gs.month == 2 and _gs.stats.credits != c0, "Şubat'a geçildi, aylık bütçe işlendi (%d → %d)" % [c0, _gs.stats.credits])
	_months(10)
	_check(_gs.month == 12 and _gs.phase == &"build", "Aralık 2040, hâlâ inşaat fazı")
	_months(1)
	_check(_gs.phase == &"report" and _reports.size() == 1, "Aralık bitince yıl sonu raporu")
	var r: Dictionary = _reports[0]
	var before: Dictionary = r.stats_before
	var after: Dictionary = r.stats_after
	var sum: int = before.credits + r.income - r.upkeep - r.investment_cost + r.missions.reward
	for cr in r.crisis_results:
		sum += int(cr.damage.get("credits", 0))
	_check(sum == after.credits, "rapor bütçesi tutarlı: başlangıç %d + gelir − gider − yatırım + ödül = %d (yıl sonu %d)" % [before.credits, sum, after.credits])
	_check(before.credits == c0, "rapor yılın başından (Ocak) başlıyor")
	_bus.report_closed.emit()
	_check(_gs.month == 1 and _gs.stats.year == 2041, "yeni yıl Ocak'tan başlıyor")

	print("Yıl ortası kriz (sıcak hava dalgası Temmuz 2043)")
	for y in 2:
		_months(12)
		_bus.report_closed.emit()
	_check(_gs.stats.year == 2043 and _gs.pending_crises.size() > 0, "2043 başı: bekleyen kriz uyarısı var")
	_months(5)
	_check(_gs.month == 6 and _crises.is_empty(), "Haziran'a kadar kriz yok")
	_months(1)
	_check(_crises.size() == 1 and _crises[0][2] == 7 and _gs.phase == &"crisis", "Temmuz'da kriz başladı, faz kriz")
	_tm.advance_month()
	_check(_gs.month == 7, "kriz açıkken takvim ilerlemiyor")
	_bus.crisis_response_chosen.emit(_crises[0][0], &"do_nothing")
	_check(_gs.phase == &"build" and _gs.month == 7, "müdahaleden sonra inşaat fazı, takvim Temmuz'dan devam")
	_months(6)
	_check(_reports.size() == 4 and _reports[3].crisis_results.size() == 1, "2043 raporu Temmuz krizini içeriyor")
	_bus.report_closed.emit()

	print("Yıl sonuna atla")
	_months(3)
	_bus.end_turn_requested.emit()
	_check(_gs.phase == &"report" and _reports.size() == 5, "Nisan'da 'Yıl sonuna atla' raporu açtı")
	_bus.report_closed.emit()
	_check(_gs.month == 1 and _gs.stats.year == 2045, "atlamadan sonra Ocak 2045")
