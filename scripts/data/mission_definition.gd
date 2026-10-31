class_name MissionDefinition
extends Resource
## Eğitim görevi: bir göstergeyi son yıla kadar hedefe getir. Sahip: B.

@export var id: StringName
@export var title: String
@export_multiline var description: String
## stats anahtarı: water_security, energy_security, quality_of_life, ecosystem_health, emissions_total, population
@export var stat: String
@export var target: float = 0.0
## true: değer hedefin altına inmeli (emisyon gibi). false: hedefe ulaşmalı.
@export var at_most := false
@export var deadline_year: int = 2045
@export var reward_credits: int = 0
## Prompt 8: &"goal" (HUD'da görünen gösterge hedefi) veya &"learning" (öğrenme görevi, İklim Laboratuvarı'nda).
@export var category: StringName = &"goal"
## &"stat" (gösterge hedefi), &"build" (required_buildings'ten biri kurulsun), &"prepared" (bir kriz koruma varken karşılansın).
@export var kind: StringName = &"stat"
@export var required_buildings: Array[StringName] = []
## Görevin öğrettiği konunun bilgi kartı.
@export var info_card: InfoCard
