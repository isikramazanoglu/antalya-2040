class_name BalanceConfig
extends Resource
## Başlangıç değerleri ve katsayılar. Sayılar docs/GAME_DESIGN.md §3-4'ten. Sahip: B.

@export_group("Takvim")
@export var start_year: int = 2040
@export var end_year: int = 2052

@export_group("Başlangıç")
@export var start_credits: int = 1000
@export var start_population: int = 500
@export var start_water_security: float = 60.0
@export var start_energy_security: float = 50.0
@export var start_quality_of_life: float = 50.0
@export var start_ecosystem_health: float = 60.0

@export_group("Ekonomi")
@export var tax_per_capita: float = 0.5
@export var city_base_upkeep: int = 100
@export var population_growth_pivot: float = 45.0
@export var population_growth_divisor: float = 1000.0
@export var population_growth_min: float = -0.03
@export var population_growth_max: float = 0.04

@export_group("İklim")
## 500 nüfus için sektör taban emisyonu (oyun birimi).
@export var base_emissions: Dictionary = {"energy": 40.0, "transport": 25.0, "buildings": 20.0, "waste": 15.0}
@export var emission_floor: float = 0.2
@export var start_risks: Dictionary = {"drought": 40.0, "heat": 45.0, "coastal_flood": 30.0}
@export var risk_growth_per_year: Dictionary = {"drought": 2.0, "heat": 2.0, "coastal_flood": 1.5}
@export var max_mitigation: float = 0.8
