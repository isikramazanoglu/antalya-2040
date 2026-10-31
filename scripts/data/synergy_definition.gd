class_name SynergyDefinition
extends BuildingDefinition
## Yatırım kombinasyonu (Prompt 9A). Sahip: B.
## requires listesindeki binaların hepsi kuruluysa, GameState.built_definitions() bu tanımı da döndürür;
## böylece bonus binalarla aynı tek yoldan (emisyon, akış, koruma) hesaba girer ve iki kez uygulanamaz.
## Maliyeti, gideri, sahnesi ve on_build_effects'i yoktur.

@export var requires: Array[StringName] = []
