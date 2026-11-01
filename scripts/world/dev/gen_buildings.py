"""Sahip: A. 12 yatırımın bina sahnelerini ve ortak bina paletini üretir (Prompt 9B).

Çalıştırma (proje kökünde):  py scripts/world/dev/gen_buildings.py .
Yazdıkları: assets/materials/buildings/bld_*.tres, scenes/buildings/Building.tscn, scenes/buildings/b_<id>.tscn
Elle düzenleme yerine bu dosya değiştirilip yeniden çalıştırılır.

Ortak yerleşim standardı (her model için otomatik denetlenir, aşılırsa üretim durur):
- Pivot arsanın ortasında ve arsa zemininin üstünde (BuildPlot.BuildingAnchor, y = 0).
- Model, arsa kenarından en az EDGE_MARGIN içeride kalır (urban/coastal 6 m, open 8 m).
- Hiçbir parça zeminin PAD_EMBED'den fazla altına inmez (arsa zemininin kalınlığı); havada parça yok.
- Yükseklik sınıfları (HEIGHTS): altyapı < kamu < konut; işaret direkleri ayrı sınıf.
- Bina önü +z (kameraya bakan yüz). Sabit parçalar Model altında (oyun açılırken birleştirilir),
  kriz tepkileri ve yanıp sönen ışıklar Model/Live altında.
"""
import math
import os
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

EDGE_MARGIN = 0.2
PAD_EMBED = 0.12
HEIGHTS = {"ground": 3.2, "infra": 4.2, "public": 4.2, "housing": 5.2, "mast": 5.6}

# ---------------------------------------------------------------- palet
# Akdeniz: krem ve taş cepheler, terracotta, doğal yeşil, sönük turkuaz, ölçülü metal.
# Ortam ayarı doygunluğu %20 artırdığı için renkler bilerek biraz sönük seçildi.
PALETTE = {
    "bld_cream": dict(c=(0.93, 0.89, 0.8), r=0.9),
    "bld_stone": dict(c=(0.8, 0.74, 0.64), r=0.95),
    "bld_stone_dark": dict(c=(0.6, 0.56, 0.5), r=0.95),
    "bld_terracotta": dict(c=(0.74, 0.4, 0.27), r=0.85),
    "bld_turquoise": dict(c=(0.24, 0.58, 0.58), r=0.6),
    "bld_turquoise_light": dict(c=(0.62, 0.82, 0.8), r=0.8),
    "bld_green_accent": dict(c=(0.36, 0.52, 0.36), r=0.7),
    "bld_lawn": dict(c=(0.48, 0.6, 0.32), r=1.0),
    "bld_olive": dict(c=(0.4, 0.5, 0.27), r=0.9),
    "bld_cypress": dict(c=(0.24, 0.36, 0.22), r=0.9),
    "bld_shrub": dict(c=(0.33, 0.45, 0.25), r=0.95),
    "bld_crop": dict(c=(0.47, 0.62, 0.28), r=0.9),
    "bld_soil": dict(c=(0.45, 0.33, 0.22), r=1.0),
    "bld_soil_dark": dict(c=(0.32, 0.24, 0.17), r=1.0),
    "bld_sand": dict(c=(0.88, 0.8, 0.62), r=1.0),
    "bld_dune": dict(c=(0.66, 0.68, 0.42), r=1.0),
    "bld_wood": dict(c=(0.58, 0.42, 0.28), r=0.85),
    "bld_concrete": dict(c=(0.74, 0.73, 0.7), r=0.95),
    "bld_asphalt": dict(c=(0.27, 0.28, 0.3), r=0.9),
    "bld_metal": dict(c=(0.66, 0.68, 0.7), r=0.45, m=0.6),
    "bld_metal_dark": dict(c=(0.3, 0.32, 0.34), r=0.5, m=0.5),
    "bld_tank": dict(c=(0.9, 0.9, 0.87), r=0.5, m=0.1),
    "bld_glass": dict(c=(0.45, 0.62, 0.68), r=0.15, m=0.3),
    "bld_window": dict(c=(0.2, 0.27, 0.32), r=0.3),
    "bld_solar": dict(c=(0.13, 0.2, 0.34), r=0.3, m=0.5),
    "bld_water": dict(c=(0.25, 0.62, 0.66), r=0.1, m=0.2),
    "bld_bin_blue": dict(c=(0.27, 0.43, 0.62), r=0.7),
    "bld_bin_yellow": dict(c=(0.85, 0.7, 0.32), r=0.7),
    "bld_bin_green": dict(c=(0.36, 0.55, 0.32), r=0.7),
    "bld_fruit": dict(c=(0.86, 0.5, 0.25), r=0.8),
    "bld_greenhouse": dict(c=(0.82, 0.93, 0.92, 0.42), r=0.1, alpha=True),
    "bld_shade_net": dict(c=(0.62, 0.82, 0.8, 0.6), r=0.9, alpha=True),
    "bld_mist": dict(c=(0.86, 0.96, 1.0, 0.5), r=1.0, alpha=True, noshadow=True, e=(0.55, 0.85, 0.95), ee=0.6),
    "bld_glow_cool": dict(c=(0.6, 0.95, 1.0), r=0.5, e=(0.6, 0.95, 1.0), ee=1.6),
    "bld_glow_warn": dict(c=(1.0, 0.6, 0.25), r=0.5, e=(1.0, 0.55, 0.2), ee=2.0),
}
## Kuraklıkta hafifçe sararan bina bitkileri (DroughtEffect.building_materials).
VEGETATION = ["bld_lawn", "bld_olive", "bld_shrub", "bld_crop", "bld_dune"]


def fmt(v):
    v = float(v)
    if abs(v) < 1e-9:
        v = 0.0
    s = ("%.6f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def vec3(v):
    return "Vector3(%s)" % ", ".join(fmt(x) for x in v)


def color(c):
    c = list(c) + [1.0] * (4 - len(c))
    return "Color(%s)" % ", ".join(fmt(x) for x in c)


def write_palette():
    folder = os.path.join(ROOT, "assets/materials/buildings")
    os.makedirs(folder, exist_ok=True)
    for name, p in PALETTE.items():
        out = ['[gd_resource type="StandardMaterial3D" format=3]', "", "[resource]", 'resource_name = "%s"' % name]
        if p.get("alpha"):
            out.append("transparency = 1")
        if p.get("noshadow"):
            out.append("disable_receive_shadows = true")
        out.append("albedo_color = %s" % color(p["c"]))
        if "m" in p:
            out.append("metallic = %s" % fmt(p["m"]))
        out.append("roughness = %s" % fmt(p["r"]))
        if "e" in p:
            out += ["emission_enabled = true", "emission = %s" % color(p["e"]),
                    "emission_energy_multiplier = %s" % fmt(p["ee"])]
        with open(os.path.join(folder, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out) + "\n")


# ---------------------------------------------------------------- dönüşüm ve sahne yazımı

def basis(rot_deg):
    rx, ry, rz = (math.radians(a) for a in rot_deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    mul = lambda a, b: [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Ry, Rx), Rz)  # Godot varsayılan YXZ sırası


def tf(pos=(0, 0, 0), rot=(0, 0, 0)):
    b = basis(rot)
    rows = []
    for i in range(3):  # Godot metin biçimi: basis satır satır
        rows += b[i]
    return "Transform3D(%s)" % ", ".join(fmt(x) for x in rows + list(pos))


class Scene:
    def __init__(self):
        self.ext, self.ext_ids, self.subs, self.sub_cache, self.nodes = [], {}, [], {}, []

    def ext_res(self, type_, path):
        if path not in self.ext_ids:
            rid = "%d_%s" % (len(self.ext) + 1, os.path.splitext(os.path.basename(path))[0][:14])
            self.ext.append((type_, path, rid))
            self.ext_ids[path] = rid
        return 'ExtResource("%s")' % self.ext_ids[path]

    def mat(self, name):
        return self.ext_res("StandardMaterial3D", "res://assets/materials/buildings/%s.tres" % name)

    def sub(self, type_, props):
        key = (type_, tuple(props))
        if key not in self.sub_cache:
            sid = "%s_%d" % (type_, len(self.subs) + 1)
            self.subs.append((type_, sid, props))
            self.sub_cache[key] = sid
        return 'SubResource("%s")' % self.sub_cache[key]

    def node(self, header, props=()):
        self.nodes.append((header, list(props)))

    def write(self, rel):
        out = ["[gd_scene format=3]", ""]
        for type_, p, rid in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (type_, p, rid))
        if self.ext:
            out.append("")
        for type_, sid, props in self.subs:
            out.append('[sub_resource type="%s" id="%s"]' % (type_, sid))
            out += ["%s = %s" % kv for kv in props]
            out.append("")
        for header, props in self.nodes:
            out.append("[node %s]" % header)
            out += ["%s = %s" % kv for kv in props]
            out.append("")
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out).rstrip("\n") + "\n")


class Model:
    """Bir bina sahnesine parça ekler ve her parçanın kaba sınır kutusunu toplar."""

    def __init__(self, scene):
        self.s = scene
        self.parent = "Model"
        self.count = {}
        self.bounds = []  # (min, max, ad)
        self.groups = set()

    # --- kriz tepkisi grupları: Model/Live/Crisis_<risk_type> (başta gizli)
    def live(self, group=None):
        """Sonraki parçaları Model/Live (veya Model/Live/<group>) altına koyar; None ile Model'e döner."""
        if "Live" not in self.groups:
            self.s.node('name="Live" type="Node3D" parent="Model"')
            self.groups.add("Live")
        if group and group not in self.groups:
            props = [("visible", "false")] if group.startswith("Crisis_") else []
            self.s.node('name="%s" type="Node3D" parent="Model/Live"' % group, props)
            self.groups.add(group)
        self.parent = "Model/Live/%s" % group if group else "Model/Live"
        return self

    def static(self):
        self.parent = "Model"
        return self

    def _name(self, base):
        key = (self.parent, base)
        self.count[key] = self.count.get(key, 0) + 1
        n = self.count[key]
        return base if n == 1 else "%s%d" % (base, n)

    def _mesh(self, name, mesh, pos, rot, mat, half, shadow):
        props = [("transform", tf(pos, rot)), ("mesh", mesh), ("surface_material_override/0", self.s.mat(mat))]
        if not shadow or PALETTE[mat].get("noshadow"):
            props.append(("cast_shadow", "0"))
        node_name = self._name(name)
        self.s.node('name="%s" type="MeshInstance3D" parent="%s"' % (node_name, self.parent), props)
        b = basis(rot)
        ext = [sum(abs(b[i][j]) * half[j] for j in range(3)) for i in range(3)]
        self.bounds.append(([pos[i] - ext[i] for i in range(3)], [pos[i] + ext[i] for i in range(3)], node_name))

    def box(self, name, size, pos, mat, rot=(0, 0, 0), shadow=True):
        m = self.s.sub("BoxMesh", [("size", vec3(size))])
        self._mesh(name, m, pos, rot, mat, [v / 2 for v in size], shadow)

    def cyl(self, name, r, h, pos, mat, rot=(0, 0, 0), top=None, segs=12, shadow=True):
        top = r if top is None else top
        m = self.s.sub("CylinderMesh", [("top_radius", fmt(top)), ("bottom_radius", fmt(r)), ("height", fmt(h)),
                                        ("radial_segments", str(segs)), ("rings", "0")])
        rr = max(r, top)
        self._mesh(name, m, pos, rot, mat, [rr, h / 2, rr], shadow)

    def sphere(self, name, r, h, pos, mat, rot=(0, 0, 0), segs=8, rings=4, shadow=True):
        m = self.s.sub("SphereMesh", [("radius", fmt(r)), ("height", fmt(h)), ("radial_segments", str(segs)),
                                      ("rings", str(rings))])
        self._mesh(name, m, pos, rot, mat, [r, h / 2, r], shadow)

    def prism(self, name, size, pos, mat, rot=(0, 0, 0), shadow=True):
        m = self.s.sub("PrismMesh", [("size", vec3(size))])
        self._mesh(name, m, pos, rot, mat, [v / 2 for v in size], shadow)

    # --- ortak parçalar (aynı mesh tekrar kullanılır)
    def ground(self, mat, size):
        self.box("Ground", (size, 0.04, size), (0, 0.02, 0), mat, shadow=False)

    def olive_tree(self, x, z, s=1.0):
        self.cyl("Trunk", 0.1 * s, 0.9 * s, (x, 0.45 * s, z), "bld_wood", segs=6)
        self.sphere("Canopy", 0.72 * s, 1.1 * s, (x, 1.3 * s, z), "bld_olive")

    def cypress(self, x, z, s=1.0):
        self.cyl("CypressTrunk", 0.08 * s, 0.4 * s, (x, 0.2 * s, z), "bld_wood", segs=6)
        self.cyl("Cypress", 0.32 * s, 2.0 * s, (x, 1.3 * s, z), "bld_cypress", top=0.04 * s, segs=8)

    def shrub(self, x, z, r=0.35):
        self.sphere("Shrub", r, r * 1.3, (x, r * 0.55, z), "bld_shrub", segs=7, rings=3)

    def bench(self, x, z, along_x=True):
        size = (1.2, 0.1, 0.4) if along_x else (0.4, 0.1, 1.2)
        self.box("BenchSeat", size, (x, 0.42, z), "bld_wood")
        leg = (1.0, 0.36, 0.3) if along_x else (0.3, 0.36, 1.0)
        self.box("BenchBase", leg, (x, 0.19, z), "bld_stone")

    def window(self, x, y, z, w=0.6, h=0.7, facing="z"):
        size = (w, h, 0.04) if facing == "z" else (0.04, h, w)
        self.box("Window", size, (x, y, z), "bld_window")


# ---------------------------------------------------------------- 12 yatırım

def b_efficient_housing(m):
    """01 · Enerji verimli konut bölgesi: iki konut bloğu, balkon gölgelikleri, ahşap güneş kırıcılar, yeşil çatı."""
    m.ground("bld_stone", 5.4)
    # Blok A: 3 katlı, düz yeşil çatı, her katta derin balkon (gölgelik görevi görür).
    m.box("BlockA", (2.2, 4.2, 4.4), (-1.45, 2.1, -0.4), "bld_cream")
    for y in (1.4, 2.8):
        m.box("FloorBand", (2.26, 0.08, 4.46), (-1.45, y, -0.4), "bld_stone")
        m.box("Balcony", (2.0, 0.1, 0.55), (-1.45, y, 2.08), "bld_stone")
        m.box("BalconyRail", (2.0, 0.36, 0.04), (-1.45, y + 0.23, 2.34), "bld_glass")
    for y in (0.75, 2.1, 3.5):
        for x in (-2.05, -0.85):
            m.window(x, y, 1.83, w=0.65, h=0.75 if y > 1 else 0.7)
    m.box("Door", (0.5, 1.0, 0.04), (-1.45, 0.5, 1.83), "bld_turquoise")
    for z in (-1.6, -0.4, 0.8):
        m.window(-0.33, 2.1, z, w=0.7, h=0.75, facing="x")
        m.window(-0.33, 3.5, z, w=0.7, h=0.75, facing="x")
    m.box("Parapet", (2.3, 0.16, 4.5), (-1.45, 4.28, -0.4), "bld_stone")
    m.box("GreenRoof", (2.0, 0.12, 4.2), (-1.45, 4.42, -0.4), "bld_lawn")
    m.shrub(-1.9, -1.6, 0.28)
    m.shrub(-1.0, 0.5, 0.25)
    # Blok B: 2 katlı, terracotta kırma çatı, cephede dikey ahşap güneş kırıcılar.
    m.box("BlockB", (2.4, 2.8, 2.5), (1.4, 1.4, -1.25), "bld_cream")
    for y in (0.85, 2.05):
        for x in (0.85, 1.95):
            m.window(x, y, 0.02, w=0.55, h=0.65)
    for x in (0.35, 1.4, 2.45):
        m.box("Louver", (0.07, 2.5, 0.28), (x, 1.35, 0.14), "bld_wood")
    m.prism("RoofB", (2.7, 0.8, 2.8), (1.4, 3.2, -1.25), "bld_terracotta")
    # Ön bahçe ve yaya yolu.
    m.box("Garden", (2.4, 0.06, 2.0), (1.4, 0.03, 1.55), "bld_lawn", shadow=False)
    m.box("Path", (0.6, 0.07, 2.0), (0.0, 0.035, 1.6), "bld_stone_dark", shadow=False)
    m.olive_tree(1.0, 1.4, 0.8)
    m.olive_tree(2.2, 2.1, 0.65)
    m.shrub(2.3, 0.9, 0.3)


def b_solar_plant(m):
    """02 · Güneş enerjisi tesisi (mevcut model korundu): panel sıraları, taşıyıcılar, kablo kanalları, kontrol alanı."""
    m.ground("bld_concrete", 7.4)
    for z in (-2.7, -0.95, 0.8):
        m.box("Rail", (7.0, 0.08, 0.08), (0, 0.45, z), "bld_metal")
        for x in (-3.0, -1.0, 1.0, 3.0):
            m.box("Post", (0.08, 0.45, 0.08), (x, 0.225, z), "bld_metal")
        for x in (-2.6, -0.87, 0.87, 2.6):
            m.box("Panel", (1.65, 0.06, 1.2), (x, 0.75, z), "bld_solar", rot=(25, 0, 0))
            m.box("PanelFrame", (1.69, 0.04, 0.06), (x, 0.5, z + 0.56), "bld_metal", rot=(25, 0, 0))
    # Kablo kanalları: sıralardan kontrol alanına.
    m.box("CableTray", (0.14, 0.06, 4.6), (3.55, 0.03, -0.55), "bld_metal_dark", shadow=False)
    m.box("CableTray", (5.2, 0.06, 0.14), (0.95, 0.03, 1.85), "bld_metal_dark", shadow=False)
    # Kontrol alanı: kabin, inverterler, trafo ve çevresindeki çit.
    m.box("ControlCabin", (1.8, 1.3, 1.1), (-2.55, 0.65, 2.75), "bld_cream")
    m.box("CabinRoof", (1.95, 0.1, 1.25), (-2.55, 1.35, 2.75), "bld_metal_dark")
    m.box("CabinDoor", (0.45, 0.9, 0.04), (-2.95, 0.45, 3.31), "bld_turquoise")
    m.window(-2.2, 0.85, 3.31, w=0.6, h=0.4)
    for x in (-0.9, -0.3):
        m.box("Inverter", (0.45, 0.85, 0.4), (x, 0.425, 2.8), "bld_metal")
        m.box("InverterStripe", (0.46, 0.08, 0.41), (x, 0.7, 2.8), "bld_turquoise")
    m.box("Transformer", (1.0, 1.0, 0.8), (1.8, 0.5, 2.8), "bld_metal_dark")
    m.box("Fence", (2.0, 0.6, 0.04), (1.8, 0.3, 3.4), "bld_metal")
    m.box("Fence", (0.04, 0.6, 1.2), (0.8, 0.3, 2.8), "bld_metal")
    m.box("Fence", (0.04, 0.6, 1.2), (2.8, 0.3, 2.8), "bld_metal")


def b_public_efficiency(m):
    """03 · Kamu binalarında enerji verimliliği: belediye hizmet binası, güneş kırıcı cephe, çatıda panel + yeşil çatı."""
    m.ground("bld_stone", 5.4)
    m.box("Hall", (4.8, 3.2, 3.0), (0, 1.6, -1.0), "bld_cream")
    m.box("Glazing", (4.0, 1.1, 0.04), (0, 0.65, 0.52), "bld_glass")
    m.box("UpperWindows", (4.0, 0.9, 0.04), (0, 2.25, 0.52), "bld_window")
    for i in range(9):
        m.box("Fin", (0.08, 1.3, 0.45), (-2.0 + i * 0.5, 2.25, 0.75), "bld_stone")
    m.box("Overhang", (4.8, 0.12, 0.8), (0, 1.38, 0.9), "bld_stone")
    m.box("Sign", (1.6, 0.26, 0.04), (0, 3.0, 0.52), "bld_turquoise")
    m.box("Parapet", (5.0, 0.16, 3.2), (0, 3.28, -1.0), "bld_stone")
    for z in (-1.9, -0.8):
        m.box("RoofSolar", (1.9, 0.06, 0.9), (-1.2, 3.55, z), "bld_solar", rot=(20, 0, 0))
    m.box("GreenRoof", (1.8, 0.1, 2.4), (1.3, 3.41, -1.0), "bld_lawn")
    m.box("Steps", (2.2, 0.14, 0.6), (0, 0.07, 1.65), "bld_stone_dark")
    for x in (-2.0, 2.0):
        m.box("Planter", (0.9, 0.4, 0.9), (x, 0.2, 1.95), "bld_stone_dark")
        m.olive_tree(x, 1.95, 0.7)


def b_water_storage(m):
    """04 · Su depolama ve kaçak azaltma (mevcut model korundu): iki depo, seviye göstergesi, vanalı boru hattı, pompa evi."""
    m.ground("bld_concrete", 7.4)
    m.cyl("TankA", 1.5, 3.0, (-1.8, 1.5, -1.3), "bld_tank", segs=16)
    m.sphere("DomeA", 1.5, 0.8, (-1.8, 3.0, -1.3), "bld_tank", segs=16, rings=4)
    m.cyl("BandA", 1.52, 0.14, (-1.8, 2.2, -1.3), "bld_turquoise", segs=16)
    m.box("LevelGauge", (0.16, 2.2, 0.06), (-1.3, 1.4, 0.13), "bld_turquoise")
    m.box("Ladder", (0.3, 2.9, 0.05), (-2.6, 1.45, -0.03), "bld_metal", rot=(0, -30, 0))
    m.cyl("TankB", 1.15, 2.4, (1.9, 1.2, -1.7), "bld_tank", segs=16)
    m.sphere("DomeB", 1.15, 0.6, (1.9, 2.4, -1.7), "bld_tank", segs=16, rings=4)
    m.cyl("BandB", 1.17, 0.14, (1.9, 1.8, -1.7), "bld_turquoise", segs=16)
    # Ana boru hattı ve vanalar (kaçak kontrolü).
    m.cyl("Manifold", 0.12, 6.4, (0.0, 0.35, 0.75), "bld_metal", rot=(0, 0, 90), segs=8)
    m.cyl("Riser", 0.12, 1.3, (-1.8, 0.35, 0.15), "bld_metal", rot=(90, 0, 0), segs=8)
    m.cyl("Riser", 0.12, 1.5, (1.9, 0.35, -0.1), "bld_metal", rot=(90, 0, 0), segs=8)
    for x in (-2.6, 0.0, 2.6):
        m.cyl("Valve", 0.2, 0.06, (x, 0.62, 0.75), "bld_turquoise", segs=10)
        m.cyl("ValveStem", 0.04, 0.2, (x, 0.5, 0.75), "bld_metal_dark", segs=6)
    # Pompa evi (taş + terracotta), sayaç ve bakım alanı.
    m.box("PumpHouse", (2.0, 1.4, 1.6), (-1.6, 0.7, 2.5), "bld_stone")
    m.prism("PumpRoof", (1.9, 0.6, 2.3), (-1.6, 1.7, 2.5), "bld_terracotta", rot=(0, 90, 0))
    m.box("PumpDoor", (0.5, 0.9, 0.04), (-1.6, 0.45, 3.31), "bld_turquoise")
    m.box("MeterCabinet", (0.6, 0.9, 0.4), (1.2, 0.45, 2.3), "bld_metal")
    m.box("MeterScreen", (0.4, 0.25, 0.02), (1.2, 0.65, 2.51), "bld_window")
    m.box("ServicePad", (1.8, 0.04, 1.2), (2.4, 0.04, 2.6), "bld_stone_dark", shadow=False)
    # Kuraklıkta: göstergede "aktif dağıtım" ışığı.
    m.live("Crisis_drought").box("GaugeGlow", (0.12, 1.2, 0.04), (-1.3, 0.95, 0.17), "bld_glow_cool")
    m.static()


def b_water_reuse(m):
    """05 · Atık su geri kazanım: dikdörtgen çökeltme havuzları, kanal, filtre üniteleri, sazlık arıtma, kontrol binası."""
    m.ground("bld_concrete", 5.4)
    for x in (-1.3, 1.3):
        m.box("Basin", (2.3, 0.44, 1.7), (x, 0.22, -1.75), "bld_concrete")
        m.box("BasinWater", (2.1, 0.04, 1.5), (x, 0.46, -1.75), "bld_water", shadow=False)
        m.box("Scraper", (0.12, 0.12, 1.8), (x, 0.58, -1.75), "bld_metal_dark")
    m.box("Channel", (5.0, 0.26, 0.5), (0, 0.13, -0.45), "bld_concrete")
    m.box("ChannelWater", (4.8, 0.04, 0.34), (0, 0.28, -0.45), "bld_water", shadow=False)
    for x in (-2.15, -1.45, -0.75):
        m.cyl("Filter", 0.3, 1.4, (x, 0.7, 0.55), "bld_tank", segs=10)
        m.cyl("FilterCap", 0.32, 0.12, (x, 1.46, 0.55), "bld_turquoise", segs=10)
    m.cyl("FilterPipe", 0.08, 2.0, (-1.45, 1.1, 0.95), "bld_metal", rot=(0, 0, 90), segs=6)
    # Sazlık (yapay sulak alan): son arıtma basamağı.
    m.box("ReedBed", (2.2, 0.18, 1.7), (1.4, 0.09, 1.0), "bld_soil_dark")
    for i, (x, z) in enumerate(((0.65, 0.5), (1.15, 0.85), (1.7, 0.45), (2.15, 0.95), (0.8, 1.45),
                                (1.4, 1.35), (1.95, 1.6), (1.3, 0.2))):
        m.cyl("Reed", 0.13, 0.6 + 0.1 * (i % 3), (x, 0.5, z), "bld_crop", top=0.0, segs=5)
    # Kontrol binası (düz çatı, turkuaz saçak).
    m.box("Control", (1.8, 1.3, 1.1), (-1.5, 0.65, 1.95), "bld_cream")
    m.box("ControlRoof", (2.0, 0.12, 1.3), (-1.5, 1.36, 1.95), "bld_stone")
    m.box("ControlBand", (1.82, 0.12, 1.12), (-1.5, 1.2, 1.95), "bld_turquoise")
    m.window(-1.15, 0.8, 2.52, w=0.8, h=0.4)
    m.box("ControlDoor", (0.4, 0.85, 0.04), (-2.05, 0.43, 2.52), "bld_metal_dark")


def b_green_park(m):
    """06 · Yeşil park ve gölgelendirme (mevcut model korundu): çim, yollar, çeşme, iki ağaç türü, pergola, çiçeklikler."""
    m.ground("bld_lawn", 5.6)
    m.box("PathX", (5.6, 0.06, 0.8), (0, 0.045, 0), "bld_stone", shadow=False)
    m.box("PathZ", (0.8, 0.06, 5.6), (0, 0.045, 0), "bld_stone", shadow=False)
    m.cyl("Fountain", 0.95, 0.35, (0, 0.18, 0), "bld_stone", segs=14)
    m.cyl("FountainWater", 0.8, 0.04, (0, 0.36, 0), "bld_water", segs=14)
    m.cyl("Spout", 0.12, 0.7, (0, 0.5, 0), "bld_stone", segs=8)
    m.olive_tree(1.9, -1.9, 1.0)
    m.olive_tree(-1.9, 1.9, 0.9)
    m.olive_tree(1.95, 1.75, 1.05)
    m.cypress(2.35, -0.9, 0.9)
    m.cypress(-0.95, -2.35, 0.85)
    for x, z, r in ((1.0, -1.0, 0.3), (-1.0, 1.0, 0.28), (2.4, 0.95, 0.3), (-2.4, 0.9, 0.26)):
        m.shrub(x, z, r)
    m.bench(1.3, 0.75)
    m.bench(-0.75, 1.3, along_x=False)
    # Pergola: ahşap direkler ve çıtalar, altında bank.
    for x in (-2.6, -1.0):
        for z in (-2.5, -1.1):
            m.box("PergolaPost", (0.1, 2.1, 0.1), (x, 1.05, z), "bld_wood")
    for i in range(6):
        m.box("PergolaSlat", (1.8, 0.06, 0.1), (-1.8, 2.15, -2.55 + i * 0.29), "bld_wood")
    m.box("ShadeSail", (1.7, 0.03, 1.5), (-1.8, 2.22, -1.8), "bld_turquoise_light")
    m.bench(-1.8, -1.8)
    for x, z in ((0.9, 2.3), (-2.25, -0.7)):
        m.box("FlowerBed", (0.9, 0.25, 0.5), (x, 0.125, z), "bld_terracotta")
        m.box("Flowers", (0.8, 0.12, 0.4), (x, 0.29, z), "bld_fruit")
    # Sıcakta: çeşmeden serinletici su sisi.
    m.live("Crisis_heat").cyl("Spray", 0.55, 1.4, (0, 1.4, 0), "bld_mist", top=0.08, segs=10)
    m.static()


def b_cooling_center(m):
    """07 · İklim serinleme merkezi: geniş konsol gölge çatı, cam salon, çatıda ısı pompaları, su oyun alanı, ağaçlar."""
    m.ground("bld_stone", 5.4)
    m.box("Hall", (3.8, 2.3, 2.1), (0, 1.15, -1.55), "bld_cream")
    m.box("GlassFront", (3.2, 1.6, 0.04), (0, 0.85, -0.48), "bld_glass")
    m.box("Door", (0.8, 1.4, 0.05), (0, 0.7, -0.45), "bld_window")
    m.box("Sign", (1.4, 0.2, 0.04), (0, 1.95, -0.48), "bld_turquoise")
    m.box("Roof", (5.1, 0.18, 3.6), (0, 2.45, -0.95), "bld_cream")
    m.box("RoofEdge", (5.1, 0.12, 0.08), (0, 2.42, 0.86), "bld_stone")
    for x in (-2.3, 2.3):
        m.cyl("Column", 0.08, 2.36, (x, 1.18, 0.6), "bld_metal", segs=8)
    for x in (-1.2, 0.2):
        m.box("HeatPump", (0.8, 0.45, 0.6), (x, 2.77, -1.8), "bld_metal")
        m.cyl("Fan", 0.22, 0.04, (x, 3.01, -1.8), "bld_metal_dark", segs=10)
    m.box("RoofSolar", (1.2, 0.05, 0.9), (1.6, 2.65, -1.8), "bld_solar", rot=(15, 0, 0))
    # Gölgede dinlenme alanı.
    m.bench(-1.2, 0.2)
    m.bench(1.2, 0.2)
    m.cyl("WaterPoint", 0.15, 0.9, (2.1, 0.45, -0.1), "bld_turquoise", segs=8)
    # Önde su oyun alanı ve iki ağaç.
    m.box("SplashPad", (2.2, 0.1, 1.2), (0, 0.05, 1.9), "bld_stone_dark")
    m.box("SplashWater", (2.0, 0.03, 1.0), (0, 0.115, 1.9), "bld_water", shadow=False)
    m.olive_tree(-2.05, 1.95, 0.85)
    m.olive_tree(2.05, 1.95, 0.85)
    # Sıcakta: çatı saçağından su sisi ve yanan tabela.
    m.live("Crisis_heat")
    for x in (-1.6, 0.0, 1.6):
        m.cyl("Mist", 0.5, 1.4, (x, 1.65, 0.6), "bld_mist", top=0.06, segs=10)
    m.box("SignGlow", (1.4, 0.2, 0.04), (0, 1.95, -0.44), "bld_glow_cool")
    m.static()


def b_urban_farming(m):
    """08 · İklime dayanıklı kent tarımı: cam sera, yükseltilmiş yataklar, damla sulama, yağmur suyu deposu."""
    m.ground("bld_soil", 7.4)
    # Sera: şeffaf cam, metal çerçeve, içinde üretim sıraları.
    m.box("Greenhouse", (3.0, 1.6, 4.6), (1.9, 0.8, -1.2), "bld_greenhouse", shadow=False)
    m.prism("GreenhouseRoof", (3.0, 0.9, 4.6), (1.9, 2.05, -1.2), "bld_greenhouse", shadow=False)
    m.box("Ridge", (0.08, 0.08, 4.64), (1.9, 2.5, -1.2), "bld_metal")
    for z in (-3.45, -2.3, -1.2, -0.1, 1.05):
        m.box("Frame", (3.04, 0.06, 0.06), (1.9, 1.6, z), "bld_metal")
        for x in (0.42, 3.38):
            m.box("FramePost", (0.06, 1.6, 0.06), (x, 0.8, z), "bld_metal")
    for z in (-2.9, -2.0, -1.1, -0.2, 0.6):
        m.box("GreenhouseRow", (2.4, 0.35, 0.45), (1.9, 0.18, z), "bld_crop")
    # Açık tarla: dört yükseltilmiş yatak, farklı ürün biçimleri.
    for i, x in enumerate((-3.0, -2.05, -1.1)):
        m.box("Bed", (0.75, 0.25, 6.0), (x, 0.125, -0.4), "bld_wood")
        m.box("BedSoil", (0.63, 0.04, 5.88), (x, 0.27, -0.4), "bld_soil_dark", shadow=False)
        m.box("Drip", (0.04, 0.04, 5.9), (x + 0.25, 0.31, -0.4), "bld_turquoise", shadow=False)
        for j in range(6):
            z = -2.9 + j * 1.0
            if i == 1:
                m.cyl("Crop", 0.2, 0.6, (x, 0.58, z), "bld_crop", top=0.02, segs=6)
            else:
                m.sphere("Crop", 0.28, 0.4, (x, 0.42, z), "bld_crop", segs=6, rings=3)
    m.box("Path", (0.5, 0.05, 6.0), (-0.35, 0.05, -0.4), "bld_stone", shadow=False)
    # Ön: yağmur suyu deposu, pompa, ürün kasaları.
    m.cyl("RainTank", 0.55, 1.4, (2.9, 0.7, 2.8), "bld_turquoise", segs=12)
    m.cyl("RainTankLid", 0.58, 0.1, (2.9, 1.45, 2.8), "bld_metal", segs=12)
    m.box("Pump", (0.5, 0.45, 0.45), (2.0, 0.225, 2.9), "bld_metal")
    m.cyl("PumpPipe", 0.06, 1.7, (2.0, 0.35, 2.05), "bld_metal", rot=(90, 0, 0), segs=6)
    for x in (0.6, 1.05):
        m.box("Crate", (0.4, 0.3, 0.4), (x, 0.15, 3.0), "bld_wood")
        m.sphere("Produce", 0.16, 0.18, (x, 0.32, 3.0), "bld_fruit", segs=6, rings=3)
    # Kuraklıkta: yatakların üstüne gölge filesi gerilir (buharlaşmayı azaltır).
    m.live("Crisis_drought")
    m.box("ShadeNet", (3.1, 0.03, 6.2), (-2.05, 1.5, -0.4), "bld_shade_net", shadow=False)
    for x in (-3.5, -0.6):
        for z in (-3.4, 2.6):
            m.box("NetPost", (0.06, 1.5, 0.06), (x, 0.75, z), "bld_metal")
    m.static()


def b_food_rescue(m):
    """09 · Gıda kurtarma merkezi: düz çatılı lojistik deposu, yükleme rampası, soğuk oda, elektrikli dağıtım aracı."""
    m.ground("bld_concrete", 5.4)
    m.box("Depot", (4.6, 2.4, 2.6), (0, 1.2, -1.35), "bld_cream")
    m.box("Parapet", (4.7, 0.14, 2.7), (0, 2.45, -1.35), "bld_stone")
    m.box("FacadeBand", (4.64, 0.14, 2.64), (0, 2.28, -1.35), "bld_green_accent")
    for x in (-1.0, 0.8):
        m.box("Skylight", (0.9, 0.16, 1.6), (x, 2.48, -1.4), "bld_glass")
    m.box("ColdRoom", (1.0, 0.5, 0.8), (1.7, 2.7, -1.9), "bld_metal")
    m.cyl("ColdFan", 0.2, 0.04, (1.7, 2.97, -1.9), "bld_metal_dark", segs=10)
    # Ofis girişi ve tabela.
    m.window(-1.75, 1.4, -0.03, w=1.0, h=0.6)
    m.box("OfficeDoor", (0.6, 1.1, 0.04), (-1.75, 0.55, -0.03), "bld_glass")
    m.box("Sign", (1.4, 0.3, 0.04), (-1.6, 2.05, -0.03), "bld_green_accent")
    # Yükleme rampası: iki sarmal kapı ve saçak.
    m.box("Dock", (3.0, 0.5, 0.8), (0.75, 0.25, 0.4), "bld_stone_dark")
    for x in (0.1, 1.45):
        m.box("RollerDoor", (1.05, 1.4, 0.04), (x, 1.2, -0.03), "bld_metal")
        for y in (0.75, 1.1, 1.45, 1.8):
            m.box("DoorRib", (1.05, 0.03, 0.02), (x, y, 0.0), "bld_metal_dark")
    m.box("DockCanopy", (3.4, 0.08, 1.1), (0.75, 2.12, 0.5), "bld_green_accent")
    # Elektrikli dağıtım aracı.
    m.box("VanBody", (2.0, 1.0, 1.0), (0.75, 0.68, 1.95), "bld_cream")
    m.box("VanCab", (0.6, 0.7, 0.98), (-0.55, 0.53, 1.95), "bld_cream")
    m.box("VanWindshield", (0.04, 0.35, 0.8), (-0.86, 0.68, 1.95), "bld_window")
    m.box("VanStripe", (2.02, 0.16, 1.02), (0.75, 0.6, 1.95), "bld_green_accent")
    for x in (-0.45, 1.3):
        m.cyl("Wheel", 0.2, 1.06, (x, 0.2, 1.95), "bld_asphalt", rot=(90, 0, 0), segs=10)
    # Palet üstünde ürün kasaları.
    m.box("Pallet", (0.9, 0.1, 0.9), (-1.85, 0.05, 1.55), "bld_wood")
    for x, z in ((-2.05, 1.35), (-1.65, 1.35), (-2.05, 1.75), (-1.65, 1.75)):
        m.box("Crate", (0.38, 0.28, 0.38), (x, 0.24, z), "bld_wood")
        m.sphere("Produce", 0.15, 0.16, (x, 0.42, z), "bld_fruit" if x < -1.8 else "bld_crop", segs=6, rings=3)


def b_recycling_compost(m):
    """10 · Geri dönüşüm ve kompost: ayrıştırma binası, malzeme bölmeleri, kompost sıraları, toplama konteynerleri, çit."""
    m.ground("bld_concrete", 7.4)
    m.box("SortingHall", (3.6, 2.4, 2.6), (-1.7, 1.2, -2.2), "bld_cream")
    m.box("HallRoof", (3.8, 0.12, 2.8), (-1.7, 2.5, -2.2), "bld_metal_dark", rot=(0, 0, 5))
    m.box("HallDoor", (1.6, 1.7, 0.04), (-2.1, 0.85, -0.88), "bld_metal")
    m.window(-0.55, 1.6, -0.88, w=0.8, h=0.5)
    m.box("Sign", (1.2, 0.26, 0.04), (-1.7, 2.1, -0.88), "bld_green_accent")
    for x in (-2.5, -1.4):
        m.box("RoofSolar", (0.9, 0.05, 2.2), (x, 2.68, -2.2), "bld_solar", rot=(0, 0, 5))
    # Ayrıştırılmış malzeme bölmeleri (üç kenarı beton duvar).
    m.box("BayBack", (3.2, 0.9, 0.2), (2.0, 0.45, -3.4), "bld_concrete")
    for x in (0.5, 1.5, 2.5, 3.5):
        m.box("BayWall", (0.16, 0.9, 1.4), (x, 0.45, -2.8), "bld_concrete")
    for x, mat in ((1.0, "bld_bin_blue"), (2.0, "bld_bin_yellow"), (3.0, "bld_bin_green")):
        m.sphere("Material", 0.42, 0.5, (x, 0.2, -2.85), mat, segs=7, rings=3)
    # Kompost sıraları (uzun, düzenli; biri samanla örtülü).
    for x, mat in ((-3.0, "bld_soil"), (-1.85, "bld_soil_dark"), (-0.7, "bld_sand")):
        m.prism("Windrow", (0.95, 0.65, 3.4), (x, 0.33, 1.3), mat)
    # Toplama konteynerleri.
    for x, mat in ((1.0, "bld_bin_blue"), (1.8, "bld_bin_yellow"), (2.6, "bld_bin_green"), (3.3, "bld_bin_blue")):
        m.box("Bin", (0.6, 0.8, 0.6), (x, 0.4, 0.4), mat)
        m.box("BinLid", (0.64, 0.06, 0.64), (x, 0.83, 0.4), "bld_metal_dark")
    m.box("Hedge", (4.0, 0.5, 0.35), (-1.5, 0.25, 3.45), "bld_shrub")
    m.olive_tree(2.1, 2.4, 0.8)
    m.olive_tree(3.2, 3.1, 0.7)


def b_transit_hub(m):
    """11 · Düşük emisyonlu toplu taşıma merkezi: kanatlı turkuaz çatılı peron, e-otobüs ve şarj direği, yeşil tramvay hattı."""
    # Arka: çimli tramvay hattı.
    m.box("TramBed", (5.6, 0.04, 1.2), (0, 0.02, -2.1), "bld_lawn", shadow=False)
    for z in (-2.4, -1.8):
        m.box("Rail", (5.6, 0.05, 0.08), (0, 0.065, z), "bld_metal")
    # Orta: peron, kanatlı çatı, cam rüzgârlık, bekleme alanı.
    m.box("Platform", (5.4, 0.25, 1.9), (0, 0.125, -0.3), "bld_stone")
    for x in (-1.8, 1.8):
        m.cyl("Column", 0.1, 2.4, (x, 1.45, -0.3), "bld_metal", segs=8)
    m.box("WingN", (5.6, 0.1, 1.15), (0, 2.68, -0.82), "bld_turquoise", rot=(-9, 0, 0))
    m.box("WingS", (5.6, 0.1, 1.15), (0, 2.68, 0.22), "bld_turquoise", rot=(9, 0, 0))
    m.box("RoofSolar", (2.4, 0.04, 0.9), (-1.3, 2.81, -0.82), "bld_solar", rot=(-9, 0, 0))
    m.box("RoofSolar", (2.4, 0.04, 0.9), (1.3, 2.81, -0.82), "bld_solar", rot=(-9, 0, 0))
    m.box("WindScreen", (4.6, 1.3, 0.04), (0, 0.9, -1.15), "bld_glass")
    m.bench(-0.9, -0.75)
    m.bench(0.9, -0.75)
    m.box("InfoPylon", (0.3, 1.8, 0.25), (2.45, 1.15, 0.2), "bld_metal_dark")
    m.box("InfoScreen", (0.24, 0.6, 0.02), (2.45, 1.5, 0.33), "bld_glow_cool")
    # Ön: otobüs şeridi, elektrikli otobüs ve pantograf şarj direği.
    m.box("BusLane", (5.6, 0.03, 1.8), (0, 0.015, 1.75), "bld_asphalt", shadow=False)
    m.box("LaneMark", (5.4, 0.02, 0.08), (0, 0.04, 2.6), "bld_cream", shadow=False)
    m.box("Bus", (4.2, 1.25, 1.15), (-0.45, 0.82, 1.7), "bld_cream")
    m.box("BusWindows", (4.22, 0.42, 1.17), (-0.45, 1.08, 1.7), "bld_window")
    m.box("BusStripe", (4.22, 0.14, 1.17), (-0.45, 0.55, 1.7), "bld_turquoise")
    m.box("BusRoofPack", (1.6, 0.16, 0.8), (0.4, 1.52, 1.7), "bld_metal")
    for x in (-1.9, 1.0):
        m.cyl("Wheel", 0.24, 1.2, (x, 0.24, 1.7), "bld_asphalt", rot=(90, 0, 0), segs=10)
    m.box("ChargerMast", (0.16, 3.0, 0.16), (2.4, 1.5, 2.55), "bld_metal")
    m.box("ChargerArm", (0.12, 0.12, 0.95), (2.4, 2.95, 2.1), "bld_metal")
    m.box("Pantograph", (0.7, 0.06, 0.4), (2.4, 2.85, 1.7), "bld_metal_dark")
    m.box("ChargerCabinet", (0.5, 1.0, 0.35), (2.4, 0.5, 2.25), "bld_metal")


def b_coastal_restoration(m):
    """12 · Kıyı ekosistemi ve erken uyarı: bitkili kumul sırtları, ahşap iskele, taş tahkimat, izleme istasyonu, uyarı direği, seviye ölçer."""
    m.ground("bld_sand", 5.6)
    for z, w in ((-1.4, 5.0), (0.3, 4.4)):
        m.prism("Dune", (1.3, 0.6, w), (-0.3, 0.3, z), "bld_dune", rot=(0, 90, 0))  # sırt x boyunca
    m.box("DuneSoil", (4.6, 0.05, 1.0), (-0.3, 0.03, -1.4), "bld_shrub", shadow=False)
    for i, (x, z) in enumerate(((-2.2, -1.2), (-1.5, -1.6), (-0.6, -1.25), (0.3, -1.55), (1.2, -1.3),
                                (-1.9, 0.45), (-1.0, 0.2), (-0.1, 0.5), (0.8, 0.25), (-2.6, -0.5))):
        m.cyl("DuneGrass", 0.17, 0.5 + 0.08 * (i % 3), (x, 0.55, z), "bld_crop", top=0.0, segs=5)
    for x, z in ((-2.3, 1.3), (0.6, 1.25), (-1.2, -2.3)):
        m.shrub(x, z, 0.3)
    # Ahşap iskele kumulların üstünden denize iner.
    m.box("Boardwalk", (0.8, 0.1, 5.0), (1.75, 0.72, -0.2), "bld_wood")
    for z in (-2.4, -1.0, 0.4, 1.8):
        for x in (1.42, 2.08):
            m.box("BoardPost", (0.08, 0.7, 0.08), (x, 0.35, z), "bld_wood")
    # Deniz tarafında taş tahkimat.
    for i, x in enumerate((-2.3, -1.4, -0.5, 0.4, 1.3, 2.25)):
        m.sphere("Rock", 0.45, 0.55, (x, 0.18, 2.05 - 0.1 * (i % 2)), "bld_stone_dark", rot=(0, i * 37, 0),
                 segs=6, rings=3)
    # İzleme istasyonu.
    m.box("Station", (1.2, 1.0, 1.0), (-1.95, 0.5, -2.2), "bld_cream")
    m.box("StationRoof", (1.35, 0.1, 1.15), (-1.95, 1.05, -2.2), "bld_turquoise")
    m.window(-1.95, 0.6, -1.68, w=0.6, h=0.35)
    m.cyl("Antenna", 0.03, 1.2, (-1.5, 1.7, -2.4), "bld_metal", segs=6)
    m.sphere("SensorDome", 0.16, 0.2, (-2.3, 1.2, -2.4), "bld_tank", segs=8, rings=3)
    # Erken uyarı direği: siren, güneş paneli ve yanıp sönen ışık (Live/Beacon).
    m.box("Mast", (0.18, 4.6, 0.18), (1.2, 2.3, -2.3), "bld_metal")
    for y in (1.2, 2.4, 3.6):
        m.box("MastBrace", (0.5, 0.05, 0.05), (1.2, y, -2.3), "bld_metal", rot=(0, 0, 35))
    m.box("Siren", (0.5, 0.4, 0.5), (1.2, 4.5, -2.3), "bld_turquoise")
    m.box("MastSolar", (0.8, 0.05, 0.6), (1.2, 3.9, -2.0), "bld_solar", rot=(35, 0, 0))
    # Su seviyesi ölçer: deniz tarafında renk bantlı direk.
    m.box("GaugePost", (0.14, 1.6, 0.14), (-2.35, 0.8, 1.75), "bld_metal")
    for y, mat in ((0.4, "bld_tank"), (0.8, "bld_turquoise"), (1.2, "bld_terracotta")):
        m.box("GaugeBand", (0.2, 0.3, 0.2), (-2.35, y, 1.75), mat)
    m.live().sphere("Beacon", 0.2, 0.4, (1.2, 4.95, -2.3), "bld_glow_warn", segs=8, rings=4)
    # Taşkında: seviye ölçerin üst bandı yanar.
    m.live("Crisis_coastal_flood").box("GaugeGlow", (0.22, 0.32, 0.22), (-2.35, 1.2, 1.75), "bld_glow_warn")
    m.static()


# id: (fonksiyon, arsa kenarı, yükseklik sınıfı) · arsa kenarı en küçük izinli arsadır (sözleşme §7, §8)
BUILDINGS = {
    "efficient_housing": (b_efficient_housing, 6, "housing"),
    "solar_plant": (b_solar_plant, 8, "infra"),
    "public_efficiency": (b_public_efficiency, 6, "public"),
    "water_storage": (b_water_storage, 8, "infra"),
    "water_reuse": (b_water_reuse, 6, "infra"),
    "green_park": (b_green_park, 6, "ground"),
    "cooling_center": (b_cooling_center, 6, "public"),
    "urban_farming": (b_urban_farming, 8, "ground"),
    "food_rescue": (b_food_rescue, 6, "public"),
    "recycling_compost": (b_recycling_compost, 8, "infra"),
    "transit_hub": (b_transit_hub, 6, "public"),
    "coastal_restoration": (b_coastal_restoration, 6, "mast"),
}


def check(bid, m, footprint, height_class):
    """Ortak yerleşim standardı. Hata listesi ve özet döndürür."""
    errors = []
    limit = footprint / 2 - EDGE_MARGIN
    lo = [min(b[0][i] for b in m.bounds) for i in range(3)]
    hi = [max(b[1][i] for b in m.bounds) for i in range(3)]
    for mn, mx, name in m.bounds:
        if mn[0] < -limit - 1e-6 or mx[0] > limit + 1e-6 or mn[2] < -limit - 1e-6 or mx[2] > limit + 1e-6:
            errors.append("%s arsa sınırını aşıyor (x %.2f..%.2f, z %.2f..%.2f, sınır ±%.2f)" % (
                name, mn[0], mx[0], mn[2], mx[2], limit))
        if mn[1] < -PAD_EMBED - 1e-6:
            errors.append("%s zeminin %.2f altına iniyor" % (name, -mn[1]))
    if hi[1] > HEIGHTS[height_class] + 1e-6:
        errors.append("yükseklik %.2f > %s sınıfı %.2f" % (hi[1], height_class, HEIGHTS[height_class]))
    if lo[1] > 0.06:
        errors.append("model havada (en alt nokta %.2f)" % lo[1])
    summary = "%-20s arsa %dm  x %.1f..%.1f  z %.1f..%.1f  y %.2f..%.2f (%s)  %d parça" % (
        bid, footprint, lo[0], hi[0], lo[2], hi[2], lo[1], hi[1], height_class, len(m.bounds))
    return errors, summary


def gen_buildings():
    s = Scene()
    script = s.ext_res("Script", "res://scripts/world/building.gd")
    s.node('name="Building" type="Node3D"', [("script", script)])
    s.node('name="Model" type="Node3D" parent="."')
    s.write("scenes/buildings/Building.tscn")
    failed = False
    for bid, (fn, footprint, height_class) in BUILDINGS.items():
        s = Scene()
        base = s.ext_res("PackedScene", "res://scenes/buildings/Building.tscn")
        s.node('name="b_%s" instance=%s' % (bid, base), [
            ("building_id", '&"%s"' % bid), ("footprint", fmt(float(footprint)) + ".0"),
            ("height_class", '&"%s"' % height_class)])
        m = Model(s)
        fn(m)
        errors, summary = check(bid, m, footprint, height_class)
        print(summary)
        for e in errors:
            print("   HATA:", e)
        failed = failed or bool(errors)
        s.write("scenes/buildings/b_%s.tscn" % bid)
    return not failed


if __name__ == "__main__":
    write_palette()
    ok = gen_buildings()
    print("ok" if ok else "STANDART DIŞI MODEL VAR")
    sys.exit(0 if ok else 1)
