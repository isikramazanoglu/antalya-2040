class_name EventManager
extends RefCounted
## Sahip: B. Saf hesap: kriz planlama ve hasar. Sinyal yaymaz, panel açmaz.
## scripted_year > 0 olan kriz yalnızca o yıl gelir; 0 ise her yıl olasılıkla.


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
				"severity": clampf(risk / 100.0, 0.2, 1.0),
			})
	return warnings


## Sözleşme §5.3 sonucu. Hasar = taban × (1 − koruma) × müdahale çarpanı; müdahale maliyeti ve ek etkiler eklenir.
static func resolve(def: EventDefinition, response: CrisisResponse, buildings: Array[BuildingDefinition], b: BalanceConfig) -> Dictionary:
	var mit := ClimateSimulator.mitigation(buildings, def.risk_type, b)
	var damage := {}
	for key in def.base_damage:
		damage[key] = def.base_damage[key] * (1.0 - mit) * response.damage_multiplier
	for key in response.extra_effects:
		damage[key] = damage.get(key, 0.0) + response.extra_effects[key]
	if response.cost > 0:
		damage["credits"] = damage.get("credits", 0.0) - response.cost
	for key in damage:
		damage[key] = roundf(damage[key])
	return {
		"event_id": def.id,
		"response_id": response.id,
		"risk_type": def.risk_type,
		"mitigation": mit,
		"damage": damage,
		"summary_text": "%s: \"%s\" seçildi, yatırımlar hasarı %%%d azalttı." % [def.display_name, response.label, roundi(mit * 100)],
	}


static func find_response(def: EventDefinition, response_id: StringName) -> CrisisResponse:
	for r in def.responses:
		if r.id == response_id:
			return r
	return null
