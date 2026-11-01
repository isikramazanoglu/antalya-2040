class_name VehicleLibrary
## Sahip: A. Görsel revizyon 9 · Araç kütüphanesi yardımcıları (yalnızca görsel; oyun kuralı yok).
## Modeller scripts/world/dev/gen_vehicle_library.gd ile üretilir: assets/vehicles/<kategori>/<model>.tscn (Body + Wheel_*).
## Ön yön -Z, sağ +X, pivot zeminde. Gövde boyası ayrı yüzey (veh_paint); renk çeşitlemesi bu yüzeyde yapılır.

const MODELS := {
	&"city_car": "res://assets/vehicles/cars/city_car.tscn",
	&"sedan": "res://assets/vehicles/cars/sedan.tscn",
	&"compact_suv": "res://assets/vehicles/cars/compact_suv.tscn",
	&"electric_car": "res://assets/vehicles/cars/electric_car.tscn",
	&"city_bus": "res://assets/vehicles/buses/city_bus.tscn",
	&"minibus": "res://assets/vehicles/buses/minibus.tscn",
	&"delivery_van": "res://assets/vehicles/commercial/delivery_van.tscn",
	&"bicycle": "res://assets/vehicles/bicycles/bicycle.tscn",
}
const CARS: Array[StringName] = [&"city_car", &"sedan", &"compact_suv", &"electric_car"]
## Kontrollü Akdeniz paleti (kırık beyaz, açık gri, koyu gri, lacivert, koyu mavi, kiremit, gümüş, krem, açık turkuaz).
const PAINT_COLORS := [Color(0.93, 0.92, 0.88), Color(0.76, 0.77, 0.78), Color(0.3, 0.32, 0.34), Color(0.15, 0.2, 0.35),
	Color(0.2, 0.32, 0.5), Color(0.7, 0.36, 0.27), Color(0.68, 0.7, 0.72), Color(0.9, 0.85, 0.72), Color(0.47, 0.73, 0.73)]
## Otobüs, minibüs ve van kendi boyalarıyla (belediye beyazı, krem, beyaz).
const FLEET_COLORS := {&"city_bus": Color(0.95, 0.95, 0.93), &"minibus": Color(0.9, 0.85, 0.72), &"delivery_van": Color(0.95, 0.95, 0.94)}

static var _paints := {}
static var _merged := {}


## Boya materyali (paylaşılan; aynı renk tek materyal).
static func paint(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _paints.has(key):
		var m := StandardMaterial3D.new()
		m.resource_name = "veh_paint_" + key
		m.albedo_color = color
		m.roughness = 0.35
		m.metallic = 0.15
		_paints[key] = m
	return _paints[key]


static func paint_for(model: StringName, look: int) -> StandardMaterial3D:
	if FLEET_COLORS.has(model):
		return paint(FLEET_COLORS[model])
	return paint(PAINT_COLORS[absi(look) % PAINT_COLORS.size()])


## Gövde + tekerlekler tek mesh (park etmiş araçlar ve bisikletler için); boya yüzeyi verilen renkte.
static func merged(model: StringName, paint_material: Material = null) -> ArrayMesh:
	var key := "%s|%s" % [model, paint_material.get_instance_id() if paint_material else 0]
	if _merged.has(key):
		return _merged[key]
	var root: Node3D = (load(MODELS[model]) as PackedScene).instantiate()
	var tools := {}
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		for s in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(s)
			if paint_material and material and material.resource_name == "veh_paint":
				material = paint_material
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
			(tools[material] as SurfaceTool).append_from(mi.mesh, s, mi.transform)
	root.free()
	var mesh := ArrayMesh.new()
	for material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	_merged[key] = mesh
	return mesh


## Gövde boyutu (uzunluk z, genişlik x) — takip mesafesi ve park aralığı için.
static func length_of(model: StringName) -> float:
	return merged(model).get_aabb().size.z
