# ANTALYA 2040 · İklimin Geleceği

Antalya kıyısından esinlenen küçük bir Akdeniz şehrini 2040'tan 2052'ye yönettiğin 3D şehir kurma ve iklim simülasyonu oyunu. Sınırlı bütçeyle 12 sürdürülebilir yatırım arasından seçim yapar, önceden haber verilen kuraklık, sıcak hava dalgası ve kıyı taşkınına hazırlanır, kararlarının ekonomi, su, enerji, ekosistem ve emisyon üzerindeki sonuçlarını görürsün.

**Amaç:** İklim değişikliğinin yerel etkilerini (risk, uyum) ve azaltım kararlarını (emisyon) oynayarak öğretmek; şehir ölçeğindeki göreli emisyon ile küresel atmosferik CO₂'yi (ppm, NOAA ölçümü) birbirinden ayırmak.

## Temel mekanikler
- **Yıllık tur:** 2040–2052 (13 tur). Arsaya tıkla → yatırım seç → inşa et → "Yılı bitir" → yıl sonu raporu.
- **12 yatırım** (güneş, kamu verimliliği, su depolama, atık su geri kazanımı, park, serinleme merkezi, kent tarımı, gıda kurtarma, kompost, toplu taşıma, verimli konut, kıyı restorasyonu) ve **6 kombinasyon**.
- **Göstergeler:** bütçe, nüfus, su güvenliği, enerji, yaşam kalitesi, ekosistem, yerel emisyon; enerji/su üretim-tüketim, yenilenebilir payı.
- **Krizler:** bir yıl önce uyarı → hazırlık yılı → kriz → müdahale seçimi. Hasar = tehlike × maruziyet × hassasiyet × (1 − yatırım koruması) × müdahale.
- **İklim Laboratuvarı:** emisyonlar, küresel CO₂, kaynaklar, riskler, 17 kavramlık kaynaklı sözlük, öğrenme görevleri.
- **2052 final raporu:** 7 alt puan, 2040 ↔ 2052 karşılaştırması, grafikler, JSON dışa aktarma.

Oyundaki sayılar oyun dengeleme değerleridir; gerçek Antalya ölçümleri değildir.

## Çalıştırma
- **Godot:** 4.7.2 Stable Standard (C#/.NET değil). Projeyi Godot'ta `project.godot` ile açıp F5.
- **Windows demo:** `build/ANTALYA2040_Windows_Demo.zip` (repoya girmez; aşağıdaki komutla üretilir). Zip'i aç, `ANTALYA2040.exe`'ye çift tıkla. Kurulum ve internet gerekmez.
- Export: `<godot> --headless --path . --export-release "Windows Desktop" build/windows/ANTALYA2040.exe` (4.7.2 Windows export şablonları gerekir).

## Kontroller
| Tuş | İşlev |
|---|---|
| Sol tık | Arsa seç |
| Sağ tık / Esc | Seçimi bırak, paneli kapat |
| W A S D / ok tuşları | Kamerayı kaydır (ekran yönünde) |
| Tekerlek | Yakınlaş / uzaklaş |
| Orta tuş sürükle | Zemini tutup kamerayı kaydır |

Kamera açısı sabittir (izometrik görünüm); final sunumunda kamera kendiliğinden döner.

## Ana sistemler
| Sistem | Dosya | Ekip |
|---|---|---|
| Ortak sinyaller | `autoload/event_bus.gd` (sözleşme v1.9) | ortak |
| Oyun verisi | `autoload/game_state.gd`, `autoload/catalog.gd` | B |
| Kurallar ve tur | `scripts/sim/game_controller.gd`, `turn_manager.gd` | B |
| Hesaplar | `economy_simulator.gd`, `climate_simulator.gd`, `event_manager.gd`, `mission_tracker.gd`, `final_evaluator.gd` | B |
| Arayüz | `scripts/ui/` (HUD, BuildPanel, İklim Laboratuvarı, kriz paneli, raporlar) | B |
| 3D şehir, kamera, binalar, kriz görselleri | `scripts/world/`, `scenes/world/`, `scenes/buildings/` | A |
| Veri | `data/` (yatırımlar, krizler, kombinasyonlar, görevler, sözlük, CO₂) | B |

Belgeler: `docs/GAME_DESIGN.md`, `docs/INTEGRATION_CONTRACT.md`, `docs/FINAL_VISUAL_CONTRACT.md`, `docs/PROJECT_ARCHITECTURE.md`, `docs/PROGRESS.md`, `CHANGELOG.md`.

## Testler
Ekip B: `tests/` (headless: day1, day2, economy, crises, investments, final; pencereli: menu, e2e_game, ui, integration, education, playthrough), denge: `tests/balance_sim.gd`. Ekip A: `scripts/world/dev/test_*.gd`. Komutlar `CLAUDE.md`'de.

## Ekip
İki kişilik ekip, iki bilgisayar: Ekip A (3D şehir ve görseller), Ekip B (simülasyon, arayüz, entegrasyon). Harici model yok; küresel CO₂ verisi NOAA GML, bilgi kartı ve sözlük kaynakları kartlarda yazılı.
