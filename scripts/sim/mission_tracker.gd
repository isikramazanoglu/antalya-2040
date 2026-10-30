class_name MissionTracker
extends RefCounted
## Sahip: B. Saf hesap: yıl sonunda görevleri değerlendirir. Durum GameState.missions'ta tutulur.


static func is_met(m: MissionDefinition, stats: Dictionary) -> bool:
	var value: float = stats[m.stat]
	return value <= m.target if m.at_most else value >= m.target


## missions_state: {id: &"active" | &"done" | &"failed"}. Dönüş: {"completed": [...], "failed": [...], "reward": int}
static func evaluate(missions: Array[MissionDefinition], stats: Dictionary, missions_state: Dictionary) -> Dictionary:
	var completed := []
	var failed := []
	var reward := 0
	for m in missions:
		if missions_state.get(m.id, &"active") != &"active":
			continue
		if is_met(m, stats):
			completed.append(m.id)
			reward += m.reward_credits
		elif stats.year >= m.deadline_year:
			failed.append(m.id)
	return {"completed": completed, "failed": failed, "reward": reward}
