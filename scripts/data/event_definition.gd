class_name EventDefinition
extends Resource
## Bir krizin verisi. Sahip: B.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## drought, heat, coastal_flood
@export var risk_type: StringName
@export var earliest_year: int = 2041
## 0 değilse kriz tam bu yıl gelir (demo garantisi).
@export var scripted_year: int = 0
@export_range(0.0, 1.0) var base_probability: float = 0.2
@export var lead_years: int = 1
## Ör. {"credits": -150, "water_security": -20}
@export var base_damage: Dictionary = {}
@export var responses: Array[CrisisResponse] = []
@export var info_card: InfoCard
