extends SceneTree
## Sahip: A. Görsel revizyon 9 · Araç kütüphanesi üreticisi (Blender ya da harici model yok).
## Godot SurfaceTool ile: yan profilden kalıplanan gövde (alt gövde + daha dar kabin), profil şeritlerinde cam / boya
## ayrımı (ön cam, arka cam), yan camlar ve direkler, farlar, stoplar, ızgara, tamponlar, aynalar, kapı çizgileri,
## plaka yerleri (boş), ayrı tekerlekler (lastik + jant + göbek).
## Çıktı:
##   assets/vehicles/materials/veh_*.tres            ortak araç paleti (gövde boyası ayrı materyal: veh_paint)
##   assets/vehicles/<kategori>/<model>_body.tres     gövde mesh'i (tekerleksiz)
##   assets/vehicles/<kategori>/<model>.tscn           Body + Wheel_* düğümleri (tekerlekler x ekseninde döner)
##   assets/vehicles/wheels/wheel_*.tres               paylaşılan tekerlekler
## Çalıştırma: <godot> --headless --path . --script res://scripts/world/dev/gen_vehicle_library.gd
## Ölçek: 1 birim ≈ 2,3 m. Pivot: zemin üstü (y = 0) gövde merkezi; ön yön -Z (PathFollow3D ileri yönü), sağ +X.

const PALETTE := {
	"paint": [Color(0.93, 0.92, 0.88), 0.35, 0.15],  # varsayılan boya (oyunda renk çeşitlemesi bu yüzeyde)
	"glass": [Color(0.16, 0.24, 0.28), 0.08, 0.35],
	"tyre": [Color(0.11, 0.11, 0.12), 0.9, 0.0],
	"rim": [Color(0.72, 0.73, 0.74), 0.35, 0.6],
	"trim": [Color(0.17, 0.18, 0.19), 0.7, 0.1],
	"chrome": [Color(0.8, 0.81, 0.82), 0.25, 0.7],
	"headlight": [Color(1.0, 0.97, 0.88), 0.2, 0.0],
	"taillight": [Color(0.72, 0.1, 0.09), 0.3, 0.0],
	"indicator": [Color(0.95, 0.6, 0.2), 0.3, 0.0],
	"plate": [Color(0.95, 0.95, 0.93), 0.6, 0.0],
	"interior": [Color(0.12, 0.13, 0.14), 0.9, 0.0],
	"livery_turquoise": [Color(0.27, 0.62, 0.63), 0.4, 0.1],
	"livery_terracotta": [Color(0.72, 0.38, 0.28), 0.4, 0.1],
	"sign": [Color(0.98, 0.78, 0.35), 0.4, 0.0],
	"frame_teal": [Color(0.24, 0.52, 0.55), 0.4, 0.3],
	"saddle": [Color(0.2, 0.16, 0.13), 0.8, 0.0],
	"basket": [Color(0.66, 0.5, 0.33), 0.8, 0.0],
}
## Işık materyallerinde hafif ışıma (gündüz, abartısız).
const EMISSIVE := {"headlight": 0.25, "taillight": 0.35, "sign": 0.3}

var mats := {}
var tools := {}
var BOX := BoxMesh.new()
var CYL := CylinderMesh.new()
var TORUS := TorusMesh.new()


func _initialize() -> void:
	CYL.top_radius = 0.5
	CYL.bottom_radius = 0.5
	CYL.height = 1.0
	CYL.radial_segments = 14
	CYL.rings = 0
	TORUS.inner_radius = 0.42
	TORUS.outer_radius = 0.5
	TORUS.rings = 20
	TORUS.ring_segments = 6
	_save_palette()
	_save_wheels()
	var models := {
		"cars/city_car": _city_car, "cars/sedan": _sedan, "cars/compact_suv": _suv, "cars/electric_car": _ev,
		"buses/city_bus": _bus, "buses/minibus": _minibus, "commercial/delivery_van": _van,
		"bicycles/bicycle": _bicycle,
	}
	for path: String in models:
		tools.clear()
		var wheels: Array = models[path].call()  # [[konum, tekerlek adı], ...]
		var mesh := _commit()
		var dir := "res://assets/vehicles/" + path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var body_path := "res://assets/vehicles/%s_body.tres" % path
		ResourceSaver.save(mesh, body_path)
		var root := Node3D.new()
		root.name = path.get_file().to_pascal_case()
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = load(body_path)
		root.add_child(body)
		body.owner = root
		var i := 0
		for w: Array in wheels:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%d" % i
			wheel.mesh = load("res://assets/vehicles/wheels/%s.tres" % w[1])
			wheel.position = w[0]
			if w[0].x < 0.0:
				wheel.rotation.y = PI  # jant yüzü dışa baksın
			root.add_child(wheel)
			wheel.owner = root
			i += 1
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene, "res://assets/vehicles/%s.tscn" % path)
		root.free()
		var aabb := mesh.get_aabb()
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
		print("%-28s uzunluk %.2f (%.1f m)  genişlik %.2f  yükseklik %.2f  %2d materyal  %4d üçgen + %d tekerlek" % [
			path, aabb.size.z, aabb.size.z * 2.3, aabb.size.x, aabb.end.y, mesh.get_surface_count(), tris, wheels.size()])
	quit()


func _save_palette() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/vehicles/materials"))
	for key: String in PALETTE:
		var p: Array = PALETTE[key]
		var m := StandardMaterial3D.new()
		m.resource_name = "veh_" + key
		m.albedo_color = p[0]
		m.roughness = p[1]
		m.metallic = p[2]
		if EMISSIVE.has(key):
			m.emission_enabled = true
			m.emission = p[0]
			m.emission_energy_multiplier = EMISSIVE[key]
		var path := "res://assets/vehicles/materials/veh_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


## Tekerlekler: x ekseninde (aks), +x yüzünde jant. Lastik silindir + yanak halkası + jant + göbek.
func _save_wheels() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/vehicles/wheels"))
	for spec: Array in [["wheel_car", 0.135, 0.085], ["wheel_small", 0.12, 0.075], ["wheel_bus", 0.2, 0.12]]:
		tools.clear()
		var r: float = spec[1]
		var w: float = spec[2]
		cyl("tyre", Vector3.ZERO, r, w, "x")
		cyl("rim", Vector3(w * 0.5 + 0.002, 0, 0), r * 0.62, 0.012, "x")
		cyl("chrome", Vector3(w * 0.5 + 0.008, 0, 0), r * 0.2, 0.01, "x")
		for k in 5:  # jant kolları: dönüşün görünmesini sağlar
			var a := TAU * k / 5.0
			box("trim", Vector3(w * 0.5 + 0.009, sin(a) * r * 0.4, cos(a) * r * 0.4), Vector3(0.006, r * 0.12, r * 0.12))
		ResourceSaver.save(_commit(), "res://assets/vehicles/wheels/%s.tres" % spec[0])
	tools.clear()
	# Bisiklet tekerleği: ince lastik halka, jant halkası, göbek, teller.
	var br := 0.15
	torus("tyre", Vector3.ZERO, br, 0.025)
	torus("rim", Vector3.ZERO, br * 0.86, 0.012)
	cyl("chrome", Vector3.ZERO, 0.018, 0.04, "x")
	for k in 8:
		var a := TAU * k / 8.0
		box("chrome", Vector3(0, sin(a) * br * 0.43, cos(a) * br * 0.43), Vector3(0.004, br * 0.86, 0.004), Vector3(a, 0, 0))
	ResourceSaver.save(_commit(), "res://assets/vehicles/wheels/wheel_bicycle.tres")


func _commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	return mesh


func _st(m: String) -> SurfaceTool:
	if not tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[m] = st
	return tools[m]


# --- Temel geometri ---

## İlkel mesh'i indekssiz üçgenler olarak ekler (elle eklenen üçgenlerle aynı köşe biçimi; SurfaceTool'da indeksli
## ve indekssiz verinin karışması elle eklenen üçgenleri düşürüyordu).
func _append(m: String, mesh: PrimitiveMesh, xform: Transform3D) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nbasis := xform.basis.inverse().transposed()
	var st := _st(m)
	var order := indices if indices.size() > 0 else PackedInt32Array(range(verts.size()))
	for i in order:
		var n := (nbasis * normals[i]).normalized()
		var tangent := n.cross(Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT).normalized()
		st.set_normal(n)
		st.set_tangent(Plane(tangent, 1.0))
		st.set_uv(uvs[i] if uvs.size() > i else Vector2.ZERO)
		st.add_vertex(xform * verts[i])

func box(m: String, c: Vector3, s: Vector3, rot := Vector3.ZERO) -> void:
	_append(m, BOX, Transform3D(Basis.from_euler(rot) * Basis.from_scale(s), c))


func cyl(m: String, c: Vector3, r: float, h: float, axis := "y") -> void:
	var rot := Vector3.ZERO
	if axis == "x":
		rot = Vector3(0, 0, PI * 0.5)
	elif axis == "z":
		rot = Vector3(PI * 0.5, 0, 0)
	_append(m, CYL, Transform3D(Basis.from_euler(rot) * Basis.from_scale(Vector3(r * 2, h, r * 2)), c))


## Halka (x ekseni etrafında, yz düzleminde): yarıçap r, kalınlık t.
func torus(m: String, c: Vector3, r: float, t: float) -> void:
	# TorusMesh dış yarıçapı 0,5: tekdüze 2·(r + t/2) ölçek → dış yarıçap r + t/2, kesit ≈ t.
	var s := (r + t * 0.5) * 2.0
	var basis := Basis.from_euler(Vector3(0, 0, PI * 0.5)) * Basis.from_scale(Vector3(s, s, s))
	_append(m, TORUS, Transform3D(basis, c))


func tri(m: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	var st := _st(m)
	var normal := outward.normalized()
	# Teğet de yazılır: aynı yüzeye BoxMesh / CylinderMesh kopyaları eklendiğinde köşe biçimi aynı kalsın
	# (biçim farklıysa elle eklenen üçgenler kayboluyordu).
	var tangent := (b - a).normalized()
	if absf(tangent.dot(normal)) > 0.99:
		tangent = normal.cross(Vector3.UP).normalized()
	for v in [a, b, c]:
		st.set_normal(normal)
		st.set_tangent(Plane(tangent, 1.0))
		st.set_uv(Vector2(v.z, v.y))
		st.add_vertex(v)


func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	tri(m, a, b, c, outward)
	tri(m, a, c, d, outward)


## Yan profilden kalıplama: profil (z, y) noktaları saat yönünün tersine; seg_mats[i] = i → i+1 kenarının şerit materyali.
## Yanlar side_mat ile (iki yan yüz, x = ±w/2). Profil dışbükey olmalı (yan yüzler yelpaze üçgenleriyle).
func extrude(profile: PackedVector2Array, w: float, seg_mats: Array, side_mat := "paint", x_center := 0.0) -> void:
	var hw := w * 0.5
	var tris := Geometry2D.triangulate_polygon(profile)
	for s: float in [-1.0, 1.0]:
		for k in range(0, tris.size(), 3):
			var p := [profile[tris[k]], profile[tris[k + 1]], profile[tris[k + 2]]]
			tri(side_mat, Vector3(x_center + s * hw, p[0].y, p[0].x), Vector3(x_center + s * hw, p[1].y, p[1].x),
					Vector3(x_center + s * hw, p[2].y, p[2].x), Vector3(s, 0, 0))
	var center := Vector2.ZERO
	for p in profile:
		center += p
	center /= profile.size()
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var edge := b - a
		var normal2 := Vector2(edge.y, -edge.x)
		if normal2.dot((a + b) * 0.5 - center) < 0.0:
			normal2 = -normal2
		quad(seg_mats[i], Vector3(x_center - hw, a.y, a.x), Vector3(x_center + hw, a.y, a.x),
				Vector3(x_center + hw, b.y, b.x), Vector3(x_center - hw, b.y, b.x), Vector3(0, normal2.y, normal2.x))


## Yan cam: kabin yüzeyinin hemen dışında ince çokgen (z, y noktaları), iki tarafta.
func side_glass(poly: PackedVector2Array, x: float, m := "glass") -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for s: float in [-1.0, 1.0]:
		for k in range(0, tris.size(), 3):
			var p := [poly[tris[k]], poly[tris[k + 1]], poly[tris[k + 2]]]
			tri(m, Vector3(s * x, p[0].y, p[0].x), Vector3(s * x, p[1].y, p[1].x), Vector3(s * x, p[2].y, p[2].x), Vector3(s, 0, 0))


## Ortak ayrıntılar: farlar, stoplar, sinyaller, plakalar, tamponlar, aynalar, kapı çizgileri, kapı kolları.
func car_details(l: float, w: float, front_y: float, rear_y: float, mirror_z: float, mirror_y: float, doors: Array, sill_y := 0.12) -> void:
	var hw := w * 0.5
	var fz := -l * 0.5
	var rz := l * 0.5
	for s: float in [-1.0, 1.0]:
		box("headlight", Vector3(s * (hw - 0.09), front_y, fz - 0.005), Vector3(0.13, 0.045, 0.02))
		box("indicator", Vector3(s * (hw - 0.02), front_y, fz + 0.01), Vector3(0.03, 0.035, 0.02))
		box("taillight", Vector3(s * (hw - 0.08), rear_y, rz + 0.005), Vector3(0.12, 0.05, 0.02))
		box("trim", Vector3(s * (hw + 0.025), mirror_y, mirror_z), Vector3(0.05, 0.04, 0.035))
		box("trim", Vector3(s * (hw + 0.002), sill_y, 0), Vector3(0.01, 0.03, l * 0.6))
		for dz: float in doors:
			box("trim", Vector3(s * (hw + 0.003), (sill_y + front_y) * 0.5 + 0.06, dz), Vector3(0.006, 0.2, 0.008))
			box("chrome", Vector3(s * (hw + 0.006), front_y + 0.01, dz + 0.07), Vector3(0.008, 0.012, 0.04))
	box("plate", Vector3(0, front_y - 0.07, fz - 0.012), Vector3(0.2, 0.05, 0.01))
	box("plate", Vector3(0, rear_y - 0.06, rz + 0.012), Vector3(0.2, 0.05, 0.01))
	box("trim", Vector3(0, 0.12, fz - 0.01), Vector3(w + 0.01, 0.07, 0.04))
	box("trim", Vector3(0, 0.12, rz + 0.01), Vector3(w + 0.01, 0.07, 0.04))


# --- Modeller (her biri tekerlek listesi döndürür) ---

## Şehir arabası: 3,8 m, kısa burun, dik hatchback arka, yüksek kabin.
func _city_car() -> Array:
	var l := 1.65
	var w := 0.74
	extrude(PackedVector2Array([Vector2(0.825, 0.08), Vector2(0.825, 0.36), Vector2(-0.6, 0.38), Vector2(-0.825, 0.3), Vector2(-0.825, 0.08)]), w,
		["paint", "paint", "paint", "paint", "trim"])
	# Kabin: dik arka cam, kısa tavan, eğik ön cam.
	extrude(PackedVector2Array([Vector2(0.78, 0.36), Vector2(0.72, 0.64), Vector2(-0.12, 0.66), Vector2(-0.52, 0.38)]), w - 0.07,
		["glass", "paint", "glass", "paint"])
	side_glass(PackedVector2Array([Vector2(0.66, 0.42), Vector2(0.62, 0.6), Vector2(0.3, 0.61), Vector2(0.3, 0.42)]), (w - 0.07) * 0.5 + 0.003)
	side_glass(PackedVector2Array([Vector2(0.24, 0.42), Vector2(0.24, 0.61), Vector2(-0.1, 0.62), Vector2(-0.4, 0.42)]), (w - 0.07) * 0.5 + 0.003)
	box("trim", Vector3(0, 0.2, -0.83), Vector3(0.3, 0.06, 0.01))
	car_details(l, w, 0.3, 0.3, -0.38, 0.44, [-0.05])
	return [[Vector3(0.33, 0.12, -0.53), "wheel_small"], [Vector3(-0.33, 0.12, -0.53), "wheel_small"],
		[Vector3(0.33, 0.12, 0.53), "wheel_small"], [Vector3(-0.33, 0.12, 0.53), "wheel_small"]]


## Sedan: 4,6 m, uzun kaput, eğik ön cam, belirgin bagaj.
func _sedan() -> Array:
	var l := 2.0
	var w := 0.8
	extrude(PackedVector2Array([Vector2(1.0, 0.09), Vector2(1.0, 0.33), Vector2(0.75, 0.37), Vector2(-0.45, 0.37),
		Vector2(-0.97, 0.32), Vector2(-1.0, 0.09)]), w, ["paint", "paint", "paint", "paint", "paint", "trim"])
	extrude(PackedVector2Array([Vector2(0.72, 0.37), Vector2(0.38, 0.6), Vector2(-0.12, 0.61), Vector2(-0.46, 0.37)]), w - 0.08,
		["glass", "paint", "glass", "paint"])
	side_glass(PackedVector2Array([Vector2(0.6, 0.41), Vector2(0.36, 0.57), Vector2(0.14, 0.58), Vector2(0.14, 0.41)]), (w - 0.08) * 0.5 + 0.003)
	side_glass(PackedVector2Array([Vector2(0.09, 0.41), Vector2(0.09, 0.58), Vector2(-0.11, 0.58), Vector2(-0.36, 0.41)]), (w - 0.08) * 0.5 + 0.003)
	box("trim", Vector3(0, 0.25, -1.0), Vector3(0.36, 0.07, 0.012))
	box("chrome", Vector3(0, 0.29, -1.004), Vector3(0.36, 0.008, 0.01))
	car_details(l, w, 0.3, 0.32, -0.38, 0.42, [-0.25, 0.12])
	return [[Vector3(0.36, 0.135, -0.62), "wheel_car"], [Vector3(-0.36, 0.135, -0.62), "wheel_car"],
		[Vector3(0.36, 0.135, 0.62), "wheel_car"], [Vector3(-0.36, 0.135, 0.62), "wheel_car"]]


## Kompakt SUV: 4,5 m, yüksek gövde, dik kabin, tavan rayları, çamurluk kaplamaları.
func _suv() -> Array:
	var l := 1.96
	var w := 0.84
	extrude(PackedVector2Array([Vector2(0.98, 0.11), Vector2(0.98, 0.42), Vector2(-0.6, 0.45), Vector2(-0.97, 0.39),
		Vector2(-0.98, 0.11)]), w, ["paint", "paint", "paint", "paint", "trim"])
	extrude(PackedVector2Array([Vector2(0.95, 0.42), Vector2(0.86, 0.72), Vector2(-0.22, 0.74), Vector2(-0.6, 0.45)]), w - 0.07,
		["glass", "paint", "glass", "paint"])
	side_glass(PackedVector2Array([Vector2(0.82, 0.5), Vector2(0.78, 0.69), Vector2(0.44, 0.7), Vector2(0.44, 0.5)]), (w - 0.07) * 0.5 + 0.003)
	side_glass(PackedVector2Array([Vector2(0.38, 0.5), Vector2(0.38, 0.7), Vector2(0.0, 0.71), Vector2(0.0, 0.5)]), (w - 0.07) * 0.5 + 0.003)
	side_glass(PackedVector2Array([Vector2(-0.06, 0.5), Vector2(-0.06, 0.71), Vector2(-0.2, 0.71), Vector2(-0.48, 0.5)]), (w - 0.07) * 0.5 + 0.003)
	for s: float in [-1.0, 1.0]:
		box("trim", Vector3(s * 0.26, 0.76, 0.3), Vector3(0.03, 0.025, 1.0))
		for z: float in [-0.62, 0.62]:
			box("trim", Vector3(s * (w * 0.5 + 0.005), 0.29, z), Vector3(0.012, 0.06, 0.4))
	box("trim", Vector3(0, 0.31, -0.985), Vector3(0.44, 0.12, 0.012))
	box("chrome", Vector3(0, 0.13, -0.995), Vector3(0.3, 0.03, 0.01))
	car_details(l, w, 0.36, 0.4, -0.5, 0.5, [-0.18, 0.36], 0.15)
	return [[Vector3(0.38, 0.135, -0.62), "wheel_car"], [Vector3(-0.38, 0.135, -0.62), "wheel_car"],
		[Vector3(0.38, 0.135, 0.62), "wheel_car"], [Vector3(-0.38, 0.135, 0.62), "wheel_car"]]


## Elektrikli otomobil: 4,7 m, alçak, akıcı fastback (uzun eğik arka cam), ızgarasız ön, ön ve arka ışık bandı, şarj kapağı.
func _ev() -> Array:
	var l := 2.04
	var w := 0.83
	extrude(PackedVector2Array([Vector2(1.02, 0.09), Vector2(1.02, 0.31), Vector2(0.9, 0.35), Vector2(-0.5, 0.35),
		Vector2(-0.98, 0.27), Vector2(-1.02, 0.09)]), w, ["paint", "paint", "paint", "paint", "paint", "trim"])
	extrude(PackedVector2Array([Vector2(0.9, 0.35), Vector2(0.12, 0.59), Vector2(-0.12, 0.6), Vector2(-0.5, 0.35)]), w - 0.09,
		["glass", "glass", "glass", "paint"])
	side_glass(PackedVector2Array([Vector2(0.62, 0.39), Vector2(0.12, 0.56), Vector2(0.0, 0.56), Vector2(0.0, 0.39)]), (w - 0.09) * 0.5 + 0.003)
	side_glass(PackedVector2Array([Vector2(-0.05, 0.39), Vector2(-0.05, 0.56), Vector2(-0.14, 0.57), Vector2(-0.4, 0.39)]), (w - 0.09) * 0.5 + 0.003)
	box("headlight", Vector3(0, 0.29, -1.0), Vector3(w - 0.1, 0.02, 0.03))
	box("taillight", Vector3(0, 0.31, 1.025), Vector3(w - 0.08, 0.03, 0.01))
	box("trim", Vector3(w * 0.5 + 0.004, 0.31, 0.7), Vector3(0.006, 0.05, 0.06))
	car_details(l, w, 0.27, 0.29, -0.36, 0.4, [-0.2, 0.2])
	return [[Vector3(0.375, 0.135, -0.64), "wheel_car"], [Vector3(-0.375, 0.135, -0.64), "wheel_car"],
		[Vector3(0.375, 0.135, 0.64), "wheel_car"], [Vector3(-0.375, 0.135, 0.64), "wheel_car"]]


## Belediye otobüsü: 11 m, 2,5 m genişlik, alçak tabanlı; geniş cam bandı, sağda iki kapı, ön camın üstünde hat
## tabelası (yazısız), damda klima, turkuaz şerit (belediye rengi, marka yok).
func _bus() -> Array:
	var l := 4.8
	var w := 1.09
	var hl := l * 0.5
	extrude(PackedVector2Array([Vector2(hl, 0.12), Vector2(hl, 1.24), Vector2(hl - 0.08, 1.32), Vector2(-hl + 0.1, 1.32),
		Vector2(-hl, 1.2), Vector2(-hl, 0.12)]), w, ["paint", "paint", "paint", "glass", "paint", "trim"])
	var x := w * 0.5 + 0.004
	# Cam bandı ve direkler.
	side_glass(PackedVector2Array([Vector2(hl - 0.2, 0.62), Vector2(hl - 0.2, 1.12), Vector2(-hl + 0.3, 1.12), Vector2(-hl + 0.3, 0.62)]), x)
	for k in 9:
		var z := -hl + 0.6 + k * 0.5
		box("paint", Vector3(0, 0.87, z), Vector3(w + 0.012, 0.5, 0.05))
	# Turkuaz şerit ve alt kaplama.
	box("livery_turquoise", Vector3(0, 0.5, 0.0), Vector3(w + 0.014, 0.12, l - 0.04))
	# Alt kaplama tekerlek boşluklarıyla (tek parça şerit tekerlekleri örtüyordu).
	for seg: Vector2 in [Vector2(-hl + 0.05, -1.7), Vector2(-1.2, 0.9), Vector2(1.4, hl - 0.05)]:
		box("trim", Vector3(0, 0.2, (seg.x + seg.y) * 0.5), Vector3(w + 0.012, 0.1, seg.y - seg.x))
	# Kapılar (sağ, +x): ön ve orta.
	for dz: float in [-hl + 0.42, 0.1]:
		box("glass", Vector3(x + 0.002, 0.62, dz), Vector3(0.006, 0.95, 0.5))
		box("trim", Vector3(x + 0.004, 0.62, dz), Vector3(0.008, 0.95, 0.02))
	# Ön: büyük ön cam (profil şeridi) + tabela + farlar; arka: stoplar, motor kapağı ızgarası.
	box("sign", Vector3(0, 1.2, -hl - 0.005), Vector3(0.8, 0.1, 0.02))
	for s: float in [-1.0, 1.0]:
		box("headlight", Vector3(s * 0.4, 0.3, -hl - 0.008), Vector3(0.16, 0.06, 0.02))
		box("taillight", Vector3(s * 0.42, 0.35, hl + 0.008), Vector3(0.1, 0.16, 0.02))
		box("trim", Vector3(s * (w * 0.5 + 0.06), 1.05, -hl + 0.05), Vector3(0.04, 0.16, 0.03))
	box("glass", Vector3(0, 0.8, -hl - 0.003), Vector3(w - 0.12, 0.62, 0.01))
	box("trim", Vector3(0, 0.6, hl + 0.006), Vector3(0.7, 0.3, 0.01))
	box("plate", Vector3(0, 0.2, -hl - 0.012), Vector3(0.22, 0.05, 0.01))
	box("trim", Vector3(0, 1.38, 0.6), Vector3(0.7, 0.12, 0.9))
	box("trim", Vector3(0, 0.13, -hl), Vector3(w + 0.01, 0.1, 0.05))
	# Tekerlek dış yüzü gövdeden (yarı genişlik 0,545) biraz taşar; yandan görünsün.
	return [[Vector3(0.51, 0.2, -1.45), "wheel_bus"], [Vector3(-0.51, 0.2, -1.45), "wheel_bus"],
		[Vector3(0.51, 0.2, 1.15), "wheel_bus"], [Vector3(-0.51, 0.2, 1.15), "wheel_bus"]]


## Minibüs (dolmuş): 6 m, kısa burun, yüksek tavan, sağda sürgülü kapı, krem gövde + kiremit şerit.
func _minibus() -> Array:
	var l := 2.6
	var w := 0.87
	var hl := l * 0.5
	extrude(PackedVector2Array([Vector2(hl, 0.1), Vector2(hl, 1.02), Vector2(hl - 0.06, 1.06), Vector2(-hl + 0.42, 1.06),
		Vector2(-hl + 0.12, 0.6), Vector2(-hl, 0.5), Vector2(-hl, 0.1)]), w,
		["paint", "paint", "paint", "glass", "paint", "paint", "trim"])
	var x := w * 0.5 + 0.004
	side_glass(PackedVector2Array([Vector2(hl - 0.12, 0.6), Vector2(hl - 0.12, 0.92), Vector2(-hl + 0.48, 0.92), Vector2(-hl + 0.2, 0.6)]), x)
	for z: float in [0.55, 0.0, -0.5]:
		box("paint", Vector3(0, 0.76, z), Vector3(w + 0.012, 0.34, 0.05))
	box("livery_terracotta", Vector3(0, 0.45, 0), Vector3(w + 0.014, 0.08, l - 0.05))
	box("trim", Vector3(x + 0.003, 0.55, -0.15), Vector3(0.006, 0.7, 0.02))
	box("trim", Vector3(x + 0.003, 0.55, 0.38), Vector3(0.006, 0.7, 0.02))
	box("sign", Vector3(0, 0.99, -hl + 0.38), Vector3(0.5, 0.07, 0.02), Vector3(deg_to_rad(-30), 0, 0))
	car_details(l, w, 0.4, 0.45, -hl + 0.4, 0.62, [-0.5])
	return [[Vector3(0.39, 0.135, -0.8), "wheel_car"], [Vector3(-0.39, 0.135, -0.8), "wheel_car"],
		[Vector3(0.39, 0.135, 0.85), "wheel_car"], [Vector3(-0.39, 0.135, 0.85), "wheel_car"]]


## Teslimat vanı: 5,2 m, yük bölmesi penceresiz, yalnızca kabin camları, arkada çift kapı, yan sürgülü kapı çizgisi.
func _van() -> Array:
	var l := 2.25
	var w := 0.86
	var hl := l * 0.5
	extrude(PackedVector2Array([Vector2(hl, 0.1), Vector2(hl, 0.98), Vector2(hl - 0.05, 1.0), Vector2(-hl + 0.48, 1.0),
		Vector2(-hl + 0.15, 0.58), Vector2(-hl, 0.5), Vector2(-hl, 0.1)]), w,
		["paint", "paint", "paint", "glass", "paint", "paint", "trim"])
	var x := w * 0.5 + 0.004
	side_glass(PackedVector2Array([Vector2(-hl + 0.56, 0.6), Vector2(-hl + 0.56, 0.88), Vector2(-hl + 0.52, 0.9), Vector2(-hl + 0.22, 0.6)]), x)
	box("trim", Vector3(x + 0.003, 0.55, -0.35), Vector3(0.006, 0.82, 0.015))
	box("trim", Vector3(x + 0.003, 0.55, 0.45), Vector3(0.006, 0.82, 0.015))
	box("trim", Vector3(0, 0.55, hl + 0.006), Vector3(0.012, 0.82, 0.01))
	box("livery_turquoise", Vector3(0, 0.62, 0.25), Vector3(w + 0.012, 0.1, 1.2))
	car_details(l, w, 0.4, 0.42, -hl + 0.42, 0.62, [-0.55])
	return [[Vector3(0.38, 0.135, -0.68), "wheel_car"], [Vector3(-0.38, 0.135, -0.68), "wheel_car"],
		[Vector3(0.38, 0.135, 0.72), "wheel_car"], [Vector3(-0.38, 0.135, 0.72), "wheel_car"]]


## Şehir bisikleti: 1,8 m; çelik çerçeve (teal), sele, gidon, pedallar, zincir, ön sepet, çamurluklar.
func _bicycle() -> Array:
	var wz := 0.31
	var ry := 0.1625  # tekerlek yarıçapı (0,15 + lastik yarısı): lastik zemine oturur
	var bb := Vector3(0, 0.12, 0.02)       # pedal göbeği
	var seat := Vector3(0, 0.36, 0.1)      # sele borusu üstü
	var head := Vector3(0, 0.34, -0.22)    # gidon boğazı
	_tube("frame_teal", bb, seat, 0.012)
	_tube("frame_teal", bb, head + Vector3(0, -0.08, 0), 0.013)
	_tube("frame_teal", seat + Vector3(0, -0.03, 0), head, 0.011)
	for s: float in [-1.0, 1.0]:
		_tube("frame_teal", bb + Vector3(s * 0.025, 0, 0), Vector3(s * 0.03, ry, wz), 0.008)
		_tube("frame_teal", seat + Vector3(s * 0.02, -0.02, 0), Vector3(s * 0.03, ry, wz), 0.007)
		_tube("frame_teal", head + Vector3(s * 0.02, -0.05, 0), Vector3(s * 0.03, ry, -wz), 0.008)
	_tube("chrome", seat, seat + Vector3(0, 0.05, 0.01), 0.008)
	box("saddle", seat + Vector3(0, 0.06, 0.0), Vector3(0.06, 0.025, 0.12))
	_tube("chrome", head, head + Vector3(0, 0.08, 0.03), 0.008)
	box("trim", head + Vector3(0, 0.08, 0.04), Vector3(0.24, 0.014, 0.014))
	for s: float in [-1.0, 1.0]:
		box("trim", head + Vector3(s * 0.12, 0.08, 0.06), Vector3(0.018, 0.018, 0.05))
		box("trim", bb + Vector3(s * 0.05, s * 0.04, s * 0.04), Vector3(0.012, 0.012, 0.06), Vector3(deg_to_rad(40), 0, 0))
		box("trim", bb + Vector3(s * 0.075, s * 0.07, s * 0.07), Vector3(0.04, 0.01, 0.025))
	cyl("chrome", bb + Vector3(0.03, 0, 0), 0.045, 0.006, "x")
	box("trim", Vector3(0.03, ry, (bb.z + wz) * 0.5) + Vector3(0, -0.01, 0), Vector3(0.006, 0.006, wz - bb.z))
	box("basket", head + Vector3(0, -0.02, -0.12), Vector3(0.16, 0.09, 0.12))
	box("frame_teal", Vector3(0, ry + 0.16, wz), Vector3(0.04, 0.008, 0.18), Vector3(deg_to_rad(15), 0, 0))
	box("frame_teal", Vector3(0, ry + 0.16, -wz), Vector3(0.04, 0.008, 0.18), Vector3(deg_to_rad(-15), 0, 0))
	box("headlight", head + Vector3(0, 0.0, -0.05), Vector3(0.03, 0.025, 0.02))
	box("taillight", Vector3(0, ry + 0.17, wz + 0.1), Vector3(0.03, 0.02, 0.01))
	return [[Vector3(0, ry, -wz), "wheel_bicycle"], [Vector3(0, ry, wz), "wheel_bicycle"]]


func _tube(m: String, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD)
	basis = basis * Basis.from_euler(Vector3(PI * 0.5, 0, 0)) * Basis.from_scale(Vector3(r * 2, d.length(), r * 2))
	_append(m, CYL, Transform3D(basis, (a + b) * 0.5))
