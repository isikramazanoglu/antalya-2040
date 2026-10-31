class_name MissionTracker
extends RefCounted
## Sahip: B. Saf hesap: yıl sonunda görevleri değerlendirir. Durum GameState.missions'ta tutulur.


## context: {"built": Array[StringName], "crisis_results": Array} (Prompt 8 görev türleri için).
static func is_met(m: MissionDefinition, stats: Dictionary, context := {}) -> bool:
	match m.kind:
		&"build":
			var built: Array = context.get("built", [])
			return m.required_buildings.any(func(id): return built.has(id))
		&"prepared":
			return context.get("crisis_results", []).any(func(r): return r.mitigation > 0.0)
	var value: float = stats[m.stat]
	return value <= m.target if m.at_most else value >= m.target


## missions_state: {id: &"active" | &"done" | &"failed"}. Dönüş: {"completed": [...], "failed": [...], "reward": int}
static func evaluate(missions: Array[MissionDefinition], stats: Dictionary, missions_state: Dictionary, context := {}) -> Dictionary:
	var completed := []
	var failed := []
	var reward := 0
	for m in missions:
		if missions_state.get(m.id, &"active") != &"active":
			continue
		if is_met(m, stats, context):
			completed.append(m.id)
			reward += m.reward_credits
		elif m.category != &"learning" and stats.year >= m.deadline_year:  # öğrenme görevi kaçmaz
			failed.append(m.id)
	return {"completed": completed, "failed": failed, "reward": reward}
