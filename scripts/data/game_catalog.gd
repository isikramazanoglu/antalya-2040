class_name GameCatalog
extends Resource
## Oyundaki bütün tanımların listesi (data/catalog.tres). Sahip: B.
## Yeni bina veya kriz: .tres oluştur, buraya ekle. Kod değişmez.

@export var buildings: Array[BuildingDefinition] = []
@export var events: Array[EventDefinition] = []
@export var lab_cards: Array[InfoCard] = []
@export var missions: Array[MissionDefinition] = []
@export var glossary: Array[GlossaryTerm] = []
@export var synergies: Array[SynergyDefinition] = []
@export var balance: BalanceConfig
@export var co2: Co2Scenario
