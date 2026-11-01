# Varlık kaynakları ve lisansları

Son güncelleme: 2026-11-01 (Ekip A, görsel revizyon 7 · Akdeniz bina kütüphanesi).

## Özet

Projede **dışarıdan alınmış 3D model, doku ya da materyal yok**. Bütün binalar, dekor, insan figürleri ve efektler
proje içinde, Godot 4.7.2'nin yerleşik mesh'leri (BoxMesh, CylinderMesh, SphereMesh, PrismMesh, PlaneMesh,
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

## Diğer varlıklar

| Klasör | İçerik | Kaynak | Lisans |
|---|---|---|---|
| `scenes/buildings/b_*.tscn`, `assets/materials/buildings/` | 12 yatırım binası ve ortak bina paleti | `scripts/world/dev/gen_buildings.py` (proje içi) | Proje lisansı |
| `assets/materials/`, `assets/materials/city/`, `assets/materials/plot_*` | Zemin, yol, kaldırım, bitki, su materyalleri (gürültü dokuları çalışma anında) | Proje içi | Proje lisansı |
| `scripts/world/city_decor.gd` | Yollar, ağaçlar, insan figürleri, araçlar, marina, dağlar | Kodla üretilir (sahneye kaydedilmez) | Proje lisansı |
| `assets/models/` | Harici model yok (bkz. `assets/models/LICENSES.md`) | — | — |

Arayüz varlıkları (`assets/ui/`, yazı tipleri, simgeler) Ekip B'nin sorumluluğundadır ve kaynakları B'nin
belgelerindedir.

## Kural

Harici bir varlık eklenirse önce bu tabloya satır eklenir: dosya, kaynak URL, yazar, lisans (ör. CC0, CC-BY 4.0),
erişim tarihi. Kaynağı veya lisansı doğrulanamayan varlık projeye eklenmez.
