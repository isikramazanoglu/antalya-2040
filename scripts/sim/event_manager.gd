class_name EventManager
extends RefCounted
## Sahip: B. Saf hesap: kriz planlama, risk değerlendirme, müdahale seçenekleri ve hasar.
## Sinyal yaymaz, panel açmaz; sonuçları TurnManager → GameController uygular.
## scripted_year > 0 olan kriz yalnızca o yıl gelir; 0 ise her yıl olasılıkla.
##
## Hasar = taban × tehlike × maruziyet × hassasiyet × (1 − uyum kapasitesi) × müdahale çarpanı
##   tehlike    = 0.5 + şiddet (şiddet: yatırımdan bağımsız ham risk / 100)
##   maruziyet  = nüfus / 500 (0.8..1.5)
##   hassasiyet = 1 + Σ ağırlık × (50 − gösterge) / 100 (0.6..1.5)
##   uyum       = binaların risk_reduction toplamı (en çok 0.8)


## Yıl sonunda çağrılır; due_year = year + lead_years olan yeni uyarıları döndürür (sözleşme §5.2).
static func plan_warnings(year: int, events: Array[EventDefinition], risks: Dictionary,
		pending: Array, b: BalanceConfig, rng: RandomNumberGenerator) -> Array:
	var warnings := []
	for def in events:
		var due := year + def.lead_years
		if due > b.end_year or due < def.earliest_year:
			continue
		if pending.any(func(w): return w.event_id == def.id):
			continue
		var risk: float = risks.get(def.risk_type, 50.0)
		var happens := false
		if def.scripted_year > 0:
			happens = due == def.scripted_year
		else:
			happens = rng.randf() < def.base_probability * risk / 50.0
		if happens:
			warnings.append({
				"event_id": def.id,
				"risk_type": def.risk_type,
				"due_year": due,
				"severity": severity(def, due, b),
			})
	return warnings


## Tehlike şiddeti 0.2..1: o yılın yatırımdan bağımsız ham riski. Uyum kapasitesi ayrıca hesaplanır, iki kez sayılmaz.
static func severity(def: EventDefinition, year: int, b: BalanceConfig) -> float:
	return clampf(ClimateSimulator.raw_risk(def.risk_type, year, b) / 100.0, 0.2, 1.0)


## Bu kriz için hasar çarpanlarının dökümü (panel ve rapor da gösterir).
static func assess(def: EventDefinition, severity_value: float, stats: Dictionary, buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var vulnerability := 1.0
	for key in def.vulnerability_stats:
		vulnerability += def.vulnerability_stats[key] * (50.0 - float(stats.get(key, 50.0))) / 100.0
	var advantages := []
	for building in buildings:
		# Sözleşme v1.6: advantages bina kimlikleridir; kombinasyonlar korumaya katılır ama listede yer almaz.
		if building.risk_reduction.get(def.risk_type, 0.0) > 0.0 and not building is SynergyDefinition:
			advantages.append(building.id)
	return {
		"hazard": 0.5 + severity_value,
		"exposure": clampf(stats.population / 500.0, 0.8, 1.5),
		"vulnerability": clampf(vulnerability, 0.6, 1.5),
		"mitigation": ClimateSimulator.mitigation(buildings, def.risk_type, b),
		"advantages": advantages,
	}


## Oyuncunun görebileceği müdahaleler: altyapı şartı olanlar yalnızca bina kuruluysa.
static func available_responses(def: EventDefinition, buildings: Array[BuildingDefinition]) -> Array[CrisisResponse]:
	var built := buildings.map(func(d): return d.id)
	var out: Array[CrisisResponse] = []
	for r in def.responses:
		if r.required_building == &"" or built.has(r.required_building):
			out.append(r)
	return out


## Müdahale seçilebilir mi? &"" ise evet; değilse neden.
static func validate(def: EventDefinition, response: CrisisResponse, buildings: Array[BuildingDefinition], credits: int) -> StringName:
	if response == null or not def.responses.has(response):
		return &"unknown_response"
	if not available_responses(def, buildings).has(response):
		return &"missing_infrastructure"
	if response.cost > credits:
		return &"not_enough_credits"
	return &""


## Uygulanmadan önce beklenen hasar (panelde "olası etkiler").
static func preview(def: EventDefinition, response: CrisisResponse, assessment: Dictionary) -> Dictionary:
	var scale: float = assessment.hazard * assessment.exposure * assessment.vulnerability * (1.0 - assessment.mitigation) * response.damage_multiplier
	var damage := {}
	for key in def.base_damage:
		damage[key] = def.base_damage[key] * scale
	for key in response.extra_effects:
		damage[key] = damage.get(key, 0.0) + response.extra_effects[key]
	if response.cost > 0:
		damage["credits"] = damage.get("credits", 0.0) - response.cost
	for key in damage:
		damage[key] = roundf(damage[key])
	return damage


## Sözleşme §5.3 sonucu (v1.5 ek alanlarla). Hasar preview ile aynıdır.
static func resolve(def: EventDefinition, response: CrisisResponse, severity_value: float, stats: Dictionary,
		buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var a := assess(def, severity_value, stats, buildings, b)
	return {
		"event_id": def.id,
		"response_id": response.id,
		"risk_type": def.risk_type,
		"mitigation": a.mitigation,
		"damage": preview(def, response, a),
		"severity": severity_value,
		"assessment": a,
		"summary_text": "%s: \"%s\" seçildi, yatırımlar hasarı %%%d azalttı." % [def.display_name, response.label, roundi(a.mitigation * 100)],
	}


static func find_response(def: EventDefinition, response_id: StringName) -> CrisisResponse:
	for r in def.responses:
		if r.id == response_id:
			return r
	return null
