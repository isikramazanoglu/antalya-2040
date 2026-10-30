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
