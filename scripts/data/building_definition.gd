class_name BuildingDefinition
extends Resource
## Bir yatırımın verisi. Sahip: B. `scene` alanı A'nın b_<id>.tscn dosyasıdır.

@export var id: StringName
@export var display_name: String
@export var short_description: String
## energy, water, heat, food, waste, transport, coast
@export var category: StringName
@export var cost: int = 0
@export var upkeep_per_year: int = 0
## urban, open, coastal
@export var allowed_plot_kinds: Array[StringName] = []
@export var max_count: int = 1
@export var scene: PackedScene
@export var icon: Texture2D
## İnşa anında bir kez uygulanır, ör. {"quality_of_life": 5}
@export var on_build_effects: Dictionary = {}
## Her yıl sonu uygulanır, ör. {"water_security": 2}
@export var yearly_effects: Dictionary = {}
## Sektör çarpanı, ör. {"energy": -0.30} = enerji emisyonu %30 az
@export var emission_multipliers: Dictionary = {}
## Kriz hasarını azaltma, ör. {"drought": 0.30}
@export var risk_reduction: Dictionary = {}
## Kaynak akışları (oyun birimi/yıl, isteğe bağlı). Üretim yenilenebilirdir; tüketim negatifse tasarruftur.
@export var energy_production: float = 0.0
@export var energy_consumption: float = 0.0
@export var water_production: float = 0.0
@export var water_consumption: float = 0.0
@export var info_card: InfoCard
