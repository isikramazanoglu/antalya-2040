# ANTALYA 2040 · Final görsel entegrasyon sözleşmesi

Sürüm: **v1.0** (2026-10-31) · Ana sözleşmenin **v1.9** eklemesine dayanır (`docs/INTEGRATION_CONTRACT.md`).
Hazırlayan: Ekip B. Kullanan: Ekip A (2040 ↔ 2052 şehir sunumu, final kamera geçişleri, görsel dönüşüm).

**Durum (2026-10-31, Prompt 10C):** B tarafı tamam ve test edildi (`tests/test_final.gd`). A tarafı (10B) henüz develop'ta değil; FinalReport'taki "Şehrin dönüşümünü izle" düğmesi A dinlemeye başlayınca kendiliğinden görünecek.

Bu belgede "mevcut" diye geçen her sinyal, fonksiyon ve veri projede **bugün vardır** ve test edilmiştir (`tests/test_final.gd`). Henüz olmayanlar açıkça **"Ekip A tarafından geliştirilecek"** diye işaretlidir. Ekip A simülasyon koduna dokunmadan çalışabilir.

---

## A. Final şehir sunumunun başlatılması

| Adım | Ne olur | Kim | Durum |
|---|---|---|---|
| 1 | 2052 yıl sonu raporu kapanır (`report_closed`) | B · YearReport | mevcut |
| 2 | `TurnManager` fazı `&"game_over"` yapar, `EventBus.phase_changed(&"game_over")` ve `EventBus.game_over(summary)` yayar | B · TurnManager | mevcut |
| 3 | `FinalReport` paneli açılır (değerlendirme, karşılaştırma, grafikler) | B · FinalReport | mevcut |
| 4 | Panelde **"Şehrin dönüşümünü izle"** düğmesi yalnızca `EventBus.final_presentation_requested` sinyaline **en az bir dinleyici bağlıysa** görünür | B · FinalReport | mevcut |
| 5 | Oyuncu düğmeye basar → FinalReport gizlenir → `EventBus.final_presentation_requested(summary)` yayılır | B · FinalReport | mevcut |
| 6 | Ekip A sunumu oynatır (2040 → 2052 geçişi, kamera turu) | **A** | **Ekip A tarafından geliştirilecek** |
| 7 | Sunum bitince Ekip A `EventBus.final_presentation_finished.emit()` yayar → FinalReport geri gelir | **A** yayar, B dinler | sinyal mevcut, yayma **A tarafından geliştirilecek** |

**Yedek (mevcut):** A bitiş sinyalini hiç yaymazsa FinalReport 120 saniye sonra ya da oyuncu Esc'ye basınca kendiliğinden geri gelir; ana menüye dönüş her zaman mümkündür. A yine de bitişte sinyali yaymalıdır.

**Faz:** Sunum boyunca faz `&"game_over"` kalır. `end_turn_requested` ve `report_closed` bu fazda yok sayılır (test edildi). CityWorld zaten `phase_changed`'de `build` dışında arsa seçimini kapatıyor; sunum sırasında seçim açılmamalı.

---

## B. 2040 başlangıç şehri

- Oyun **binasız** başlar. `summary.city_2040.plots` her zaman doldurulur; bugün boş sözlüktür (`{}`), ileride başlangıç binası eklenirse dolar.
- Dekor (evler, zeytinlik, palmiyeler, marina, dağlar) Ekip A'nın `scripts/world/city_decor.gd` dosyasında **sabit seed** ile kurulur; 2040 ile 2052 arasında değişmez. Ayrı bir kayıt gerekmez.
- 2040 görüntüsünü yeniden göstermek için A, `city_2040.plots` dışındaki arsalardaki binaları geçici olarak gizler, sonra 2052 yerleşimine geri döner.
  - Önerilen A fonksiyonu: `CityWorld.show_city_state(plots: Dictionary, animate: bool) -> void` · **Ekip A tarafından geliştirilecek.**
  - Bu fonksiyon yalnızca görseli değiştirmeli; `GameState.plots`'a yazmamalı, `place_building` ile kalıcı bina eklememeli.

---

## C. 2052 final şehri

`summary.city_2052` (mevcut):
```
{
  "year": int,                              # 2052
  "plots": { plot_id: building_id },        # StringName → StringName, final yerleşim (GameState.plots kopyası)
  "builds": [                               # inşaat sırasıyla, her onaylanan yatırım bir kez
    { "plot_id": StringName, "building_id": StringName, "year": int, "cost": int }
  ]
}
```
- Bina bilgisi: `Catalog.get_building(building_id) -> BuildingDefinition` (mevcut, sözleşme §4): `display_name`, `category` (energy, water, heat, food, waste, transport, coast), `scene` (`scenes/buildings/b_<id>.tscn`), `icon`, `risk_reduction`.
- Aynı veri oyun sırasında da okunabilir (salt okunur): `GameState.plots`, `GameState.build_log`.
- "Hangi yıl ne yapıldı" sahnesi için `builds[].year` kullanılır (örnek: binaları inşa yılına göre sırayla göstermek).

---

## D. Kamera ve sahne geçişleri

Mevcut A fonksiyonları (A'nın kendi dosyası, B çağırmaz):

| Fonksiyon | Dosya | Durum |
|---|---|---|
| `CameraRig.focus_on(point: Vector3) -> void` | `scripts/world/camera_rig.gd` | mevcut |
| `CameraRig.bring_into_view(point: Vector3) -> void` | `scripts/world/camera_rig.gd` | mevcut |
| `CameraRig` @export: `bounds`, `zoom_min/max`, `rotate_limit_deg`, `safe_area`, `smoothing` | aynı | mevcut |
| `CityWorld.get_plots() -> Array[BuildPlot]`, `find_plot(plot_id) -> BuildPlot` | `scripts/world/city_world.gd` | mevcut |
| `BuildPlot.global_position`, `get_building() -> Node3D` | `scripts/world/build_plot.gd` | mevcut |
| Final kamera turu (ör. `CameraRig.play_tour(points: Array[Vector3], duration: float)`) | — | **Ekip A tarafından geliştirilecek** |

B kamera açısı ya da konumu belirlemez; sunum boyunca kamerayı yalnızca A yönetir. Sunum bitince A kamerayı oyuncunun son görünümüne (ya da açılış kadrajına) geri getirmelidir.

---

## E. Görsel efektler

**Oyun sırasında (mevcut, v1.5/v1.6):** `EventBus.crisis_stage_changed(event_id, stage, info)`; `info`: `severity`, `due_year`, `visual_effect_id` (`heat_haze`, `drought_dust`, `storm_surge`), `affected_area` (`city`, `farmland`, `coast`), `affected_plot_kinds`, `progress`, `mitigation` (0..0.8), `advantages` (koruma sağlayan bina kimlikleri). A bunu `DisasterFX.set_stage(stage, info)` ile kullanıyor (mevcut).

**Final sunumunda geçmiş krizleri göstermek için (mevcut veri):** `GameState.crisis_log` (salt okunur), her öğe:
```
{ "event_id", "response_id", "risk_type", "severity": float, "mitigation": float,
  "damage": { "<stat>": float }, "assessment": {...}, "summary_text": String, "year": int }
```
- Görsel bilgi için: `Catalog.get_event(event_id)` → `visual_effect_id`, `affected_area`, `affected_plot_kinds`.
- Koruma temsili: `mitigation` (0..0.8) ve `assessment.advantages` (bina kimlikleri). Kombinasyon bonusları `mitigation`'a dahildir, `advantages` listesinde yalnızca gerçek binalar vardır.
- Final "tekrar oynatma" için `info` sözlüğü crisis_log'dan kurulabilir; `progress` A'nın seçimidir. Kriz efektleri yalnızca görseldir, GameState'e yazmaz.

---

## F. Veri, sınıf ve sinyal özeti

**Sinyaller (EventBus, sözleşme v1.9):**

| Sinyal | Parametre | Yayan | Dinleyen | Durum |
|---|---|---|---|---|
| `game_over` | `summary: Dictionary` | B · TurnManager | B · FinalReport, A (isteğe bağlı) | mevcut |
| `phase_changed` | `phase: StringName` (`&"game_over"`) | B · TurnManager | A · CityWorld | mevcut |
| `final_presentation_requested` | `summary: Dictionary` | B · FinalReport | **A** | sinyal mevcut, dinleme **A tarafından geliştirilecek** |
| `final_presentation_finished` | yok | **A** | B · FinalReport | sinyal ve dinleme mevcut, yayma **A tarafından geliştirilecek** |
| `crisis_stage_changed` | `event_id, stage, info` | B · TurnManager | A | mevcut |

**`summary` (game_over ve final_presentation_requested, aynı sözlük):**

| Anahtar | Tip | Açıklama |
|---|---|---|
| `score`, `grade` | int, String | Genel oyun içi puan ve not |
| `evaluation` | Dictionary | `overall`, `grade`, `grade_text`, `dimensions[7]` (`id`, `title`, `score`, `weight`, `why`, `advice`), `best`, `worst`, `comparisons[10]`, `totals` |
| `start_stats`, `final_stats` | Dictionary | sözleşme §5.1 şekli; 2040 başı ve 2052 sonu |
| `history` | Array | her yıl sonunun `stats` kopyası (13 öğe) |
| `city_2040`, `city_2052` | Dictionary | bkz. B ve C |
| `emission_reduction_pct` | int | kişi başı emisyon azalması (%) |

**Salt okunur durum (oyun sırasında da):** `GameState.plots`, `GameState.build_log`, `GameState.crisis_log`, `GameState.history`, `GameState.year_reports`, `GameState.get_stats()`, `Catalog.get_building()`, `Catalog.get_event()`.

**Hata durumunda:**
- `summary` içinde beklenen anahtar yoksa (`summary.get("city_2052", {})` gibi) A sunumu atlamalı ve hemen `final_presentation_finished` yaymalı.
- `Catalog.get_building(id)` `null` dönerse o arsa sunumda boş geçilir, `push_warning` yazılır.
- Sunum bir hatayla yarıda kalırsa B'nin yedeği (Esc / 120 sn) raporu geri getirir.

---

## Ekip A için teslim

**Çekilecek dal:** `develop` (Prompt 10A PR'ı birleştikten sonra). Kendi dalına: `git switch feature/city-world`, `git pull`, `git merge origin/develop`.

**A'nın değiştirmesi serbest:** `scenes/world/**`, `scripts/world/**` (dev ve effects dahil), `scenes/buildings/**`, `assets/models/**`, `assets/materials/**`, `assets/shaders/**`, `assets/textures/**`, `assets/environment/**`, `docs/PROGRESS.md` içindeki A bölümü.

**A'nın dokunmaması gereken:** `autoload/**` (event_bus.gd yalnızca sözleşme süreciyle), `scripts/sim/**`, `scripts/ui/**`, `scripts/data/**`, `scenes/ui/**`, `scenes/main/**`, `data/**`, `tests/**`, `export_presets.cfg`, `project.godot`.

**Kabul ölçütleri (görsel entegrasyon tamam sayılması için):**
1. `final_presentation_requested`'a bağlanınca FinalReport'ta "Şehrin dönüşümünü izle" düğmesi görünür (B otomatik yapar).
2. Sunum 2040 görünümünü (binasız şehir) ve 2052 yerleşimini (`city_2052.plots`) gösterir; `GameState`'e yazmaz.
3. Sunum bitince `final_presentation_finished` yayılır ve kamera oyuncunun görünümüne döner.
4. Sunum 1280×720 ve 1920×1080'de çalışır; arayüzle çakışmaz.
5. B'nin testleri (özellikle `tests/test_final.gd`, `test_integration.gd`) A'nın değişiklikleriyle TAMAM kalır.
6. Eksik veride (ör. hiç yatırım yok) sunum çökmez.
