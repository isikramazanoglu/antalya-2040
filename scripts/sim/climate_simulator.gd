class_name ClimateSimulator
extends RefCounted
## Sahip: B. Saf hesap: sektör emisyonları, yerel riskler, ekosistem, küresel CO2 okuma.
## Küresel CO2 oyuncu yatırımıyla değişmez; yalnızca tablodan okunur (GAME_DESIGN §7).


## Dönüş: {"emissions_by_sector", "emissions_total", "risks", "global_co2_ppm", "deltas"}.
## risks: gelen yılın (stats.year + 1) korunmuş riskleri; uyarılar ve arayüz bunu kullanır.
static func compute_year(stats: Dictionary, buildings: Array[BuildingDefinition], b: BalanceConfig, co2: Co2Scenario) -> Dictionary:
	var emissions := compute_emissions(stats.population, buildings, b)
	var by_sector: Dictionary = emissions.emissions_by_sector
	var total: float = emissions.emissions_total

	var risks := {}
	for risk_type in b.start_risks:
		var shown := raw_risk(risk_type, stats.year + 1, b) * (1.0 - mitigation(buildings, risk_type, b))
		risks[risk_type] = clampf(shown, 0.0, 100.0)

	var eco_delta := -1.0
	if total < 80.0:
		eco_delta += 1.0
	return {
		"emissions_by_sector": by_sector,
		"emissions_total": total,
		"risks": risks,
		"global_co2_ppm": co2_for_year(co2, stats.year),
		"deltas": {"ecosystem_health": eco_delta},
	}


## Sektör emisyonları; yıl sonunda ve her inşaattan sonra kullanılır.
static func compute_emissions(population: int, buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var pop_factor := population / 500.0
	var by_sector := {}
	var total := 0.0
	for sector in b.base_emissions:
		var mult := 1.0
		for def in buildings:
			mult += def.emission_multipliers.get(sector, 0.0)
		by_sector[sector] = b.base_emissions[sector] * pop_factor * maxf(mult, b.emission_floor)
		total += by_sector[sector]
	var waste_cut := 0.0
	for def in buildings:
		waste_cut -= def.emission_multipliers.get("waste", 0.0)
	return {"emissions_by_sector": by_sector, "emissions_total": total, "waste_recovery": clampf(waste_cut, 0.0, 1.0)}


## İklim dayanıklılığı: üç risk için yatırım korumasının ortalaması (0..max_mitigation). Oyun göstergesidir.
static func resilience(buildings: Array[BuildingDefinition], b: BalanceConfig) -> float:
	var sum := 0.0
	for risk_type in b.start_risks:
		sum += mitigation(buildings, risk_type, b)
	return sum / maxf(b.start_risks.size(), 1.0)


## Yatırım öncesi risk: başlangıç + yıllık artış × başlangıçtan beri geçen yıl.
static func raw_risk(risk_type: StringName, year: int, b: BalanceConfig) -> float:
	var years := year - b.start_year
	return clampf(b.start_risks[risk_type] + b.risk_growth_per_year[risk_type] * years, 0.0, 100.0)


## Binaların bu risk için toplam koruması, en çok b.max_mitigation.
static func mitigation(buildings: Array[BuildingDefinition], risk_type: StringName, b: BalanceConfig) -> float:
	var sum := 0.0
	for def in buildings:
		sum += def.risk_reduction.get(risk_type, 0.0)
	return minf(sum, b.max_mitigation)


## Tablo bu yılı içermiyorsa -1.0 (arayüz "veri yok" yazar). Değer uydurulmaz.
static func co2_for_year(co2: Co2Scenario, year: int) -> float:
	if co2 == null:
		return -1.0
	var i := co2.years.find(year)
	return co2.ppm[i] if i >= 0 else -1.0
