extends SceneTree
## Sahip: A. Görsel revizyon 7 · Akdeniz bina kütüphanesi üreticisi (Blender gerekmez).
## Godot'nun SurfaceTool'uyla özel geometri kurar ve kaydeder:
##   assets/materials/architecture/arch_*.tres   ortak mimari palet
##   assets/buildings/<kategori>/<model>.tres     ArrayMesh (materyal başına yüzey, materyaller dış dosya)
##   assets/buildings/<kategori>/<model>.tscn     önizleme sahnesi (MeshInstance3D)
## Çalıştırma: <godot> --headless --path . --script res://scripts/world/dev/gen_building_library.gd
## Ölçek: 1 birim ≈ 2,3 m, kat yüksekliği 1,4 birim. Pivot taban merkezi (y = 0), ön cephe +z (kameraya bakar).
## Modeller yalnızca görseldir: yatırım değildir, BuildingDefinition'a bağlanmaz (dekor, city_decor.gd yerleştirir).

const FLOOR := 1.4
const PALETTE := {
	"facade": [Color("#E8DDC8"), 0.9, 0.0],
	"facade_white": [Color(0.95, 0.94, 0.9), 0.9, 0.0],
	"facade_ochre": [Color(0.89, 0.78, 0.6), 0.9, 0.0],
	"facade_rose": [Color(0.91, 0.8, 0.74), 0.9, 0.0],
	"stone": [Color("#D6C8AE"), 0.95, 0.0],
	"stone_dark": [Color(0.64, 0.58, 0.5), 0.95, 0.0],
	"roof": [Color("#C97960"), 0.85, 0.0],
	"roof_dark": [Color("#A85F4D"), 0.85, 0.0],
	"rail": [Color("#6D7776"), 0.5, 0.5],
	"frame": [Color("#8A938F"), 0.6, 0.2],
	"glass": [Color("#8FB8C2"), 0.12, 0.25],
	"wood": [Color("#A97C59"), 0.85, 0.0],
	"wood_dark": [Color(0.48, 0.33, 0.22), 0.85, 0.0],
	"trim": [Color(0.97, 0.96, 0.93), 0.85, 0.0],
	"interior": [Color(0.16, 0.19, 0.21), 0.9, 0.0],
	"shutter_teal": [Color(0.3, 0.55, 0.55), 0.8, 0.0],
	"shutter_green": [Color(0.38, 0.5, 0.36), 0.8, 0.0],
	"awning_teal": [Color(0.33, 0.6, 0.6), 0.8, 0.0],
	"awning_terracotta": [Color(0.75, 0.45, 0.33), 0.8, 0.0],
	"metal": [Color(0.62, 0.64, 0.66), 0.45, 0.6],
	"plant": [Color(0.36, 0.5, 0.28), 0.95, 0.0],
	"lawn": [Color(0.48, 0.6, 0.32), 1.0, 0.0],
	"solar": [Color(0.13, 0.2, 0.34), 0.3, 0.5],
	"water": [Color(0.3, 0.66, 0.7), 0.1, 0.2],
}

var mats := {}
var tools := {}
var BOX := BoxMesh.new()
var CYL := CylinderMesh.new()


func _initialize() -> void:
	CYL.top_radius = 0.5
	CYL.bottom_radius = 0.5
	CYL.height = 1.0
	CYL.radial_segments = 8
	CYL.rings = 0
	_save_palette()
	var models := {
		"residential/residential_house_a": _house_a, "residential/residential_house_b": _house_b,
		"residential/mediterranean_house_c": _house_c,
		"apartments/apartment_midrise_a": _apartment_a, "apartments/apartment_modern_b": _apartment_b,
		"apartments/apartment_urban_c": _apartment_c,
		"villas/villa_modern_a": _villa_a, "villas/villa_mediterranean_b": _villa_b,
		"commercial/commercial_shop_a": _commercial_a, "commercial/commercial_shop_b": _commercial_b,
		"public/public_building_a": _public_a, "public/public_building_b": _public_b,
	}
	for path: String in models:
		tools.clear()
		models[path].call()
		var mesh := _commit()
		var dir := "res://assets/buildings/" + path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		ResourceSaver.save(mesh, "res://assets/buildings/%s.tres" % path)
		var root := MeshInstance3D.new()
		root.name = path.get_file().to_pascal_case()
		root.mesh = load("res://assets/buildings/%s.tres" % path)
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene, "res://assets/buildings/%s.tscn" % path)
		root.free()
		var aabb := mesh.get_aabb()
		var tris := 0
		for i in mesh.get_surface_count():
			tris += mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX].size() / 3
		print("%-36s taban %.1f x %.1f  yükseklik %.1f  %2d materyal  %5d üçgen" % [path, aabb.size.x, aabb.size.z, aabb.end.y, mesh.get_surface_count(), tris])
	quit()


func _save_palette() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/materials/architecture"))
	for name: String in PALETTE:
		var p: Array = PALETTE[name]
		var m := StandardMaterial3D.new()
		m.resource_name = "arch_" + name
		m.albedo_color = p[0]
		m.roughness = p[1]
		m.metallic = p[2]
		var path := "res://assets/materials/architecture/arch_%s.tres" % name
		ResourceSaver.save(m, path)
		mats[name] = load(path)


func _commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for name: String in tools:
		var st: SurfaceTool = tools[name]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[name])
	return mesh


func _st(name: String) -> SurfaceTool:
	if not tools.has(name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[name] = st
	return tools[name]


# --- Temel geometri ---

func box(m: String, c: Vector3, s: Vector3, rot := Vector3.ZERO) -> void:
	_st(m).append_from(BOX, 0, Transform3D(Basis.from_euler(rot) * Basis.from_scale(s), c))


## Silindir; eksen "y" (dik), "x" ya da "z" (yatık).
func cyl(m: String, c: Vector3, r: float, h: float, axis := "y") -> void:
	var rot := Vector3.ZERO
	if axis == "x":
		rot = Vector3(0, 0, PI * 0.5)
	elif axis == "z":
		rot = Vector3(PI * 0.5, 0, 0)
	_st(m).append_from(CYL, 0, Transform3D(Basis.from_euler(rot) * Basis.from_scale(Vector3(r * 2, h, r * 2)), c))


## Dörtgen (düz gölgeleme); dış normal yönüne göre sarım otomatik düzeltilir.
func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	tri(m, a, b, c, outward)
	tri(m, a, c, d, outward)


func tri(m: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(outward) > 0.0:  # Godot ön yüzleri saat yönünde
		var t := b
		b = c
		c = t
	var st := _st(m)
	var normal := outward.normalized()
	for v in [a, b, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


# --- Mimari parçalar (ön cephe +z düzleminde ya da yan cephe +x düzleminde) ---

## Pencere: girinti, cam, çerçeve, kayıt, denizlik; isteğe bağlı panjur. face "z" (ön) ya da "x" (yan).
func window(face: String, plane: float, u: float, y: float, w: float, h: float, shutters := "", frame := "frame") -> void:
	var p := func(along: float, up: float, out: float) -> Vector3:
		return Vector3(u + along, y + up, plane + out) if face == "z" else Vector3(plane + out, y + up, u - along)
	var sz := func(along: float, up: float, out: float) -> Vector3:
		return Vector3(along, up, out) if face == "z" else Vector3(out, up, along)
	box("interior", p.call(0, 0, -0.004), sz.call(w, h, 0.02))
	box("glass", p.call(0, 0, 0.004), sz.call(w * 0.94, h * 0.94, 0.01))
	box(frame, p.call(0, h * 0.5, 0.012), sz.call(w + 0.06, 0.045, 0.035))
	box(frame, p.call(0, -h * 0.5, 0.012), sz.call(w + 0.06, 0.045, 0.035))
	for s: float in [-1.0, 1.0]:
		box(frame, p.call(s * w * 0.5, 0, 0.012), sz.call(0.045, h, 0.035))
	if w > 0.34:
		box(frame, p.call(0, 0, 0.01), sz.call(0.025, h, 0.02))
	box("trim", p.call(0, -h * 0.5 - 0.035, 0.035), sz.call(w + 0.12, 0.04, 0.08))
	if shutters != "":
		for s: float in [-1.0, 1.0]:
			box(shutters, p.call(s * (w * 0.5 + w * 0.26 + 0.03), 0, 0.015), sz.call(w * 0.5, h, 0.025))


## Boy pencere / balkon kapısı (alt kenar döşemede, denizlik yok).
func french_door(plane: float, x: float, y0: float, w: float, h: float) -> void:
	box("interior", Vector3(x, y0 + h * 0.5, plane - 0.004), Vector3(w, h, 0.02))
	box("glass", Vector3(x, y0 + h * 0.5, plane + 0.004), Vector3(w * 0.92, h * 0.94, 0.01))
	box("frame", Vector3(x, y0 + h, plane + 0.012), Vector3(w + 0.06, 0.045, 0.035))
	for s: float in [-1.0, 0.0, 1.0]:
		box("frame", Vector3(x + s * w * 0.5, y0 + h * 0.5, plane + 0.012), Vector3(0.04, h, 0.035))


## Kapı: taş çerçeve, ahşap kanat, basamak, isteğe bağlı saçak.
func door(plane: float, x: float, w := 0.42, h := 0.82, panel := "wood_dark", canopy := true) -> void:
	box("trim", Vector3(x, h * 0.5 + 0.03, plane + 0.012), Vector3(w + 0.12, h + 0.08, 0.03))
	box(panel, Vector3(x, h * 0.5, plane + 0.02), Vector3(w, h, 0.03))
	box("metal", Vector3(x + w * 0.3, h * 0.48, plane + 0.04), Vector3(0.03, 0.03, 0.03))
	box("stone_dark", Vector3(x, 0.03, plane + 0.12), Vector3(w + 0.3, 0.06, 0.22))
	if canopy:
		box("trim", Vector3(x, h + 0.13, plane + 0.14), Vector3(w + 0.34, 0.05, 0.3))


## Balkon: döşeme, babalı demir korkuluk ya da cam korkuluk, alt konsollar.
func balcony(plane: float, x: float, floor_y: float, w: float, depth := 0.36, style := "bars") -> void:
	box("trim", Vector3(x, floor_y + 0.03, plane + depth * 0.5), Vector3(w, 0.06, depth))
	for s: float in [-1.0, 1.0]:
		box("trim", Vector3(x + s * (w * 0.5 - 0.05), floor_y - 0.05, plane + depth * 0.35), Vector3(0.05, 0.1, depth * 0.6))
	var front := plane + depth - 0.02
	if style == "glass":
		box("glass", Vector3(x, floor_y + 0.22, front), Vector3(w - 0.04, 0.3, 0.015))
		box("rail", Vector3(x, floor_y + 0.38, front), Vector3(w, 0.025, 0.03))
		return
	if style == "solid":
		box("trim", Vector3(x, floor_y + 0.2, front), Vector3(w, 0.32, 0.04))
		return
	box("rail", Vector3(x, floor_y + 0.37, front), Vector3(w, 0.03, 0.03))
	box("rail", Vector3(x, floor_y + 0.09, front), Vector3(w, 0.02, 0.02))
	var n := maxi(3, int(w / 0.13))
	for i in n + 1:
		box("rail", Vector3(x - w * 0.5 + i * w / n, floor_y + 0.23, front), Vector3(0.018, 0.28, 0.018))
	for s: float in [-1.0, 1.0]:
		box("rail", Vector3(x + s * w * 0.5, floor_y + 0.37, plane + depth * 0.5), Vector3(0.03, 0.03, depth))


## Beşik çatı (mahya x ekseninde): eğimli kaplamalar, alın üçgenleri, kiremit sıraları, mahya, saçak altı, oluk.
func gable_roof(cx: float, cz: float, y: float, w: float, d: float, rise: float, o := 0.22, gable_mat := "facade") -> void:
	var half := d * 0.5
	var ang := atan2(rise, half)
	var run := sqrt(pow(half + o, 2) + pow(rise + o * rise / half, 2))
	for s: float in [-1.0, 1.0]:
		var mid := Vector3(cx, y + rise * 0.5 - o * rise / half * 0.5, cz + s * (half + o) * 0.5)
		box("roof", mid, Vector3(w + 2 * o, 0.07, run), Vector3(s * ang, 0, 0))
		# Kiremit sıraları: eğim boyunca aralıklı ince şeritler.
		var rows := int(run / 0.2)
		for r in rows:
			var t := (r + 0.5) / rows
			var pz := cz + s * (half + o) * (1.0 - t)
			var py := (y - o * rise / half) + (rise + o * rise / half) * t + 0.05
			box("roof_dark", Vector3(cx, py, pz), Vector3(w + 2 * o, 0.035, 0.05), Vector3(s * ang, 0, 0))
		cyl("rail", Vector3(cx, y - o * rise / half - 0.02, cz + s * (half + o)), 0.035, w + 2 * o, "x")
	for s: float in [-1.0, 1.0]:
		var px := cx + s * w * 0.5
		tri(gable_mat, Vector3(px, y, cz - half), Vector3(px, y, cz + half), Vector3(px, y + rise, cz), Vector3(s, 0, 0))
	box("roof_dark", Vector3(cx, y + rise + 0.03, cz), Vector3(w + 2 * o + 0.04, 0.08, 0.12))
	box("trim", Vector3(cx, y - 0.03, cz), Vector3(w + 0.1, 0.06, d + 0.1))


## Kırma çatı (mahya x ekseninde, w > d): dört eğim, kiremit sıraları, saçak altı, oluk.
func hip_roof(cx: float, cz: float, y: float, w: float, d: float, rise: float, o := 0.22) -> void:
	var x0 := cx - w * 0.5 - o
	var x1 := cx + w * 0.5 + o
	var z0 := cz - d * 0.5 - o
	var z1 := cz + d * 0.5 + o
	var ey := y - 0.05
	var ridge_half := maxf(0.0, (w - d) * 0.5)
	var r0 := Vector3(cx - ridge_half, y + rise, cz)
	var r1 := Vector3(cx + ridge_half, y + rise, cz)
	quad("roof", Vector3(x0, ey, z1), Vector3(x1, ey, z1), r1, r0, Vector3(0, 1, 1))
	quad("roof", Vector3(x1, ey, z0), Vector3(x0, ey, z0), r0, r1, Vector3(0, 1, -1))
	tri("roof", Vector3(x1, ey, z1), Vector3(x1, ey, z0), r1, Vector3(1, 1, 0))
	tri("roof", Vector3(x0, ey, z0), Vector3(x0, ey, z1), r0, Vector3(-1, 1, 0))
	# Kiremit sıraları ön ve arka eğimde (yükseldikçe kısalır).
	var depth := d * 0.5 + o
	var rows := int(depth / 0.2)
	for r in rows:
		var t := (r + 0.5) / rows
		var span := (x1 - x0) * (1.0 - t) + ridge_half * 2.0 * t
		var py := ey + (rise + 0.05) * t + 0.03
		for s: float in [-1.0, 1.0]:
			box("roof_dark", Vector3(cx, py, cz + s * depth * (1.0 - t)), Vector3(span, 0.03, 0.045), Vector3(s * atan2(rise, depth), 0, 0))
	box("roof_dark", Vector3(cx, y + rise + 0.02, cz), Vector3(ridge_half * 2 + 0.1, 0.07, 0.1))
	box("trim", Vector3(cx, ey - 0.03, cz), Vector3(x1 - x0, 0.06, z1 - z0))
	for s: float in [-1.0, 1.0]:
		cyl("rail", Vector3(cx, ey - 0.04, cz + s * (d * 0.5 + o)), 0.035, x1 - x0, "x")


## Düz dam: parapet ve harpuşta, dam yüzeyi.
func flat_roof(cx: float, cz: float, y: float, w: float, d: float, parapet := 0.22, mat := "facade") -> void:
	box("stone_dark", Vector3(cx, y + 0.02, cz), Vector3(w - 0.1, 0.04, d - 0.1))
	for s: float in [-1.0, 1.0]:
		box(mat, Vector3(cx, y + parapet * 0.5, cz + s * (d * 0.5 - 0.05)), Vector3(w, parapet, 0.1))
		box(mat, Vector3(cx + s * (w * 0.5 - 0.05), y + parapet * 0.5, cz), Vector3(0.1, parapet, d - 0.2))
	box("trim", Vector3(cx, y + parapet + 0.02, cz + d * 0.5 - 0.05), Vector3(w + 0.06, 0.04, 0.14))
	box("trim", Vector3(cx, y + parapet + 0.02, cz - d * 0.5 + 0.05), Vector3(w + 0.06, 0.04, 0.14))
	box("trim", Vector3(cx + w * 0.5 - 0.05, y + parapet + 0.02, cz), Vector3(0.14, 0.04, d))
	box("trim", Vector3(cx - w * 0.5 + 0.05, y + parapet + 0.02, cz), Vector3(0.14, 0.04, d))


func chimney(x: float, z: float, y0: float, h: float) -> void:
	box("stone", Vector3(x, y0 + h * 0.5, z), Vector3(0.28, h, 0.28))
	box("trim", Vector3(x, y0 + h + 0.03, z), Vector3(0.36, 0.06, 0.36))
	box("roof_dark", Vector3(x, y0 + h + 0.12, z), Vector3(0.22, 0.04, 0.22))


func ac_unit(c: Vector3, face := "z") -> void:
	var s := Vector3(0.32, 0.22, 0.14) if face == "z" else Vector3(0.14, 0.22, 0.32)
	box("metal", c, s)
	var g := Vector3(0, 0, 0.075) if face == "z" else Vector3(0.075, 0, 0)
	cyl("rail", c + g, 0.07, 0.01, "z" if face == "z" else "x")


## Güneş enerjili su ısıtıcısı (Türkiye damlarına özgü): eğik panel ve yatık depo.
func solar_heater(c: Vector3) -> void:
	box("solar", c + Vector3(0, 0.18, 0.08), Vector3(0.5, 0.03, 0.4), Vector3(deg_to_rad(-35), 0, 0))
	cyl("metal", c + Vector3(0, 0.36, -0.12), 0.08, 0.52, "x")
	for s: float in [-1.0, 1.0]:
		box("rail", c + Vector3(s * 0.22, 0.14, -0.05), Vector3(0.03, 0.28, 0.03))


func downpipe(x: float, z: float, top: float) -> void:
	cyl("rail", Vector3(x, top * 0.5, z), 0.025, top)


func band(cx: float, cz: float, y: float, w: float, d: float, mat := "trim", h := 0.06) -> void:
	box(mat, Vector3(cx, y, cz), Vector3(w + 0.04, h, d + 0.04))


func pergola(c: Vector3, w: float, d: float, h := 0.85) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box("wood", c + Vector3(sx * (w * 0.5 - 0.04), h * 0.5, sz * (d * 0.5 - 0.04)), Vector3(0.06, h, 0.06))
	for sz: float in [-1.0, 1.0]:
		box("wood", c + Vector3(0, h, sz * (d * 0.5 - 0.04)), Vector3(w + 0.1, 0.06, 0.06))
	var n := int(w / 0.18)
	for i in n + 1:
		box("wood", c + Vector3(-w * 0.5 + i * w / n, h + 0.05, 0), Vector3(0.04, 0.04, d + 0.12))


func planter(c: Vector3, w: float) -> void:
	box("stone", c + Vector3(0, 0.1, 0), Vector3(w, 0.2, 0.22))
	box("plant", c + Vector3(0, 0.25, 0), Vector3(w - 0.06, 0.14, 0.16))


# --- 12 model ---

## A · Klasik Akdeniz evi: 2 kat, kırma terracotta çatı, panjurlu pencereler, ön balkon, baca, oluk.
func _house_a() -> void:
	var w := 3.0
	var d := 2.6
	var zf := d * 0.5
	var xf := w * 0.5
	box("facade", Vector3(0, FLOOR, 0), Vector3(w, FLOOR * 2, d))
	band(0, 0, 0.12, w, d, "stone", 0.24)
	band(0, 0, FLOOR, w, d)
	door(zf, -0.15)
	window("z", zf, -0.95, 0.78, 0.42, 0.55, "shutter_teal")
	window("z", zf, 0.8, 0.78, 0.42, 0.55, "shutter_teal")
	french_door(zf, -0.15, FLOOR + 0.05, 0.5, 0.85)
	balcony(zf, -0.15, FLOOR, 1.1)
	window("z", zf, 0.95, FLOOR + 0.78, 0.42, 0.55, "shutter_teal")
	window("z", zf, -1.05, FLOOR + 0.78, 0.36, 0.55, "shutter_teal")
	for z: float in [-0.55, 0.55]:
		window("x", xf, z, 0.78, 0.38, 0.5, "shutter_teal")
		window("x", xf, z, FLOOR + 0.78, 0.38, 0.5, "shutter_teal")
	hip_roof(0, 0, FLOOR * 2, w, d, 0.85)
	chimney(-0.85, -0.45, FLOOR * 2 + 0.3, 0.95)
	downpipe(xf - 0.05, zf + 0.15, FLOOR * 2)
	planter(Vector3(0.85, 0, zf + 0.2), 0.6)


## B · Modern Akdeniz evi: iki kademeli kütle, boy camlar, ahşap kaplama, güneş kırıcılar, cam korkuluklu teras.
func _house_b() -> void:
	var w := 3.3
	var d := 2.8
	var zf := d * 0.5
	box("facade_white", Vector3(0, FLOOR * 0.5, 0), Vector3(w, FLOOR, d))
	box("facade_white", Vector3(-0.45, FLOOR * 1.5, -0.25), Vector3(2.4, FLOOR, 2.3))
	# Zemin: boy camlar ve ahşap kaplamalı giriş bölümü.
	box("wood", Vector3(1.15, FLOOR * 0.5, zf + 0.01), Vector3(1.0, FLOOR - 0.1, 0.03))
	for i in 6:
		box("wood_dark", Vector3(0.7 + i * 0.18, FLOOR * 0.5, zf + 0.03), Vector3(0.025, FLOOR - 0.12, 0.02))
	french_door(zf, -0.55, 0.0, 1.6, 1.1)
	door(zf, 1.15, 0.38, 0.82, "wood_dark", false)
	box("trim", Vector3(-0.55, 1.18, zf + 0.22), Vector3(2.0, 0.06, 0.48))
	# Üst kat: geniş pencere, yatay güneş kırıcılar, terasta cam korkuluk ve pergola.
	var uz := -0.25 + 1.15
	french_door(uz, -0.45, FLOOR + 0.05, 1.5, 0.95)
	for k in 4:
		box("wood", Vector3(-0.45, FLOOR + 0.2 + k * 0.22, uz + 0.1), Vector3(1.6, 0.03, 0.06))
	box("glass", Vector3(0, FLOOR + 0.22, zf - 0.02), Vector3(w - 0.08, 0.3, 0.015))
	box("rail", Vector3(0, FLOOR + 0.38, zf - 0.02), Vector3(w, 0.025, 0.03))
	pergola(Vector3(1.15, FLOOR, 0.55), 0.9, 1.3, 0.8)
	window("x", w * 0.5, -0.4, 0.75, 0.9, 0.5)
	window("x", 0.75, -0.6, FLOOR + 0.75, 0.9, 0.5)
	flat_roof(-0.45, -0.25, FLOOR * 2, 2.4, 2.3, 0.18, "facade_white")
	box("trim", Vector3(0, FLOOR + 0.02, 0), Vector3(w + 0.06, 0.05, d + 0.06))
	solar_heater(Vector3(-0.9, FLOOR * 2 + 0.04, -0.6))
	planter(Vector3(-1.2, 0, zf + 0.22), 0.7)


## C · Geleneksel Antalya evi: taş zemin kat, sıvalı üst kat, ahşap cumba (çıkma), ahşap pencereler, beşik çatı.
func _house_c() -> void:
	var w := 2.8
	var d := 2.6
	var zf := d * 0.5
	var xf := w * 0.5
	box("stone", Vector3(0, FLOOR * 0.5, 0), Vector3(w, FLOOR, d))
	for k in range(1, 5):
		band(0, 0, k * FLOOR / 5.0, w, d, "stone_dark", 0.025)
	for s: float in [-1.0, 1.0]:
		box("stone_dark", Vector3(s * (w * 0.5 - 0.1), FLOOR * 0.5, 0), Vector3(0.24, FLOOR, d + 0.03))
	box("facade_ochre", Vector3(0, FLOOR * 1.5, 0), Vector3(w, FLOOR, d))
	band(0, 0, FLOOR, w, d, "wood_dark", 0.08)
	# Zemin: kemerli ahşap kapı ve küçük demir parmaklıklı pencereler.
	door(zf, -0.6, 0.48, 0.9, "wood", false)
	box("stone_dark", Vector3(-0.6, 0.98, zf + 0.03), Vector3(0.62, 0.12, 0.04))
	window("z", zf, 0.75, 0.75, 0.36, 0.42, "", "wood_dark")
	for i in 4:
		box("rail", Vector3(0.62 + i * 0.09, 0.75, zf + 0.04), Vector3(0.015, 0.42, 0.015))
	# Cumba: üst katta öne çıkan ahşap çerçeveli kutu, konsollar üzerinde.
	var cz := zf + 0.32
	box("facade_ochre", Vector3(0.1, FLOOR + 0.62, zf + 0.16), Vector3(1.7, 1.0, 0.32))
	box("wood_dark", Vector3(0.1, FLOOR + 0.1, zf + 0.16), Vector3(1.78, 0.08, 0.38))
	box("wood_dark", Vector3(0.1, FLOOR + 1.14, zf + 0.16), Vector3(1.78, 0.06, 0.38))
	for s: float in [-1.0, 1.0]:
		box("wood_dark", Vector3(0.1 + s * 0.75, FLOOR - 0.06, zf + 0.12), Vector3(0.07, 0.2, 0.26), Vector3(deg_to_rad(-25), 0, 0))
	for i in 3:
		window("z", cz, -0.45 + i * 0.55, FLOOR + 0.62, 0.36, 0.62, "", "wood_dark")
	window("x", 0.95, zf + 0.16, FLOOR + 0.62, 0.2, 0.55, "", "wood_dark")
	window("x", xf, -0.5, FLOOR + 0.7, 0.36, 0.55, "", "wood_dark")
	window("x", xf, 0.4, 0.75, 0.32, 0.42, "", "wood_dark")
	gable_roof(0, 0, FLOOR * 2, w, d, 0.8, 0.24, "facade_ochre")
	box("roof", Vector3(0.1, FLOOR * 2 + 0.03, zf + 0.25), Vector3(1.9, 0.05, 0.5), Vector3(deg_to_rad(18), 0, 0))
	chimney(0.8, -0.55, FLOOR * 2 + 0.3, 0.8)
	downpipe(-xf + 0.05, zf + 0.12, FLOOR * 2)


## Apartman A · 4 kat, balkonlar, kat bantları, klimalar, kırma çatı, saçaklı giriş.
func _apartment_a() -> void:
	var w := 3.4
	var d := 3.0
	var zf := d * 0.5
	var xf := w * 0.5
	var floors := 4
	box("facade", Vector3(0, FLOOR * floors * 0.5, 0), Vector3(w, FLOOR * floors, d))
	band(0, 0, 0.14, w, d, "stone", 0.28)
	door(zf, 0.0, 0.5, 0.88)
	window("z", zf, -1.1, 0.8, 0.42, 0.5)
	window("z", zf, 1.1, 0.8, 0.42, 0.5)
	for f in range(1, floors):
		var y := f * FLOOR
		band(0, 0, y, w, d)
		for s: float in [-1.0, 1.0]:
			french_door(zf, s * 0.85, y + 0.05, 0.5, 0.85)
			balcony(zf, s * 0.85, y, 1.15)
			window("x", xf, s * 0.7, y + 0.78, 0.4, 0.55, "shutter_green")
		window("z", zf, 0.0, y + 0.78, 0.3, 0.55)
		ac_unit(Vector3(xf + 0.08, y + 0.35, -0.9), "x")
	for s: float in [-1.0, 1.0]:
		window("x", xf, s * 0.7, 0.8, 0.4, 0.5)
	hip_roof(0, 0, FLOOR * floors, w, d, 0.9)
	chimney(1.0, -0.6, FLOOR * floors + 0.3, 0.75)
	downpipe(xf - 0.05, zf + 0.12, FLOOR * floors)


## Apartman B · 5 kat modern: geniş cam korkuluklu balkonlar (katlara göre kaydırmalı), taş dikey kanatlar, çatı terası.
func _apartment_b() -> void:
	var w := 3.6
	var d := 3.0
	var zf := d * 0.5
	var xf := w * 0.5
	var floors := 5
	box("facade_white", Vector3(0, FLOOR * floors * 0.5, 0), Vector3(w, FLOOR * floors, d))
	# Zemin: cam lobi, taş kaplama.
	box("stone", Vector3(-1.1, FLOOR * 0.5, zf + 0.01), Vector3(1.3, FLOOR, 0.04))
	french_door(zf, 0.65, 0.0, 2.1, 1.15)
	box("trim", Vector3(0.65, 1.22, zf + 0.3), Vector3(2.4, 0.07, 0.6))
	for f in range(1, floors):
		var y := f * FLOOR
		var shift := 0.35 if f % 2 == 0 else -0.35
		french_door(zf, shift, y + 0.05, 1.8, 0.95)
		balcony(zf, shift, y, 2.3, 0.5, "glass")
		window("z", zf, -shift * 3.2 if absf(shift * 3.2) < 1.5 else -1.45, y + 0.75, 0.32, 0.6)
		window("x", xf, -0.5, y + 0.75, 0.9, 0.6)
		box("trim", Vector3(0, y + 0.02, 0), Vector3(w + 0.05, 0.05, d + 0.05))
	for s: float in [-1.0, 1.0]:
		box("stone", Vector3(s * (xf - 0.06), FLOOR * floors * 0.5, zf + 0.1), Vector3(0.14, FLOOR * floors, 0.22))
	flat_roof(0, 0, FLOOR * floors, w, d, 0.15, "facade_white")
	box("glass", Vector3(0, FLOOR * floors + 0.3, zf - 0.08), Vector3(w - 0.3, 0.3, 0.015))
	pergola(Vector3(-0.8, FLOOR * floors, 0.3), 1.4, 1.4, 0.75)
	planter(Vector3(0.9, FLOOR * floors + 0.04, 0.6), 0.9)
	box("facade_white", Vector3(1.0, FLOOR * floors + 0.45, -0.8), Vector3(1.0, 0.9, 0.9))


## Apartman C · 6 kat yoğun kent apartmanı: taş zemin kat dükkân, üst üste çıkmalar, küçük balkonlar,
## damda güneş enerjili su ısıtıcıları ve su depoları, klimalar.
func _apartment_c() -> void:
	var w := 3.2
	var d := 3.2
	var zf := d * 0.5
	var xf := w * 0.5
	var floors := 6
	box("facade_ochre", Vector3(0, FLOOR * floors * 0.5, 0), Vector3(w, FLOOR * floors, d))
	box("stone", Vector3(0, FLOOR * 0.5, 0), Vector3(w + 0.04, FLOOR, d + 0.04))
	french_door(zf + 0.02, -0.55, 0.0, 1.5, 1.05)
	door(zf + 0.02, 1.0, 0.42, 0.88)
	box("awning_terracotta", Vector3(-0.55, 1.15, zf + 0.25), Vector3(1.7, 0.05, 0.5), Vector3(deg_to_rad(12), 0, 0))
	for f in range(1, floors):
		var y := f * FLOOR
		# Çıkma (ortada, cepheden öne).
		box("facade_ochre", Vector3(-0.35, y + FLOOR * 0.5, zf + 0.15), Vector3(1.4, FLOOR, 0.3))
		window("z", zf + 0.3, -0.35, y + 0.75, 0.9, 0.62)
		band(-0.35, zf + 0.15, y + 0.02, 1.4, 0.3)
		french_door(zf, 1.05, y + 0.05, 0.45, 0.85)
		balcony(zf, 1.05, y, 0.8, 0.32)
		window("x", xf, -0.8, y + 0.75, 0.4, 0.55)
		window("x", xf, 0.4, y + 0.75, 0.4, 0.55)
		if f % 2 == 1:
			ac_unit(Vector3(xf + 0.08, y + 0.3, -0.2), "x")
	flat_roof(0, 0, FLOOR * floors, w, d, 0.2, "facade_ochre")
	for k in 2:
		solar_heater(Vector3(-0.8 + k * 0.9, FLOOR * floors + 0.04, -0.6))
	cyl("metal", Vector3(1.0, FLOOR * floors + 0.3, 0.5), 0.22, 0.5)
	box("facade_ochre", Vector3(-0.7, FLOOR * floors + 0.4, 0.7), Vector3(0.9, 0.8, 0.8))


## Villa A · Modern Akdeniz: L kütle, taş kaplama duvar, boy camlar, pergolalı teras, düz dam, küçük havuz.
func _villa_a() -> void:
	var w := 3.6
	var d := 3.2
	var zf := d * 0.5
	box("facade_white", Vector3(-0.6, FLOOR, -0.4), Vector3(2.4, FLOOR * 2, 2.4))
	box("stone", Vector3(1.0, FLOOR * 0.5, -0.4), Vector3(1.6, FLOOR, 2.4))
	french_door(0.8, -0.6, 0.0, 1.8, 1.1)
	french_door(0.8, -0.6, FLOOR + 0.05, 1.8, 0.9)
	balcony(0.8, -0.6, FLOOR, 2.2, 0.3, "glass")
	window("z", 0.8, 1.0, 0.75, 0.9, 0.55)
	window("x", 1.8, -0.4, 0.75, 1.2, 0.55)
	window("x", 0.6, -0.4, FLOOR + 0.75, 1.0, 0.6)
	flat_roof(-0.6, -0.4, FLOOR * 2, 2.4, 2.4, 0.15, "facade_white")
	flat_roof(1.0, -0.4, FLOOR, 1.6, 2.4, 0.12, "stone")
	pergola(Vector3(-0.6, 0, 1.25), 2.2, 0.85, 1.0)
	box("stone", Vector3(-0.6, 0.03, 1.25), Vector3(2.3, 0.06, 0.9))
	box("stone", Vector3(1.05, 0.06, 1.15), Vector3(1.4, 0.12, 0.8))
	box("water", Vector3(1.05, 0.125, 1.15), Vector3(1.24, 0.02, 0.64))
	box("rail", Vector3(1.45, 0.25, 0.85), Vector3(0.03, 0.3, 0.03))


## Villa B · Geleneksel Akdeniz: iki katlı ana kütle + tek katlı teraslı kanat, sütunlu revak, kırma kiremit çatı,
## babalı teras korkuluğu, taş bahçe duvarı ve kapı ayakları.
func _villa_b() -> void:
	var cx := -0.6
	var w := 2.8
	var d := 2.4
	var zf := d * 0.5 - 0.1
	var front := zf - 0.35
	box("facade", Vector3(cx, FLOOR, -0.1 - 0.175), Vector3(w, FLOOR * 2, d - 0.35))
	band(cx, -0.275, 0.1, w, d - 0.35, "stone", 0.2)
	# Revak: üç sütun + köşe ayağı, kiriş, kemer bantları.
	for i in 4:
		var x := cx - 1.3 + i * 0.866
		cyl("trim", Vector3(x, FLOOR * 0.45, zf - 0.08), 0.08, FLOOR * 0.9)
		box("stone", Vector3(x, 0.05, zf - 0.08), Vector3(0.22, 0.1, 0.22))
	box("trim", Vector3(cx, FLOOR - 0.05, zf - 0.08), Vector3(w, 0.18, 0.2))
	for i in 3:
		box("trim", Vector3(cx - 0.866 + i * 0.866, FLOOR - 0.2, zf - 0.08), Vector3(0.62, 0.12, 0.16))
	box("stone", Vector3(cx, 0.03, zf - 0.2), Vector3(w, 0.06, 0.42))
	door(front, cx, 0.46, 0.85, "wood", false)
	window("z", front, cx - 0.85, 0.7, 0.38, 0.5, "shutter_green")
	window("z", front, cx + 0.85, 0.7, 0.38, 0.5, "shutter_green")
	french_door(front, cx, FLOOR + 0.05, 0.6, 0.85)
	balcony(front, cx, FLOOR, 1.5, 0.42)
	window("z", front, cx - 0.95, FLOOR + 0.75, 0.38, 0.55, "shutter_green")
	window("z", front, cx + 0.95, FLOOR + 0.75, 0.38, 0.55, "shutter_green")
	window("x", cx - w * 0.5 - 0.0, -0.3, FLOOR + 0.75, 0.38, 0.55, "shutter_green")
	hip_roof(cx, -0.275, FLOOR * 2, w, d - 0.35, 0.95)
	chimney(cx - 0.8, -0.75, FLOOR * 2 + 0.3, 0.95)
	downpipe(cx + w * 0.5 + 0.05, zf - 0.3, FLOOR * 2)
	# Tek katlı kanat: kemerli pencereler, damda babalı korkuluklu teras, saksılar.
	var kx := 1.4
	var kw := 1.2
	box("facade", Vector3(kx, FLOOR * 0.5, -0.4), Vector3(kw, FLOOR, 1.9))
	band(kx, -0.4, 0.1, kw, 1.9, "stone", 0.2)
	window("z", 0.55, kx, 0.72, 0.5, 0.62, "shutter_green")
	box("trim", Vector3(kx, 1.08, 0.57), Vector3(0.6, 0.08, 0.05))
	window("x", kx + kw * 0.5, -0.4, 0.72, 0.5, 0.55, "shutter_green")
	box("stone_dark", Vector3(kx, FLOOR + 0.02, -0.4), Vector3(kw - 0.06, 0.04, 1.84))
	box("trim", Vector3(kx, FLOOR + 0.04, -0.4), Vector3(kw + 0.1, 0.06, 2.0))
	for s: float in [-1.0, 1.0]:
		box("trim", Vector3(kx, FLOOR + 0.35, -0.4 + s * 0.97), Vector3(kw + 0.06, 0.05, 0.08))
	box("trim", Vector3(kx + kw * 0.5 + 0.02, FLOOR + 0.35, -0.4), Vector3(0.08, 0.05, 2.0))
	for i in 7:
		box("trim", Vector3(kx - kw * 0.5 + 0.08 + i * (kw - 0.1) / 6.0, FLOOR + 0.2, 0.57), Vector3(0.06, 0.28, 0.06))
	for i in 12:
		box("trim", Vector3(kx + kw * 0.5 + 0.02, FLOOR + 0.2, -1.32 + i * 0.167), Vector3(0.06, 0.28, 0.06))
	planter(Vector3(kx - 0.2, FLOOR + 0.04, -0.9), 0.5)
	# Bahçe duvarı: alçak taş duvar, harpuşta, giriş ayakları (kapı açıklığı revağın önünde).
	var gz := d * 0.5 + 0.55
	for seg: Array in [[-2.0, cx - 0.45], [cx + 0.45, 2.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		box("stone", Vector3((a + b) * 0.5, 0.2, gz), Vector3(b - a, 0.4, 0.14))
		box("trim", Vector3((a + b) * 0.5, 0.42, gz), Vector3(b - a + 0.04, 0.05, 0.2))
	for s: float in [-1.0, 1.0]:
		box("stone", Vector3(cx + s * 0.5, 0.3, gz), Vector3(0.2, 0.6, 0.2))
		box("trim", Vector3(cx + s * 0.5, 0.63, gz), Vector3(0.26, 0.06, 0.26))
	box("stone_dark", Vector3(cx, 0.02, (zf + gz) * 0.5 + 0.05), Vector3(0.6, 0.04, gz - zf + 0.1))


## Ticari A · 3 kat: zeminde cam vitrin, giriş, tente, boş tabela bandı; üstte konut ve balkonlar, korniş.
func _commercial_a() -> void:
	var w := 3.2
	var d := 2.8
	var zf := d * 0.5
	var xf := w * 0.5
	var floors := 3
	box("facade", Vector3(0, FLOOR * floors * 0.5, 0), Vector3(w, FLOOR * floors, d))
	box("stone_dark", Vector3(0, FLOOR * 0.5, zf + 0.01), Vector3(w, FLOOR, 0.03))
	french_door(zf + 0.02, -0.35, 0.08, 1.9, 0.95)
	door(zf + 0.02, 1.15, 0.42, 0.88, "glass", false)
	box("trim", Vector3(-0.1, 1.17, zf + 0.04), Vector3(2.7, 0.18, 0.04))  # boş tabela bandı
	box("awning_teal", Vector3(-0.35, 1.0, zf + 0.3), Vector3(2.1, 0.04, 0.6), Vector3(deg_to_rad(18), 0, 0))
	for k in 6:
		box("trim" if k % 2 == 0 else "awning_teal", Vector3(-1.2 + k * 0.34, 0.86, zf + 0.58), Vector3(0.34, 0.1, 0.02))
	for f in range(1, floors):
		var y := f * FLOOR
		band(0, 0, y, w, d)
		for s: float in [-1.0, 1.0]:
			window("z", zf, s * 1.05, y + 0.78, 0.42, 0.55, "shutter_teal")
		french_door(zf, 0.0, y + 0.05, 0.5, 0.85)
		balcony(zf, 0.0, y, 1.0)
		window("x", xf, -0.5, y + 0.78, 0.4, 0.55)
		window("x", xf, 0.6, y + 0.78, 0.4, 0.55)
	window("x", xf, 0.0, 0.7, 1.4, 0.7)
	box("trim", Vector3(0, FLOOR * floors + 0.08, 0), Vector3(w + 0.16, 0.16, d + 0.16))
	flat_roof(0, 0, FLOOR * floors + 0.16, w, d, 0.1)
	ac_unit(Vector3(0.6, FLOOR * floors + 0.3, -0.5))


## Ticari B · Küçük ticari yapı: tek kat, köşe camlı vitrin, uzun saçak, damda boş tabela çerçevesi, önde saksılar.
func _commercial_b() -> void:
	var w := 3.2
	var d := 2.4
	var zf := d * 0.5
	var xf := w * 0.5
	var h := FLOOR * 1.25
	box("facade_white", Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	french_door(zf, -0.2, 0.0, 2.4, 1.3)
	box("interior", Vector3(xf - 0.004, 0.65, 0.35), Vector3(0.02, 1.3, 1.2))
	box("glass", Vector3(xf + 0.004, 0.65, 0.35), Vector3(0.01, 1.22, 1.12))
	box("frame", Vector3(xf + 0.012, 1.31, 0.35), Vector3(0.035, 0.045, 1.2))
	box("wood", Vector3(0, h + 0.05, zf + 0.35), Vector3(w + 0.3, 0.08, 0.8))
	for s: float in [-1.0, 1.0]:
		box("rail", Vector3(s * (xf + 0.05), h * 0.5, zf + 0.7), Vector3(0.05, h, 0.05))
	flat_roof(0, 0, h, w, d, 0.14, "facade_white")
	box("rail", Vector3(0, h + 0.5, 0.3), Vector3(2.2, 0.06, 0.06))
	for s: float in [-1.0, 1.0]:
		box("rail", Vector3(s * 1.05, h + 0.3, 0.3), Vector3(0.05, 0.45, 0.05))
	box("trim", Vector3(0, h + 0.38, 0.32), Vector3(2.1, 0.2, 0.03))
	for s: float in [-1.0, 1.0]:
		planter(Vector3(s * 1.1, 0, zf + 0.85), 0.5)


## Kamu A · Modern kamu yapısı: taş kaplamalı yan kütleler, ortada cam giydirme cephe, dikey güneş kırıcılar,
## konsol giriş saçağı, geniş basamaklar, bayrak direkleri.
func _public_a() -> void:
	var w := 4.0
	var d := 3.2
	var zf := d * 0.5
	var h := FLOOR * 2.3
	box("stone", Vector3(0, h * 0.5, -0.1), Vector3(w, h, d - 0.2))
	var front := zf - 0.2
	box("interior", Vector3(0, h * 0.5 + 0.1, front + 0.004), Vector3(2.2, h - 0.5, 0.02))
	box("glass", Vector3(0, h * 0.5 + 0.1, front + 0.012), Vector3(2.15, h - 0.55, 0.01))
	for i in 9:
		box("trim", Vector3(-1.05 + i * 0.2625, h * 0.5 + 0.1, front + 0.08), Vector3(0.05, h - 0.5, 0.14))
	for s: float in [-1.0, 1.0]:
		for f in 2:
			window("z", front, s * 1.55, 0.75 + f * 1.45, 0.5, 0.65)
	box("trim", Vector3(0, 1.0, front + 0.45), Vector3(2.6, 0.08, 0.9))
	for s: float in [-1.0, 1.0]:
		box("rail", Vector3(s * 1.15, 0.5, front + 0.85), Vector3(0.05, 1.0, 0.05))
	for k in 3:
		box("stone_dark", Vector3(0, 0.03 + k * 0.05, zf + 0.25 - k * 0.12), Vector3(2.8 - k * 0.2, 0.06, 0.3))
	window("x", w * 0.5, -0.4, 0.8, 1.4, 0.6)
	window("x", w * 0.5, -0.4, 2.2, 1.4, 0.6)
	flat_roof(0, -0.1, h, w, d - 0.2, 0.2, "stone")
	box("solar", Vector3(-0.8, h + 0.15, -0.4), Vector3(1.2, 0.04, 1.0), Vector3(deg_to_rad(-20), 0, 0))
	for s: float in [-1.0, 1.0]:
		cyl("metal", Vector3(s * 1.7, 1.4, zf + 0.35), 0.025, 2.8)
	box("awning_teal", Vector3(-1.7, 2.6, zf + 0.5), Vector3(0.02, 0.35, 0.5))
	box("awning_terracotta", Vector3(1.7, 2.6, zf + 0.5), Vector3(0.02, 0.35, 0.5))


## Kamu B · Sosyal tesis / okul: geniş yatay kütle, şerit pencereler, gölgelikli giriş revağı, yeşil çatı ve paneller.
func _public_b() -> void:
	var w := 4.2
	var d := 3.0
	var zf := d * 0.5
	var xf := w * 0.5
	box("facade", Vector3(0, FLOOR, 0), Vector3(w, FLOOR * 2, d))
	box("awning_terracotta", Vector3(-1.75, FLOOR, zf + 0.01), Vector3(0.7, FLOOR * 2, 0.03))
	for f in 2:
		var y := f * FLOOR
		for i in 5:
			window("z", zf, -1.0 + i * 0.6, y + 0.8, 0.52, 0.55)
		box("trim", Vector3(0.2, y + 1.15, zf + 0.12), Vector3(3.2, 0.04, 0.24))
		window("x", xf, -0.6, y + 0.8, 0.5, 0.55)
		window("x", xf, 0.4, y + 0.8, 0.5, 0.55)
	band(0, 0, FLOOR, w, d)
	# Giriş revağı: ince kolonlar ve gölgelik.
	box("trim", Vector3(-1.75, 1.1, zf + 0.5), Vector3(1.1, 0.07, 1.0))
	for s: float in [-1.0, 1.0]:
		box("rail", Vector3(-1.75 + s * 0.48, 0.55, zf + 0.92), Vector3(0.05, 1.1, 0.05))
	door(zf + 0.02, -1.75, 0.6, 0.85, "glass", false)
	flat_roof(0, 0, FLOOR * 2, w, d, 0.16)
	box("lawn", Vector3(-1.0, FLOOR * 2 + 0.07, 0), Vector3(1.9, 0.06, d - 0.3))
	for k in 3:
		box("solar", Vector3(1.0, FLOOR * 2 + 0.18, -0.9 + k * 0.85), Vector3(1.6, 0.04, 0.6), Vector3(deg_to_rad(-22), 0, 0))
	for s: float in [-1.0, 1.0]:
		planter(Vector3(-0.6 + s * 0.6, 0, zf + 0.25), 0.5)
