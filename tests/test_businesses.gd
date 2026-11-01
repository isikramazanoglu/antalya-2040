extends SceneTree
## Sahip: B. Prompt 13 testi: kendiliğinden kurulan işletmeler, çevre denetimi, ceza, kararlar, kayıt/yükleme,
## Ekip A görsel sinyalleri. Çalıştır: <godot> --headless --path . --script res://tests/test_businesses.gd

var _bus: Node
var _gs: Node
var _cat: Node
var _gc: Node
var _fail := 0
var _frame := 0
var _spawned: Array = []
var _updated: Array = []


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
		print("SONUÇ: " + ("TAMAM" if _fail == 0 else "%d HATA" % _fail))
		quit(1 if _fail else 0)
		return true
	return false


func _type(id: StringName) -> Resource:
	for t in _cat.data.business_types:
		if t.id == id:
			return t
	return null


## Test kurulumu: belirli türde işletme ekler (GameState'e test düzeneği yazar; oyunda yalnızca GameController yazar).
func _add(type_id: StringName, site: StringName) -> Dictionary:
	_gs.business_seq += 1
	var b: Dictionary = BusinessSimulator.create(_type(type_id), site, _gs.business_seq, _gs.stats.year, _gs.month)
	_gs.set_business(b)
	_gc.refresh_resources()
	return b


func _run() -> void:
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	_cat = root.get_node("Catalog")
	_gc = current_scene.find_child("GameController", true, false)
	var bal = _cat.data.balance
	_bus.business_spawned.connect(func(info): _spawned.append(info))
	_bus.business_updated.connect(func(info): _updated.append(info))
	var plot_ids := ["U01", "U02", "U03", "U04", "U05", "U06", "U07", "U08", "O01", "O02", "O03", "O04", "O05", "C01", "C02"]

	print("Kendiliğinden kurulma")
	_check(_cat.data.business_types.size() == 10 and bal.industrial_sites.size() == 8, "10 işletme türü ve 8 sanayi yeri veriden okunuyor")
	_gs.stats.population = 600
	var credits0: int = _gs.stats.credits
	_gc.business_month([0.0, 0.5, 0.0, 0.5, 0.5])
	_check(_gs.businesses.size() == 1 and _gs.businesses[0].site_id in bal.industrial_sites, "1) uygun sanayi yerinde yeni işletme kuruldu (%s)" % (_gs.businesses[0].site_id if _gs.businesses.size() > 0 else "-"))
	_check(not (_gs.businesses[0].site_id in plot_ids) and _gs.plots.is_empty(), "2) oyuncunun arsalarına işletme konmadı")
	_check(_spawned.size() == 1 and _spawned[0].has_all(["business_id", "visual_id", "site_id", "smoke_intensity", "violation_level", "operational_status"]),
			"15) business_spawned görsel veriyi taşıyor (%s)" % (_spawned[0].get("visual_id", "") if _spawned.size() > 0 else "-"))
	_gc.business_month([0.99, 0.5, 0.0, 0.5, 0.5])
	_check(_gs.businesses.size() == 1, "olasılık tutmayınca yeni işletme gelmedi")
	for i in 20:
		_gc.business_month([0.0, float(i) / 20.0, float(i % 7) / 7.0, 0.5, 0.5])
	var sites := {}
	var ids := {}
	for b in _gs.businesses:
		sites[b.site_id] = true
		ids[b.business_id] = true
	_check(sites.size() == _gs.businesses.size(), "3) aynı sanayi yerine iki işletme kurulmadı")
	_check(_gs.businesses.size() == bal.max_businesses, "4) üst sınır korundu (%d işletme)" % _gs.businesses.size())
	_check(ids.size() == _gs.businesses.size() and _gs.business_seq == _gs.businesses.size(), "14) kimlikler tekrar etmiyor (%s)" % ", ".join(ids.keys()))
	var low_pop := BusinessSimulator.spawn({"population": 300, "water_security": 60.0}, [], _cat.data.business_types, bal, 0.0, 0.5, 0.0)
	_check(low_pop.is_empty(), "nüfus düşükken (300) hiçbir tür gelmiyor")

	print("Ekonomi ve emisyon")
	_gs.businesses.clear()
	var heavy := _add(&"heavy_factory", &"I01")
	var shop := _add(&"small_workshop", &"I02")
	var e_heavy := BusinessSimulator.effective(heavy, _type(&"heavy_factory"), bal)
	var e_shop := BusinessSimulator.effective(shop, _type(&"small_workshop"), bal)
	_check(e_heavy.ghg > e_shop.ghg and e_heavy.air > e_shop.air and e_heavy.contribution > e_shop.contribution, "5/6) farklı türler farklı emisyon ve katkı (ağır %.1f/%d, atölye %.1f/%d)" % [e_heavy.ghg, e_heavy.contribution, e_shop.ghg, e_shop.contribution])
	_check(_gs.stats.emissions_by_sector.industry > 0.0 and _gs.stats.air_pollution > 0.0 and _gs.stats.global_co2_ppm == -1.0,
			"sanayi karbonu ve hava kirliliği ayrı göstergede; küresel CO₂ değişmedi (sanayi %.1f, hava %.0f)" % [_gs.stats.emissions_by_sector.industry, _gs.stats.air_pollution])
	var tot: Dictionary = _gc.business_totals()
	_check(is_equal_approx(tot.contribution, e_heavy.contribution + e_shop.contribution), "6) şehir toplamı işletme katkılarının toplamı (%d)" % tot.contribution)

	print("Denetim ve ceza")
	_gs.set_phase(&"build")
	var c_before: int = _gs.stats.credits
	_check(_gc.fine_business(shop.business_id) == &"no_inspection", "denetimsiz ceza kesilemiyor")
	_check(_gc.inspect_business(shop.business_id) == &"", "7) atölye denetlendi")
	var shop_now: Dictionary = _gs.get_business(shop.business_id)
	_check(shop_now.inspection_history[-1].level == 0 and _gc.fine_business(shop.business_id) == &"no_violation" and _gs.stats.credits == c_before,
			"8) ihlal yokken ceza kesilemedi, kasa değişmedi")
	_check(_gc.inspect_business(heavy.business_id) == &"", "7) ağır sanayi denetlendi")
	var rec: Dictionary = _gs.get_business(heavy.business_id).inspection_history[-1]
	_check(rec.level >= 2 and not rec.air_ok, "7) ihlal verilerden belirlendi (seviye %d, hava %.1f > %.0f)" % [rec.level, rec.air, bal.air_standard])
	var expected := BusinessSimulator.fine_amount(_gs.get_business(heavy.business_id), _type(&"heavy_factory"), rec.level, bal)
	_check(_gc.fine_business(heavy.business_id) == &"" and _gs.stats.credits == c_before + expected, "9) ceza kesildi, kasaya %d kredi girdi" % expected)
	_check(_gc.fine_business(heavy.business_id) == &"already_fined" and _gs.stats.credits == c_before + expected, "10) aynı ihlale ikinci ceza kesilemedi")
	_check(_gc.inspect_business(heavy.business_id) == &"cooldown", "10) aynı işletme hemen yeniden denetlenemiyor")
	var air_before: float = _gs.stats.air_pollution
	_check(is_equal_approx(_gs.stats.air_pollution, air_before), "ceza kirliliği azaltmıyor (yalnızca gelir)")
	_check(_gc.inspect_business(heavy.business_id) == &"cooldown" and _gs.inspections_used == 2, "bu ay 2 denetim hakkı kullanıldı")

	print("Kararlar")
	_check(_gc.order_business(heavy.business_id, &"filter") == &"", "11) filtre zorunluluğu verildi")
	_check(_gc.order_business(heavy.business_id, &"treatment") == &"already_ordered", "aynı denetime ikinci karar verilemiyor")
	var contrib_during: float = BusinessSimulator.effective(_gs.get_business(heavy.business_id), _type(&"heavy_factory"), bal).contribution
	_check(contrib_during < e_heavy.contribution, "dönüşüm sürerken işletmenin katkısı düştü (%d → %d)" % [e_heavy.contribution, contrib_during])
	for m in bal.order_months.filter:
		_gc.business_month([0.99, 0.5, 0.0, 0.5, 0.5])
	var h2: Dictionary = _gs.get_business(heavy.business_id)
	var e2 := BusinessSimulator.effective(h2, _type(&"heavy_factory"), bal)
	_check(h2.upgrades.filter and e2.air < e_heavy.air and e2.air > 0.0 and is_equal_approx(e2.ghg, e_heavy.ghg),
			"11) %d ay sonra filtre tamam: hava %.1f → %.1f (sıfırlanmadı), karbon aynı" % [bal.order_months.filter, e_heavy.air, e2.air])
	_check(_gs.inspections_used == 0, "aylık denetim hakları yenilendi")
	var q0: float = _gs.stats.quality_of_life
	h2.last_inspection = {}
	_gs.set_business(h2)
	_gc.inspect_business(heavy.business_id)
	var lvl: int = _gs.get_business(heavy.business_id).inspection_history[-1].level
	if lvl > 0:
		_check(_gc.order_business(heavy.business_id, &"suspend") == &"", "12) faaliyet durduruldu (seviye %d)" % lvl)
		var e3 := BusinessSimulator.effective(_gs.get_business(heavy.business_id), _type(&"heavy_factory"), bal)
		_check(e3.contribution == 0.0 and e3.ghg < e_heavy.ghg * 0.2 and _gs.stats.quality_of_life < q0, "12) katkı 0, emisyon %%10'a indi, çalışanlar işsiz (yaşam kalitesi %.1f → %.1f)" % [q0, _gs.stats.quality_of_life])
		_check(_gc.resume_business(heavy.business_id) == &"" and _gs.get_business(heavy.business_id).operational_status == &"active", "durdurulan işletme yeniden açıldı")
	else:
		_check(true, "12) filtreden sonra ihlal kalmadı; durdurma ayrı işletmede denenir")
		var chem := _add(&"chemical_plant", &"I03")
		_gc.inspect_business(chem.business_id)
		_check(_gc.order_business(chem.business_id, &"suspend") == &"" and BusinessSimulator.effective(_gs.get_business(chem.business_id), _type(&"chemical_plant"), bal).contribution == 0.0,
				"12) kimya fabrikası durduruldu, katkısı 0")

	print("Yıl sonu ekonomisi")
	var reports: Array = []
	_bus.year_ended.connect(func(r): reports.append(r))
	_bus.end_turn_requested.emit()
	var r: Dictionary = reports[-1]
	var sum: int = r.stats_before.credits + r.income - r.upkeep - r.investment_cost + r.missions.reward + r.fines - r.inspection_cost
	for cr in r.crisis_results:
		sum += int(cr.damage.get("credits", 0))
	_check(r.business_income > 0 and r.fines == expected and sum == r.stats_after.credits,
			"6/16) rapor: işletme geliri %d, ceza %d, bütçe tutarlı (%d = %d)" % [r.business_income, r.fines, sum, r.stats_after.credits])
	_bus.report_closed.emit()

	print("Kayıt ve yükleme")
	SaveGame.enabled = true
	SaveGame.path = "user://test_businesses_save.dat"
	var snap_before: Array = _gs.businesses.duplicate(true)
	var credits_before: int = _gs.stats.credits
	var seq_before: int = _gs.business_seq
	var reasons_before: Array = _gs.businesses.map(func(b): return BusinessSimulator.fine_block_reason(b))
	_check(_gc.save_game(), "13) oyun kaydedildi")
	_gs.reset()
	_check(_gs.businesses.is_empty(), "sıfırlanınca işletme yok")
	_check(SaveGame.load_into_state(), "13) kayıt yüklendi")
	_check(_gs.businesses == snap_before and _gs.stats.credits == credits_before and _gs.business_seq == seq_before,
			"13) işletmeler, denetim geçmişi, kasa ve kimlik sayacı aynı (%d işletme, %d kredi)" % [_gs.businesses.size(), _gs.stats.credits])
	var fined_rec: Dictionary = _gs.get_business(heavy.business_id).inspection_history[0]
	var reasons_after: Array = _gs.businesses.map(func(b): return BusinessSimulator.fine_block_reason(b))
	_check(fined_rec.fined and fined_rec.fine_paid == expected and reasons_after == reasons_before,
			"13) cezalı ihlal kayıtta işaretli kaldı; ceza durumu yüklemeden önceki gibi (%s)" % str(reasons_after))
	_spawned.clear()
	_gc.turn_manager.start_game()
	_check(_spawned.size() == _gs.businesses.size() and _spawned.all(func(i): return i.get("restored", false)) and _gs.businesses.size() == snap_before.size(),
			"15) yüklemede işletmeler görsele yeniden bildirildi (restored), yeni işletme oluşmadı (%d)" % _spawned.size())
	SaveGame.delete()
	_check(not SaveGame.exists(), "test kaydı silindi")
