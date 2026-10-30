class_name Co2Scenario
extends Resource
## Küresel CO2 (ppm) tablosu. Yalnızca kaynaklı değer girilir. Sahip: B.

@export var scenario_name: String
@export var source: String
@export var years: PackedInt32Array = PackedInt32Array()
@export var ppm: PackedFloat32Array = PackedFloat32Array()
