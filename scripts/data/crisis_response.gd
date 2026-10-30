class_name CrisisResponse
extends Resource
## Bir krize verilebilecek müdahale seçeneği. Sahip: B.

@export var id: StringName
@export var label: String
@export_multiline var description: String
@export var cost: int = 0
@export_range(0.0, 1.0) var damage_multiplier: float = 1.0
@export var extra_effects: Dictionary = {}
