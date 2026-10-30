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

