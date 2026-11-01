# Varlık kaynakları ve lisansları

Son güncelleme: 2026-11-01 (Ekip A, görsel revizyon 9 · araçlar; 8 · insan karakterleri; 7 · bina kütüphanesi).

## Özet

Tek harici varlık grubu **insan karakterleridir** (Quaternius, CC0; aşağıda). Bunun dışında bütün binalar, dekor ve
efektler proje içinde, Godot 4.7.2'nin yerleşik mesh'leri (BoxMesh, CylinderMesh, SphereMesh, PrismMesh, PlaneMesh,
CapsuleMesh) ve `SurfaceTool` ile kodla üretildi. Dokular Godot'nun `NoiseTexture2D` / `FastNoiseLite` kaynaklarıyla
çalışma anında üretiliyor; resim dosyası değiller. Gerçek marka, logo ya da işletme adı kullanılmadı; tabela alanları boş.

Lisans: bu varlıklar projenin kendi kodu ve çıktısıdır, projenin lisansına tabidir. Üçüncü taraf hakkı yoktur.

## Bina kütüphanesi (yalnızca dekor)

Üretici: `scripts/world/dev/gen_building_library.gd` (Godot `--script` aracı, Blender gerekmez).
Yeniden üretmek için:

```
<godot> --headless --path . --script res://scripts/world/dev/gen_building_library.gd
```

Modeller **yatırım değildir**: BuildingDefinition'a, yatırım kimliğine ya da arsa kimliğine bağlı değildir.
`scripts/world/city_decor.gd` mahalle dekoru olarak yerleştirir. Yatırım binaları ayrı sahnelerdir
(`scenes/buildings/b_*.tscn`, `scripts/world/dev/gen_buildings.py`).

| Dosya | Tür | Kaynak | Yazar | Lisans |
|---|---|---|---|---|
| `assets/buildings/residential/residential_house_a.tres` / `.tscn` | Klasik Akdeniz evi, 2 kat | Proje içinde üretildi (gen_building_library.gd) | Ekip A | Proje lisansı |
| `assets/buildings/residential/residential_house_b.tres` / `.tscn` | Modern Akdeniz evi, 2 kademe | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/residential/mediterranean_house_c.tres` / `.tscn` | Geleneksel Antalya evi (taş zemin, ahşap cumba) | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/apartments/apartment_midrise_a.tres` / `.tscn` | 4 katlı apartman | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/apartments/apartment_modern_b.tres` / `.tscn` | 5 katlı modern apartman | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/apartments/apartment_urban_c.tres` / `.tscn` | 6 katlı yoğun kent apartmanı | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/villas/villa_modern_a.tres` / `.tscn` | Modern villa (havuz, pergola) | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/villas/villa_mediterranean_b.tres` / `.tscn` | Geleneksel Akdeniz villası (revak, teras kanadı) | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/commercial/commercial_shop_a.tres` / `.tscn` | Zemin katı dükkânlı 3 katlı yapı | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/commercial/commercial_shop_b.tres` / `.tscn` | Küçük tek katlı ticari yapı | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/public/public_building_a.tres` / `.tscn` | Modern kamu yapısı | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/buildings/public/public_building_b.tres` / `.tscn` | Sosyal tesis / okul | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/materials/architecture/arch_*.tres` | Mimari palet (24 StandardMaterial3D) | Proje içinde üretildi | Ekip A | Proje lisansı |

## Araç kütüphanesi (görsel revizyon 9, proje içinde üretildi)

Üretici: `scripts/world/dev/gen_vehicle_library.gd` (Godot `--script`; Blender ya da harici model yok). Yeniden üretmek için:

```
<godot> --headless --path . --script res://scripts/world/dev/gen_vehicle_library.gd
```

Yalnızca görsel: araç sayısı bütçe, nüfus, enerji, emisyon ya da ulaşım kapasitesi üretmez.

| Dosya | Tür | Kaynak | Yazar | Lisans |
|---|---|---|---|---|
| `assets/vehicles/cars/city_car.tscn` (+ `_body.tres`) | Şehir arabası, 3,9 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/cars/sedan.tscn` | Sedan, 4,7 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/cars/compact_suv.tscn` | Kompakt SUV, 4,6 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/cars/electric_car.tscn` | Elektrikli otomobil, 4,8 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/buses/city_bus.tscn` | Belediye otobüsü, 11,1 m (marka / yazı yok) | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/buses/minibus.tscn` | Minibüs, 6,1 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/commercial/delivery_van.tscn` | Teslimat vanı, 5,3 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/bicycles/bicycle.tscn` | Şehir bisikleti, 1,9 m | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/wheels/wheel_*.tres` | Tekerlekler (araba, küçük, otobüs, bisiklet) | Proje içinde üretildi | Ekip A | Proje lisansı |
| `assets/vehicles/materials/veh_*.tres` | Araç paleti (17 materyal) | Proje içinde üretildi | Ekip A | Proje lisansı |

Değerlendirilip kullanılmayan: Kenney "Car Kit" 3.1 (CC0) — otobüs yok, renkler tek dokuya gömülü (prompt paletine
boyanamıyor) ve oranları oyuncak gibi; projeye eklenmedi.

## İnsan karakterleri (görsel revizyon 8, harici, CC0)

| Alan | Bilgi |
|---|---|
| Paket | Ultimate Animated Character Pack (Kasım 2019; glTF klasörü 31.10.2021) |
| Üretici | Quaternius (https://quaternius.com) |
| Kaynak | https://quaternius.com/packs/ultimatedanimatedcharacter.html → paketin resmî Google Drive klasörü, `glTF/` |
| Lisans | CC0 1.0 Universal (Public Domain Dedication) — https://creativecommons.org/publicdomain/zero/1.0/ |
| Atıf | Gerekli değil; nezaketen "LowPoly Models by @Quaternius" |
| Lisans metni | `assets/characters/pedestrians/License_Quaternius_Ultimate_Animated_Character_Pack.txt` (pakettekiyle aynı) |
| Erişim tarihi | 2026-11-01 |
| Değişiklik | `.gltf` (gömülü buffer) → `.glb` olarak paketlendi (geometri, iskelet, animasyon değişmedi); renkler oyunda materyal geçersiz kılmayla verilir (paketteki ten rengi glTF'de neredeyse siyah geliyordu) |

Kullanılan 12 model (`assets/characters/pedestrians/`): `qt_casual_male.glb`, `qt_casual_female.glb`,
`qt_casual2_male.glb`, `qt_casual2_female.glb`, `qt_casual3_male.glb`, `qt_casual3_female.glb`, `qt_casual_bald.glb`,
`qt_old_classy_male.glb`, `qt_old_classy_female.glb`, `qt_suit_male.glb`, `qt_suit_female.glb`,
`qt_doctor_female_young.glb`. Hepsinde 23 kemikli iskelet ve aynı 17 animasyon (Walk, Idle, SitDown, StandUp,
Walk_Carry, Run …). Oyunda Walk, Idle ve SitDown (son kare oturma pozu) kullanılır.

Değerlendirilip kullanılmayan: Kenney "Mini Characters" (CC0) — iskelet ve animasyonları uygundu, ancak oranları
çok "chibi" (baş boyun yarısı) olduğu için projeye eklenmedi.

## Diğer varlıklar

| Klasör | İçerik | Kaynak | Lisans |
|---|---|---|---|
| `scenes/buildings/b_*.tscn`, `assets/materials/buildings/` | 12 yatırım binası ve ortak bina paleti | `scripts/world/dev/gen_buildings.py` (proje içi) | Proje lisansı |
| `assets/materials/`, `assets/materials/city/`, `assets/materials/plot_*` | Zemin, yol, kaldırım, bitki, su materyalleri (gürültü dokuları çalışma anında) | Proje içi | Proje lisansı |
| `scripts/world/city_decor.gd` | Yollar, ağaçlar, insan figürleri, araçlar, marina, dağlar | Kodla üretilir (sahneye kaydedilmez) | Proje lisansı |
| `assets/models/` | Harici model yok (bkz. `assets/models/LICENSES.md`) | — | — |
| `scripts/world/pedestrians.gd` | Yaya rotaları, karakter renkleri, oturma yerleşimi | Proje içi kod | Proje lisansı |
| `scripts/world/traffic.gd`, `scripts/world/vehicle_library.gd` | Trafik rotaları, park etmiş araçlar, araç boyaları | Proje içi kod | Proje lisansı |

Arayüz varlıkları (`assets/ui/`, yazı tipleri, simgeler) Ekip B'nin sorumluluğundadır ve kaynakları B'nin
belgelerindedir.

## Kural

Harici bir varlık eklenirse önce bu tabloya satır eklenir: dosya, kaynak URL, yazar, lisans (ör. CC0, CC-BY 4.0),
erişim tarihi. Kaynağı veya lisansı doğrulanamayan varlık projeye eklenmez.
