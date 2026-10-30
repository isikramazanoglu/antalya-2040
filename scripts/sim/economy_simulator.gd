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


## Sözleşme §5.5 için puan ve not.
## Emisyon bonusu kişi başı emisyondaki azalmadan gelir; şehri büyütmek cezalandırılmaz.
static func final_score(final_stats: Dictionary, start_stats: Dictionary) -> Dictionary:
	var avg: float = (final_stats.water_security + final_stats.energy_security
			+ final_stats.quality_of_life + final_stats.ecosystem_health) / 4.0
	var reduction_pct := 0.0
	var start_per_capita: float = start_stats.emissions_total / maxf(start_stats.population, 1.0)
	var final_per_capita: float = final_stats.emissions_total / maxf(final_stats.population, 1.0)
	if start_per_capita > 0.0:
		reduction_pct = maxf(0.0, (start_per_capita - final_per_capita) / start_per_capita * 100.0)
	var score := roundi(avg + minf(reduction_pct * 0.3, 30.0))
	var grade := "Risk Altında"
	if score >= 85:
		grade = "İklim Lideri"
	elif score >= 70:
		grade = "Dayanıklı Şehir"
	elif score >= 50:
		grade = "Gelişen Şehir"
	return {"score": score, "grade": grade, "emission_reduction_pct": roundi(reduction_pct)}
