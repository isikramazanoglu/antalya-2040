extends Node
## Sahip: B. Sözleşme §4: get_building, buildings_for_plot_kind, get_event.
## data/catalog.tres içindeki tanımlara kimlikle erişim verir.

const CATALOG_PATH := "res://data/catalog.tres"

var data: GameCatalog = load(CATALOG_PATH)


func get_building(id: StringName) -> BuildingDefinition:
	for def in data.buildings:
		if def.id == id:
			return def
	return null


func buildings_for_plot_kind(kind: StringName) -> Array[BuildingDefinition]:
	var result: Array[BuildingDefinition] = []
	for def in data.buildings:
		if kind in def.allowed_plot_kinds:
			result.append(def)
	return result


func get_event(id: StringName) -> EventDefinition:
	for def in data.events:
		if def.id == id:
			return def
	return null


## Veri doğrulaması (Prompt 9A): eksik maliyet, sahne, arsa türü, bilgi kartı, yinelenen kimlik.
## Boş liste: sorun yok. Oyun açılırken uyarı olarak yazılır, oyun durmaz.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen := {}
	for def in data.buildings:
		if seen.has(def.id):
			problems.append("%s: kimlik tekrar ediyor" % def.id)
		seen[def.id] = true
		if def.cost <= 0:
			problems.append("%s: maliyet yok" % def.id)
		if def.scene == null:
			problems.append("%s: bina sahnesi yok" % def.id)
		if def.allowed_plot_kinds.is_empty():
			problems.append("%s: arsa türü yok" % def.id)
		if def.info_card == null:
			problems.append("%s: bilgi kartı yok" % def.id)
	for syn in data.synergies:
		for id in syn.requires:
			if not seen.has(id):
				problems.append("%s: bilinmeyen bina %s" % [syn.id, id])
	return problems


func _ready() -> void:
	for p in validate():
		push_warning("Catalog: " + p)
