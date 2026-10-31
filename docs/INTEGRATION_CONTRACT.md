# ANTALYA 2040 · Entegrasyon sözleşmesi

Bu belge Ekip A (şehir ve 3D) ile Ekip B (simülasyon ve arayüz) arasındaki tek resmi arayüzdür.
İki taraf birbirinin koduna yalnızca burada yazan sinyaller, fonksiyonlar ve veri şekilleri üzerinden dokunur.
Burada yazmayan bir şeye güvenen kod, sözleşme dışıdır.

Sürüm: **v1.7** (2026-10-31). Her değişiklikte sürümü artırın ve en alttaki değişiklik günlüğüne satır ekleyin.

---

## 1. Temel kurallar

1. Ekipler arası iletişim **yalnızca `EventBus` autoload'u** üzerinden yapılır. Ekip A, Ekip B'nin node'larına `get_node()` ile erişmez; tersi de geçerli.
2. Ekip A'nın okuyabileceği tek Ekip B servisi `Catalog.get_building(id)` fonksiyonudur (bina sahnesini bulmak için).
3. Oyun durumunu (`GameState`) yalnızca `GameController` değiştirir. Diğer herkes ya sinyal dinler ya da salt okunur getter çağırır.
4. Kimlikler (`plot_id`, `building_id`, `event_id`, `response_id`, `risk_type`, `phase`, `reason`) her zaman `StringName` olarak yazılır: `&"solar_plant"`.
5. Hackathon boyunca sözleşme **yalnızca eklemeyle** büyür. Var olan sinyalin adı, parametre sırası veya parametre tipi değiştirilmez, silinmez. Yeni ihtiyaç varsa yeni sinyal eklenir.
6. Sinyal parametresi olarak gelen `Dictionary` ve `Array` değerleri **değiştirilmez** (salt okunur kabul edilir). Gönderen taraf kopya gönderir.

---

## 2. Autoload listesi

`project.godot` içinde bu sırayla tanımlanır. Sıra önemlidir: sonraki autoload öncekini kullanabilir.

| Sıra | Ad | Dosya | Sahip | Görev |
|---|---|---|---|---|
| 1 | `EventBus` | `res://autoload/event_bus.gd` | ORTAK | Yalnızca sinyal tanımları. Değişken, fonksiyon, mantık yok. |
| 2 | `Catalog` | `res://autoload/catalog.gd` | B | `res://data/catalog.tres` dosyasını yükler, tanımlara erişim verir. |
| 3 | `GameState` | `res://autoload/game_state.gd` | B | Oyun verisinin tek kaynağı. Mantık içermez. |

---

## 3. EventBus sinyalleri (tam liste)

"Yayan" sütunundaki node dışında hiçbir node bu sinyali `emit` etmez.

### 3.1 Arsa ve inşaat

| Sinyal | Parametreler | Yayan | Dinleyen |
|---|---|---|---|
| `plot_selected` | `plot_id: StringName, plot_kind: StringName, is_empty: bool` | A · `CityWorld` | B · `BuildPanel` |
| `plot_deselected` | yok | A · `CityWorld` | B · `BuildPanel` |
| `build_requested` | `plot_id: StringName, building_id: StringName` | B · `BuildPanel` | B · `GameController` |
| `build_approved` | `plot_id: StringName, building_id: StringName` | B · `GameController` | A · `CityWorld`, B · `BuildPanel`, `HUD` |
| `build_rejected` | `plot_id: StringName, building_id: StringName, reason: StringName` | B · `GameController` | B · `BuildPanel` |
| `plot_deselect_requested` (v1.3) | yok | B · `BuildPanel` (kapat düğmesi, Esc) | A · `CityWorld` → seçimi bırakır ve `plot_deselected` yayar |

`reason` değerleri: `&"not_enough_credits"`, `&"plot_occupied"`, `&"wrong_plot_kind"`, `&"max_count_reached"`, `&"wrong_phase"`, `&"unknown_building"`, v1.4: `&"scene_unavailable"` (bina sahnesi yüklenemiyor), `&"unknown_plot"` (bu oturumda `plot_selected` ile bildirilmemiş arsa).

### 3.2 Durum ve tur

| Sinyal | Parametreler | Yayan | Dinleyen |
|---|---|---|---|
| `stats_changed` | `stats: Dictionary` (şekil §5.1) | B · `GameState` | B · `HUD`, `ClimateLab` |
| `phase_changed` | `phase: StringName` | B · `TurnManager` | A · `CityWorld`, B · tüm UI |
| `end_turn_requested` | yok | B · `HUD` | B · `GameController` |
| `year_started` | `year: int` | B · `TurnManager` | A · `CityWorld` (isteğe bağlı), B · `HUD` |
| `year_ended` | `report: Dictionary` (şekil §5.4) | B · `TurnManager` | B · `YearReport` |
| `report_closed` | yok | B · `YearReport` | B · `GameController` |
| `game_over` | `summary: Dictionary` (şekil §5.5) | B · `TurnManager` | B · `YearReport` (final ekranı) |

`phase` değerleri:

| Değer | Anlamı | Şehirde tıklama |
|---|---|---|
| `&"build"` | Oyuncu inşa edebilir, yılı bitirebilir. | Açık |
| `&"crisis"` | Kriz paneli açık, müdahale bekleniyor. | Kapalı |
| `&"report"` | Yıl sonu raporu açık. | Kapalı |
| `&"game_over"` | Oyun bitti. | Kapalı |

Ekip A, `phase_changed` ile gelen değer `&"build"` değilse arsa seçimini kapatır ve seçili arsa varsa `plot_deselected` yayar.

### 3.3 Kriz

| Sinyal | Parametreler | Yayan | Dinleyen |
|---|---|---|---|
| `crisis_warned` | `warning: Dictionary` (şekil §5.2) | B · `TurnManager` | B · `HUD` |
| `crisis_started` | `event_id: StringName, risk_type: StringName, severity: float` | B · `TurnManager` | A · `CityWorld` (görsel efekt), B · `EventPanel` |
| `crisis_response_chosen` | `event_id: StringName, response_id: StringName` | B · `EventPanel` | B · `GameController` |
| `crisis_resolved` | `result: Dictionary` (şekil §5.3) | B · `TurnManager` | A · `CityWorld` (efekti bitir), B · `EventPanel` |
| `crisis_stage_changed` (v1.5) | `event_id: StringName, stage: StringName, info: Dictionary` (şekil §5.6) | B · `TurnManager` | A · `CityWorld` (isteğe bağlı: aşamaya göre görsel) |

`stage` değerleri (v1.5), sırayla: `&"warning"` (yıl N sonu, `crisis_warned` ile aynı an) → `&"preparation"` (yıl N+1 başı) → `&"active"` (yıl N+1 sonu, `crisis_started`'dan hemen önce) → `&"resolved"` (`crisis_resolved`'dan hemen sonra) → `&"ended"` (rapor kapanınca). Mevcut `crisis_started` / `crisis_resolved` aynen yayılmaya devam eder; A yeni sinyali kullanmak zorunda değildir.

`risk_type` değerleri: `&"drought"` (kuraklık), `&"heat"` (aşırı sıcak), `&"coastal_flood"` (kıyı taşkını).
`severity`: 0.0 ile 1.0 arası. Ekip A bunu efekt şiddeti için kullanır (ör. su seviyesi yüksekliği).

---

## 4. Ekipler arası fonksiyonlar

Sözleşmedeki fonksiyonlar bunlardan ibarettir.

| Fonksiyon | Dönüş | Sahip | Kim çağırır |
|---|---|---|---|
| `Catalog.get_building(id: StringName)` | `BuildingDefinition` veya `null` | B | A · `CityWorld`, B |
| `Catalog.buildings_for_plot_kind(kind: StringName)` | `Array[BuildingDefinition]` | B | B · `BuildPanel` |
| `Catalog.get_event(id: StringName)` | `EventDefinition` veya `null` | B | B |
| `GameState.get_stats()` | `Dictionary` kopyası (§5.1) | B | herkes (salt okunur) |
| `GameState.get_building_on(plot_id: StringName)` | `StringName` (boşsa `&""`) | B | herkes (salt okunur) |

Ekip A bina sahnesini şöyle bulur: `Catalog.get_building(building_id).scene` (`PackedScene`). `scene` boşsa veya tanım `null` ise A yer tutucu bir kutu gösterir ve `push_warning` yazar. Oyun çökmez.

---

## 5. Veri şekilleri

Sözlük anahtarları düz `String` olarak yazılır (`"credits"`), `StringName` değil. Kimlik değerleri ise `StringName`'dir.

### 5.1 `stats`

```
{
  "year": int,                    # 2040..2052
  "credits": int,
  "population": int,
  "water_security": float,        # 0..100
  "energy_security": float,       # 0..100
  "quality_of_life": float,       # 0..100
  "ecosystem_health": float,      # 0..100
  "emissions_total": float,       # oyun birimi, yıllık
  "emissions_by_sector": { "energy": float, "transport": float, "buildings": float, "waste": float },
  "risks": { "drought": float, "heat": float, "coastal_flood": float },   # 0..100
  "global_co2_ppm": float,        # kaynak tablodan; veri yoksa -1.0
  # v1.2 kaynak akışları (oyun birimi, bilgi amaçlı; endekslerden ayrı)
  "energy_demand": float,
  "renewable_energy": float,
  "renewable_share": float,       # 0..1
  "water_demand": float,
  "water_supply": float
}
```

### 5.2 `warning`

```
{ "event_id": StringName, "risk_type": StringName, "due_year": int, "severity": float }
```

### 5.3 `result` (kriz sonucu)

```
{
  "event_id": StringName,
  "response_id": StringName,
  "risk_type": StringName,
  "mitigation": float,            # 0..0.8, yatırımlardan gelen koruma oranı
  "damage": { "<stat_adı>": float },   # uygulanan değişimler, ör. {"credits": -120, "water_security": -8}
  "summary_text": String,         # rapora yazılacak tek cümle
  "severity": float,              # v1.5: tehlike şiddeti 0.2..1 (yatırımdan bağımsız ham risk)
  "assessment": Dictionary        # v1.5: {"hazard", "exposure", "vulnerability", "mitigation": float, "advantages": Array[StringName]}
}
```

### 5.6 `info` (crisis_stage_changed, v1.5)

```
{
  "severity": float,              # 0.2..1
  "due_year": int,
  "visual_effect_id": StringName, # heat_haze, drought_dust, storm_surge
  "affected_area": StringName,    # city, farmland, coast
  "affected_plot_kinds": Array,   # ör. [&"coastal"]; A bunu arsa kimliklerine çevirebilir
  "progress": float,              # warning 0.0, preparation 0.25, active 0.5, resolved 0.75, ended 1.0
  "mitigation": float,            # v1.6: o risk için yatırımların koruma oranı 0..0.8 (aşama anındaki binalardan)
  "advantages": Array             # v1.6: koruma sağlayan building_id listesi (StringName)
}
```
Bütün aşamalarda bu sekiz anahtarın hepsi vardır. `mitigation` ve `advantages` aşama anındaki binalardan hesaplanır; örneğin uyarı ile kriz arasında park yapılırsa `active` aşamasında artar.

### 5.4 `report` (yıl sonu)

```
{
  "year": int,
  "stats_before": Dictionary,     # §5.1
  "stats_after": Dictionary,      # §5.1
  "income": int,
  "upkeep": int,
  "built_this_year": Array,       # building_id listesi
  "crisis_results": Array,        # §5.3 listesi
  "new_warnings": Array,          # §5.2 listesi
  "missions": { "completed": Array, "failed": Array, "reward": int }   # v1.1
}
```

### 5.5 `summary` (oyun sonu)

```
{ "final_stats": Dictionary, "history": Array, "score": int, "grade": String, "emission_reduction_pct": int, "start_stats": Dictionary }   # emission_reduction_pct: v1.1, start_stats: v1.7
```

`history`: her yıl sonunun `stats` kopyası (ClimateLab grafikleri de bunu kullanır).

---

## 6. Akışlar

### 6.1 Arsa seçimi

1. Oyuncu şehirde tıklar. `CityWorld._unhandled_input` kameradan ışın atar, `plots` fizik katmanında bir `BuildPlot` bulursa onu vurgular.
2. `CityWorld` → `EventBus.plot_selected(plot_id, plot_kind, is_empty)`.
3. Boş yere veya sağ tık → `EventBus.plot_deselected()`.
4. Arayüz paneli üstündeki tıklamalar dünyaya inmez: panellerin `mouse_filter` değeri `STOP`, dünya ise `_unhandled_input` kullanır.

### 6.2 Bina seçimi ve yatırım talebi

1. `BuildPanel` `plot_selected` alır. `is_empty` yanlışsa arsadaki binanın bilgisini gösterir.
2. Boşsa `Catalog.buildings_for_plot_kind(plot_kind)` ile kartları listeler. Parası yetmeyen kart gri görünür ama tıklanabilir (ret mesajını görmek eğiticidir).
3. Oyuncu "İnşa et" der → `EventBus.build_requested(plot_id, building_id)`.

### 6.3 Bütçe kontrolü ve inşaat onayı

`GameController` sırayla kontrol eder; ilk başarısız kontrolde `build_rejected` yayar ve durur:

1. `phase == &"build"` mi? Değilse `wrong_phase`.
2. Tanım var mı? Yoksa `unknown_building`.
2a. (v1.4) Tanımın `scene` alanı yüklenebilir mi? Değilse `scene_unavailable`.
2b. (v1.4) Arsa `plot_selected` ile bildirilmiş mi? Değilse `unknown_plot`.
3. Arsa boş mu (`GameState.get_building_on`)? Değilse `plot_occupied`.
4. `plot_kind` izinli mi? Değilse `wrong_plot_kind`. (Plot türünü `plot_selected` anında `GameController` de dinleyip saklar.)
5. Bu binadan `max_count` kadar var mı? Varsa `max_count_reached`.
6. `credits >= cost` mu? Değilse `not_enough_credits`.

Hepsi geçerse: krediyi düşer, binayı `GameState`'e yazar, `on_build_effects` uygular, sonra `EventBus.build_approved(plot_id, building_id)` yayar. `GameState` de `stats_changed` yayar.

### 6.4 Şehirde bina oluşturma

1. `CityWorld` `build_approved` alır, `plot_id` ile `BuildPlot`'u bulur.
2. `Catalog.get_building(building_id).scene` örneklenir, `BuildPlot/BuildingAnchor` altına eklenir.
3. Bina kısa bir büyüme animasyonu oynatır (Tween). Bu tamamen A'nın içidir; B beklemez.

### 6.5 Yıllık tur geçişi

1. `HUD` "Yılı bitir" → `end_turn_requested`. `GameController` bunu `TurnManager.end_year()` çağrısına çevirir.
2. Bu yıl için zamanı gelmiş kriz varsa §6.6'ya gider, kriz çözülünce buradan devam eder.
3. Ekonomi adımı: gelir, işletme gideri, nüfus.
4. İklim adımı: sektör emisyonları, riskler, ekosistem, küresel CO2 değeri.
5. Uyarı adımı: gelecek yıllar için yeni krizler planlanır, her biri için `crisis_warned`.
6. Rapor hazırlanır → `phase_changed(&"report")` → `year_ended(report)`.
7. Oyuncu raporu kapatır → `report_closed`.
8. Yıl artar. Yıl 2052'yi geçtiyse `phase_changed(&"game_over")` ve `game_over(summary)`. Değilse `phase_changed(&"build")` ve `year_started(year)`.

### 6.6 Kriz uyarısı ve müdahalesi

Kriz zaman çizelgesi (yıllık tur ile):

| Zaman | Ne olur | Sinyal |
|---|---|---|
| Yıl N sonu | Risk uyarısı | `crisis_warned` (`due_year = N + lead_years`) |
| Yıl N+1 boyunca | Hazırlık: oyuncu koruyucu yatırım yapabilir | yok |
| Yıl N+1 sonu, ekonomi adımından önce | Kriz başlar | `phase_changed(&"crisis")`, `crisis_started` |
| Oyuncu seçer | Müdahale | `crisis_response_chosen` |
| Hemen ardından | Hasar hesabı ve uygulama | `crisis_resolved(result)` |
| Tur devam eder | Yıl sonu raporunda kriz bölümü | `year_ended` |

Aynı yıl birden fazla kriz gelirse sırayla işlenir; her biri kendi `crisis_started` / `crisis_resolved` çiftini alır.

### 6.7 Yıl sonu raporu

`YearReport` yalnızca `report` sözlüğünü gösterir; hiçbir hesap yapmaz. "Devam" düğmesi `report_closed` yayar.

---

## 7. Arsa listesi (A tanımlar, B güvenir)

| plot_id | plot_kind |
|---|---|
| `U01` … `U08` | `&"urban"` |
| `O01` … `O05` | `&"open"` |
| `C01` … `C02` | `&"coastal"` |

Arsa eklemek veya türünü değiştirmek sözleşme değişikliğidir.

## 8. Bina kimlikleri ve sahne dosyaları

| # | building_id | İzinli arsa türü | Sahne (A) |
|---|---|---|---|
| 1 | `efficient_housing` | urban | `res://scenes/buildings/b_efficient_housing.tscn` |
| 2 | `solar_plant` | open | `res://scenes/buildings/b_solar_plant.tscn` |
| 3 | `public_efficiency` | urban | `res://scenes/buildings/b_public_efficiency.tscn` |
| 4 | `water_storage` | open | `res://scenes/buildings/b_water_storage.tscn` |
| 5 | `water_reuse` | open, coastal | `res://scenes/buildings/b_water_reuse.tscn` |
| 6 | `green_park` | urban | `res://scenes/buildings/b_green_park.tscn` |
| 7 | `cooling_center` | urban | `res://scenes/buildings/b_cooling_center.tscn` |
| 8 | `urban_farming` | open | `res://scenes/buildings/b_urban_farming.tscn` |
| 9 | `food_rescue` | urban | `res://scenes/buildings/b_food_rescue.tscn` |
| 10 | `recycling_compost` | open | `res://scenes/buildings/b_recycling_compost.tscn` |
| 11 | `transit_hub` | urban | `res://scenes/buildings/b_transit_hub.tscn` |
| 12 | `coastal_restoration` | coastal | `res://scenes/buildings/b_coastal_restoration.tscn` |

MVP üçlüsü: `solar_plant`, `water_storage`, `green_park`.

## 9. Girdi eylemleri (Input Map)

`project.godot` içinde ilk kurulum commit'inde tanımlanır. Ekip A kullanır.

| Eylem | Varsayılan tuş |
|---|---|
| `cam_left` / `cam_right` / `cam_forward` / `cam_back` | A / D / W / S |
| `cam_rotate_left` / `cam_rotate_right` | Q / E |
| `cam_zoom_in` / `cam_zoom_out` | fare tekerleği yukarı / aşağı |
| `select` | sol fare tuşu |
| `cancel` | sağ fare tuşu, Esc |

## 10. Fizik katmanları

| Katman | Ad | Kullanan |
|---|---|---|
| 1 | `world` | zemin, binalar |
| 2 | `plots` | `BuildPlot` tıklama alanları |

---

## 11. Sözleşme değişiklik süreci

1. İhtiyacı olan kişi `docs/PROGRESS.md` içindeki "Sözleşme değişiklik talepleri" bölümüne satır ekler.
2. Diğer kişi onaylar (sohbet veya PR yorumu yeterli).
3. Değişikliği **Ekip B** yapar: `event_bus.gd` + bu belge + sürüm numarası tek commit'te, `contract:` önekiyle, doğrudan `develop`'a.
4. İki kişi de hemen `develop`'u kendi dalına birleştirir.

## Değişiklik günlüğü

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| v1.0 | 2026-10-30 | İlk sürüm. |
| v1.7 | 2026-10-31 | Ekleme: `summary.start_stats` (final ekranında başlangıç ↔ final). Yalnızca B'nin YearReport'u kullanır. |
| v1.6 | 2026-10-31 | Ekleme: `crisis_stage_changed` info'suna `mitigation` ve `advantages`. Ekip A talebi. |
| v1.5 | 2026-10-31 | Ekleme: `crisis_stage_changed` sinyali (§5.6), `result` içine `severity` ve `assessment`. Mevcut kriz sinyalleri değişmedi; A etkilenmez. |
| v1.4 | 2026-10-31 | Ekleme: iki ret nedeni (`scene_unavailable`, `unknown_plot`). Sinyal değişikliği yok; A ret nedenlerini kullanmaz. |
| v1.3 | 2026-10-31 | Ekleme: `plot_deselect_requested` sinyali. Neden: panel kapanınca arsa vurgusu kalıyordu. A onayladı. |
| v1.2 | 2026-10-31 | Ekleme: `stats` içine enerji ve su akışları (5 anahtar). Sinyal değişikliği yok, A etkilenmez. |
| v1.1 | 2026-10-30 | Ekleme: `report.missions`, `summary.emission_reduction_pct`. Yalnızca B'nin YearReport'u kullanır; sinyal değişikliği yok, A etkilenmez. |
