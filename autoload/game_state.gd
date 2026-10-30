extends Node
## Sahip: B. Oyun verisinin tek kaynağı; hesap ve kural yok.
## Yazma yetkisi yalnızca GameController'da (mimari §3). Diğerleri getter kullanır.

var stats: Dictionary = {}
var plots: Dictionary = {}  # plot_id (StringName) -> building_id (StringName)
var pending_crises: Array = []  # sözleşme §5.2 warning sözlükleri
var history: Array = []  # her yıl sonunun stats kopyası
var phase: StringName = &"build"
var rng_seed: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	var b: BalanceConfig = Catalog.data.balance
	stats = {
		"year": b.start_year,
		"credits": b.start_credits,
		"population": b.start_population,
		"water_security": b.start_water_security,
		"energy_security": b.start_energy_security,
		"quality_of_life": b.start_quality_of_life,
		"ecosystem_health": b.start_ecosystem_health,
		"emissions_total": 0.0,
		"emissions_by_sector": b.base_emissions.duplicate(),
		"risks": b.start_risks.duplicate(),
		"global_co2_ppm": -1.0,
	}
	var total := 0.0
	for value in b.base_emissions.values():
		total += value
	stats["emissions_total"] = total
	plots.clear()
	pending_crises.clear()
	history.clear()
	phase = &"build"
	rng_seed = randi()
	EventBus.stats_changed.emit(get_stats())


## Sözleşme §4: salt okunur kopya.
func get_stats() -> Dictionary:
	return stats.duplicate(true)


## Sözleşme §4: boşsa &"".
func get_building_on(plot_id: StringName) -> StringName:
	return plots.get(plot_id, &"")


# --- Yazma fonksiyonları: yalnızca GameController çağırır ---

const INDEX_STATS: Array[String] = ["water_security", "energy_security", "quality_of_life", "ecosystem_health"]


## {"credits": -400, "energy_security": 20} gibi değişimleri uygular; göstergeler 0..100 arası kalır.
func apply_deltas(deltas: Dictionary) -> void:
	for key in deltas:
		if key == "credits":
			stats.credits += int(deltas[key])
		elif key == "population":
			stats.population = maxi(0, stats.population + int(deltas[key]))
		elif key in INDEX_STATS:
			stats[key] = clampf(stats[key] + float(deltas[key]), 0.0, 100.0)
		else:
			push_warning("GameState: bilinmeyen gösterge '%s'" % key)
	EventBus.stats_changed.emit(get_stats())


func place_building(plot_id: StringName, building_id: StringName) -> void:
	plots[plot_id] = building_id


func set_phase(new_phase: StringName) -> void:
	phase = new_phase


func advance_year() -> void:
	stats.year += 1
	EventBus.stats_changed.emit(get_stats())


func record_history() -> void:
	history.append(get_stats())
