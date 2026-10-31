extends SceneTree
## Sahip: B. Denge ölçümü: farklı stratejileri 2040-2052 otomatik oynatır, final değerlerini yazar.
## Çalıştır: <godot> --headless --path . --script res://tests/balance_sim.gd

const PLOTS := {&"urban": [&"U01", &"U02", &"U03", &"U04", &"U05", &"U06", &"U07", &"U08"],
		&"open": [&"O01", &"O02", &"O03", &"O04", &"O05"], &"coastal": [&"C01", &"C02"]}

var _bus: Node
var _gs: Node
var _cat: Node
var _strategies := ["hiçbir şey", "en ucuz", "koruyucu", "emisyon", "karma"]
var _i := 0
var _frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")


func _process(_d: float) -> bool:
	_frame += 1
	if _frame % 3 != 0:
		return false
	if _i >= _strategies.size():
		quit()
		return true
	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	_cat = root.get_node("Catalog")
	_play(_strategies[_i])
	_i += 1
	_gs.reset()
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")
	return false


func _priority(def, strategy: String) -> float:
	match strategy:
		"en ucuz": return -def.cost
		"koruyucu": return def.risk_reduction.values().reduce(func(a, b): return a + b, 0.0) * 1000.0 - def.cost
		"emisyon": return -def.emission_multipliers.values().reduce(func(a, b): return a + b, 0.0) * 1000.0 - def.cost
		_: return def.on_build_effects.values().reduce(func(a, b): return a + b, 0.0) * 10.0 \
				+ def.risk_reduction.values().reduce(func(a, b): return a + b, 0.0) * 300.0 \
				- def.emission_multipliers.values().reduce(func(a, b): return a + b, 0.0) * 300.0 - def.cost * 0.1


func _play(strategy: String) -> void:
	var on_crisis := func(id, _r, _s):
		var def = _cat.get_event(id)
		var best = null
		for r in EventManager.available_responses(def, _gs.built_definitions()):
			if r.cost <= _gs.stats.credits and (best == null or r.damage_multiplier < best.damage_multiplier):
				best = r
		_bus.crisis_response_chosen.emit(id, best.id if strategy != "hiçbir şey" else &"do_nothing")
	_bus.crisis_started.connect(on_crisis)
	var summary := {}
	_bus.game_over.connect(func(s): summary.merge(s))
	var built_count := 0
	var crisis := {"credits": 0, "count": 0}  # lambda yerel değişkeni kopyalar; sözlük referansla paylaşılır
	var on_resolved := func(r): crisis.credits += int(r.damage.get("credits", 0)); crisis.count += 1
	_bus.crisis_resolved.connect(on_resolved)
	while _gs.phase == &"build":
		if strategy != "hiçbir şey":
			var defs: Array = _cat.data.buildings.duplicate()
			defs.sort_custom(func(a, b): return _priority(a, strategy) > _priority(b, strategy))
			for def in defs:
				if def.cost > _gs.stats.credits or _gs.plots.values().has(def.id):
					continue
				for kind in def.allowed_plot_kinds:
					var free: Array = PLOTS[kind].filter(func(p): return _gs.get_building_on(p) == &"")
					if free.size() > 0:
						_bus.plot_selected.emit(free[0], kind, true)
						_bus.build_requested.emit(free[0], def.id)
						built_count += 1
						break
				break  # yılda en çok bir yatırım
		_bus.end_turn_requested.emit()
		_bus.report_closed.emit()
	var s: Dictionary = summary.final_stats
	print("%-11s puan %3d %-16s | kredi %5d nüfus %4d su %3d enerji %3d yaşam %3d eko %3d emisyon %5.1f | bina %2d | %d kriz, kredi kaybı %d | görev %d/%d" % [
		strategy, summary.score, summary.grade, s.credits, s.population, s.water_security, s.energy_security,
		s.quality_of_life, s.ecosystem_health, s.emissions_total, built_count, crisis.count, crisis.credits, _gs.missions.values().count(&"done"), _cat.data.missions.size()])
	_bus.crisis_started.disconnect(on_crisis)
	_bus.crisis_resolved.disconnect(on_resolved)
