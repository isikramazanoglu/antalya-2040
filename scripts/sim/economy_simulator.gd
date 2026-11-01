class_name EconomySimulator
extends RefCounted
## Sahip: B. Saf hesap: gelir, gider, nüfus, binaların yıllık etkileri, final puanı.
## Durum tutmaz, sinyal yaymaz. Formüller: docs/GAME_DESIGN.md §4.


## Dönüş: {"income": int, "upkeep": int, "deltas": Dictionary}. deltas doğrudan GameState.apply_deltas'a gider.
static func compute_year(stats: Dictionary, buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var income := roundi(stats.population * b.tax_per_capita)
	var upkeep := b.city_base_upkeep
	var deltas := {}
	for def in buildings:
		upkeep += def.upkeep_per_year
		for key in def.yearly_effects:
			deltas[key] = deltas.get(key, 0.0) + def.yearly_effects[key]

	var rate := clampf((stats.quality_of_life - b.population_growth_pivot) / b.population_growth_divisor,
			b.population_growth_min, b.population_growth_max)
	if stats.water_security < 30.0:
		rate -= 0.02
	deltas["population"] = deltas.get("population", 0) + roundi(stats.population * rate)
	deltas["credits"] = income - upkeep
	if stats.credits + income - upkeep < 0:
		deltas["quality_of_life"] = deltas.get("quality_of_life", 0.0) - 5.0
	return {"income": income, "upkeep": upkeep, "deltas": deltas}


## Enerji ve su akışları (sözleşme §5.1 v1.2). Endekslerden (energy_security, water_security) ayrı, bilgi amaçlı.
## renewable_share: talebin yenilenebilir üretimle karşılanan payı, 0..1.
static func compute_resources(population: int, buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var energy_demand := population * b.energy_per_capita
	var water_demand := population * b.water_per_capita
	var renewable := 0.0
	var water_supply := b.base_water_supply
	var recycled := 0.0
	for def in buildings:
		renewable += def.energy_production
		energy_demand += def.energy_consumption
		water_supply += def.water_production
		water_demand += def.water_consumption
		recycled += def.recycled_water_production
	energy_demand = maxf(energy_demand, 0.0)
	return {
		"energy_demand": energy_demand,
		"renewable_energy": renewable,
		"renewable_share": clampf(renewable / energy_demand, 0.0, 1.0) if energy_demand > 0.0 else 0.0,
		"water_demand": maxf(water_demand, 0.0),
		"water_supply": water_supply,  # içme suyu kalitesinde arz
		# v1.8: geri kazanılmış su ayrı; yalnızca içme dışı talebi (en çok non_potable_water_share) karşılar.
		"recycled_water": recycled,
		"recycled_water_used": minf(recycled, maxf(water_demand, 0.0) * b.non_potable_water_share),
	}
