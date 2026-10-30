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
## Uyarı anında oyuncuya gösterilen cümle.
@export var warning_text: String
## Hassasiyet: {"stat": ağırlık}. Gösterge 50'nin altındaysa hasar artar, üstündeyse azalır (Prompt 7A).
@export var vulnerability_stats: Dictionary = {}
## Ekip A görselleri için (sözleşme v1.5): efekt kimliği, etkilenen bölge ve arsa türleri.
@export var visual_effect_id: StringName
@export var affected_area: StringName
@export var affected_plot_kinds: Array[StringName] = []
@export var info_card: InfoCard
