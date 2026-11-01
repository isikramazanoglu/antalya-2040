# ANTALYA 2040 · Proje mimarisi

Hedef motor: **Godot 4.7.2 Stable Standard** (C#/.NET sürümü değil). İki bilgisayarda da tam olarak aynı sürüm kurulu olmalı.
Dil: GDScript. Renderer: Forward+. Hedef platform: Windows masaüstü.

Ekipler arası arayüz: `docs/INTEGRATION_CONTRACT.md`. Bu belge "neyin nerede durduğunu" anlatır, sözleşme ise "nasıl konuştuklarını".

Sahiplik kısaltmaları: **A** = Şehir ve 3D, **B** = Simülasyon ve arayüz, **ORTAK** = yalnızca sözleşme değişiklik süreciyle değişir.

---

## 1. Klasör yapısı

```
antalya-2040/
├── project.godot                  B     Proje ayarları, autoload'lar, Input Map, fizik katman adları
├── icon.svg                       B
├── .gitignore                     B     .godot/ ve dışa aktarım çıktıları hariç tutulur
├── .gitattributes                 B     Satır sonu ve ikili dosya kuralları
├── CLAUDE.md                      ORTAK Claude oturumları için giriş noktası
├── docs/
│   ├── GAME_DESIGN.md             ORTAK Oyun kuralları, sayılar, eğitim içeriği
│   ├── INTEGRATION_CONTRACT.md    ORTAK Sinyaller, fonksiyonlar, veri şekilleri
│   ├── PROJECT_ARCHITECTURE.md    ORTAK Bu belge
│   └── PROGRESS.md                ORTAK Her ekip yalnızca kendi bölümünü düzenler
│
├── autoload/
│   ├── event_bus.gd               ORTAK Yalnızca sinyal bildirimleri
│   ├── catalog.gd                 B     catalog.tres yükler, kimlikle arama yapar
│   └── game_state.gd              B     Oyun verisi + geçmiş; mantık yok
│
├── scripts/
│   ├── data/                      B (A okur)  Özel Resource sınıfları
│   │   ├── building_definition.gd
│   │   ├── event_definition.gd
│   │   ├── crisis_response.gd
│   │   ├── info_card.gd
│   │   ├── balance_config.gd
│   │   ├── co2_scenario.gd
│   │   ├── mission_definition.gd    (+ category, kind, required_buildings, info_card)
│   │   ├── glossary_term.gd         Sözlük kavramı
│   │   ├── synergy_definition.gd    Yatırım kombinasyonu (BuildingDefinition'dan türer)
│   │   └── game_catalog.gd
│   ├── sim/                       B
│   │   ├── game_controller.gd     Oyuncu taleplerini karşılar, GameState'e tek yazan
│   │   ├── turn_manager.gd        Yıl sonu adımlarını sıralar, faz makinesi
│   │   ├── economy_simulator.gd   Saf hesap: gelir, gider, nüfus
│   │   ├── climate_simulator.gd   Saf hesap: emisyon, risk, ekosistem, CO2 okuma
│   │   ├── event_manager.gd       Saf hesap: kriz planlama ve hasar
│   │   ├── mission_tracker.gd     Saf hesap: görev değerlendirme
│   │   └── final_evaluator.gd     Saf hesap: 2052 final değerlendirmesi (7 alt puan, karşılaştırma, toplamlar)
│   ├── world/                     A
│   │   ├── city_world.gd          Arsa seçimi, bina yerleştirme, efekt tetikleme
│   │   ├── camera_rig.gd          İzometrik kamera
│   │   ├── build_plot.gd          Arsa verisi ve vurgu
│   │   ├── building.gd            Bina tabanı: büyüme animasyonu
│   │   └── disaster_fx.gd         Kuraklık / sıcak / taşkın görselleri
│   └── ui/                        B
│       ├── main_menu.gd
│       ├── hud.gd
│       ├── build_panel.gd
│       ├── ui_text.gd             Arayüzdeki Türkçe adlar (gösterge, arsa türü, ret nedeni)
│       ├── ui_sandbox.gd          UISandbox: A'nın sinyallerini klavyeyle taklit eder
│       ├── climate_lab.gd
│       ├── line_chart.gd          Control._draw() ile basit çizgi grafik
│       ├── event_panel.gd
│       ├── year_report.gd
│       ├── toasts.gd              Geçici bildirimler
│       ├── city_info.gd           Şehir bilgileri paneli
│       └── settings_panel.gd      Ayarlar (tam ekran, V-Sync)
│
├── scenes/
│   ├── main/
│   │   ├── MainMenu.tscn          B     Ana sahne (run/main_scene)
│   │   └── Game.tscn              B     CityWorld + sim node'ları + UI'yi birleştirir
│   ├── world/                     A
│   │   ├── CityWorld.tscn
│   │   ├── CameraRig.tscn
│   │   ├── BuildPlot.tscn
│   │   └── DisasterFX.tscn
│   ├── buildings/                 A
│   │   ├── Building.tscn          Taban sahne
│   │   └── b_<building_id>.tscn   12 bina, Building.tscn'den miras
│   ├── ui/                        B
│   │   ├── HUD.tscn
│   │   ├── BuildPanel.tscn
│   │   ├── ClimateLab.tscn
│   │   ├── EventPanel.tscn
│   │   ├── YearReport.tscn
│   │   ├── CityInfo.tscn
│   │   ├── EducationCard.tscn
│   │   ├── FinalReport.tscn
│   │   └── SettingsPanel.tscn
│   └── dev/
│       ├── CitySandbox.tscn       A     Şehri B olmadan test etme sahnesi
│       └── UISandbox.tscn         B     Arayüzü şehir olmadan test etme sahnesi
│
├── data/                          B
│   ├── catalog.tres               GameCatalog: bütün bina ve olay listesi
│   ├── balance.tres               BalanceConfig: başlangıç değerleri ve katsayılar
│   ├── co2_scenario.tres          Co2Scenario: kaynaklı ppm tablosu
│   ├── buildings/<id>.tres        BuildingDefinition × 12
│   ├── events/<id>.tres           EventDefinition × 3+
│   ├── missions/<id>.tres         MissionDefinition × 9 (4 hedef + 5 öğrenme)
│   ├── glossary/<id>.tres         GlossaryTerm × 17
│   ├── synergies/<id>.tres        SynergyDefinition × 6
│   └── cards/<id>.tres            InfoCard (bina, olay ve İklim Laboratuvarı kartları)
│
├── tests/                         B     Headless testler (test_day1_flow, test_day2_flow, test_economy, test_crises, test_investments, test_final), pencereli testler (test_menu, test_e2e_game, test_ui, test_integration, test_education, test_playthrough), denge simülasyonu (balance_sim)
│
└── assets/
    ├── models/                    A     .glb modeller
    ├── materials/                 A     .tres materyaller (terracotta, beyaz sıva, deniz)
    ├── shaders/                   A     water.gdshader
    ├── textures/                  A
    ├── ui/                        B     theme.tres, ikonlar, fontlar
    └── audio/                     B
```

Dosya adı kuralları: script ve veri dosyaları `snake_case`, sahneler `PascalCase.tscn`, bina sahneleri `b_<building_id>.tscn`.

---

## 2. Sahne mimarisi

### 2.1 MainMenu (B)

```
MainMenu (Control, main_menu.gd)
├── Background (TextureRect)
└── VBox (VBoxContainer)
    ├── Title (Label)
    ├── NewGameButton (Button)
    ├── HowToPlayButton (Button)
    └── QuitButton (Button)
```

"Yeni oyun": `GameState.reset()` sonra `get_tree().change_scene_to_file("res://scenes/main/Game.tscn")`.

### 2.2 Game (B)

```
Game (Node)
├── GameController (Node, game_controller.gd)
│   └── TurnManager (Node, turn_manager.gd)
├── CityWorld (CityWorld.tscn örneği)          ← A'nın sahnesi, B yalnızca örnekler
└── UI (CanvasLayer)
    ├── HUD (HUD.tscn)
    ├── BuildPanel (BuildPanel.tscn)
    ├── ClimateLab (ClimateLab.tscn, başta gizli)
    ├── EventPanel (EventPanel.tscn, başta gizli)
    └── YearReport (YearReport.tscn, başta gizli)
```

`Game.tscn` CityWorld'ün iç yapısına dokunmaz. B, Game.tscn içinde CityWorld örneğinde "Editable Children" açmaz.

### 2.3 CityWorld (A)

```
CityWorld (Node3D, city_world.gd)
├── WorldEnvironment               ProceduralSkyMaterial, tonemap, SSAO, glow
├── Sun (DirectionalLight3D)       gölgeler açık
├── CameraRig (CameraRig.tscn)
├── Terrain (StaticBody3D, katman 1)
│   ├── MeshInstance3D
│   └── CollisionShape3D
├── Sea (MeshInstance3D)           water.gdshader
├── Plots (Node3D)
│   ├── U01 (BuildPlot.tscn)       plot_id = U01, plot_kind = urban
│   ├── …                          toplam 15 arsa, liste sözleşme §7
│   └── C02 (BuildPlot.tscn)
├── Decor (Node3D)                 yollar, mevcut evler, ağaçlar, iskele
└── DisasterFX (DisasterFX.tscn)
```

`city_world.gd` görevleri:
- `_unhandled_input` içinde `select` eylemiyle kameradan ışın atar (`Camera3D.project_ray_origin` / `project_ray_normal` + `PhysicsDirectSpaceState3D.intersect_ray`, maske = katman 2). Viewport'un `physics_object_picking` ayarına bağımlı değildir.
- `EventBus.build_approved` → bina sahnesini örnekler.
- `EventBus.phase_changed` → `build` değilse seçimi kapatır.
- `EventBus.crisis_started` / `crisis_resolved` → `DisasterFX.play(risk_type, severity)` / `DisasterFX.stop()`.

### 2.4 CameraRig (A)

```
CameraRig (Node3D, camera_rig.gd)       konum = bakılan nokta, Y ekseninde döner
└── Pitch (Node3D)                      sabit eğim, yaklaşık -45°
    └── Camera3D                        perspektif, düşük FOV (izometrik görünüm)
```

Dışa açık ayarlar (`@export`): kaydırma hızı, harita sınırları (`Rect2`), yakınlaştırma alt/üst sınırı, döndürme sınırı (ör. ±30°). Yakınlaştırma kamerayı Pitch ekseninde ileri geri iter. Hareketler `lerp` ile yumuşatılır.

### 2.5 BuildPlot (A)

```
BuildPlot (Node3D, build_plot.gd)       @export plot_id: StringName, plot_kind: StringName
├── Pad (MeshInstance3D)                zemin karosu, türüne göre renk
├── Highlight (MeshInstance3D)          seçim çerçevesi, başta gizli
├── PickArea (StaticBody3D, katman 2)
│   └── CollisionShape3D (BoxShape3D)
└── BuildingAnchor (Marker3D)           bina buraya eklenir
```

### 2.6 Building (A)

```
Building (Node3D, building.gd)          play_build_animation(): ölçek 0 → 1 Tween
└── Model (Node3D)                      miras alan sahnede .glb örneği veya MeshInstance3D'ler
```

Her `b_<id>.tscn` bu sahneden miras alır (Scene > New Inherited Scene) ve yalnızca `Model` altını doldurur. Bina sahnelerinde çarpışma yoktur; tıklama arsadan gelir.

### 2.6b Arayüz düzeni (Prompt 5)

- Paneller `ui_panel` grubundadır ve `open()` / `close()` sunar; HUD bir panel açarken önce `call_group("ui_panel", "close")` çağırır, aynı anda tek panel açık kalır. Esc açık paneli kapatır.
- Büyük paneller `theme.tres` içindeki `SolidPanel` varyasyonunu kullanır (opak, turkuaz üst kenar).
- Bildirimler (`Toasts`, HUD içinde, `z_index = 10`) üst ortada 3 sn görünür; rapor/kriz fazında temizlenir.
- İkonlar `assets/ui/icons/*.svg` (aynı çizgi stili); bina küçük resimleri `assets/ui/thumbnails/<id>.png`, A'nın modellerinden render edilir ve `BuildingDefinition.icon` alanına bağlıdır.
- `BuildPanel` kapatılınca şehirdeki arsa vurgusu kalır: `plot_deselected` A'ya aittir, B yayamaz.

### 2.7 HUD (B)

```
HUD (Control, hud.gd, tam ekran, mouse_filter = IGNORE)
├── TopBar (PanelContainer)              logo, yıl + ilerleme, bütçe (animasyonlu, yetmezse kırmızı), nüfus
├── LeftColumn (VBoxContainer)
│   ├── ResourcePanel                    su, enerji (üretim/talep), yaşam, ekosistem, ekonomi: ikon + değer + çubuk + durum yazısı; daraltılabilir
│   ├── Warnings                         bekleyen krizler
│   └── Missions                         aktif görevler
├── BottomBar (PanelContainer)           İnşaat, İklim Laboratuvarı, Şehir bilgileri, Son rapor, Ayarlar, Ana menü | Yılı bitir
├── Toasts (toasts.gd)                   geçici bildirimler
└── QuitConfirm (ConfirmationDialog)     ana menüye dönüş onayı
```

### 2.8 BuildPanel (B)

```
BuildPanel (PanelContainer, build_panel.gd, sağ kenar)
└── VBox
    ├── PlotTitle (Label)
    ├── Cards (VBoxContainer içinde ScrollContainer)   kodla oluşturulan toggle Button kartlar
    ├── InfoCardView (RichTextLabel)                   seçili binanın bilgi kartı
    ├── ErrorLabel (Label)                             build_rejected mesajı
    └── BuildButton (Button)
```

### 2.9 ClimateLab (B)

```
ClimateLab (PanelContainer, climate_lab.gd, tam ekran yakın)
└── TabContainer
    ├── Yerel emisyonlar      LineChart (sektör başına çizgi) + sektör tablosu
    ├── Küresel CO2           LineChart (ppm) + "senin şehrin bunu doğrudan değiştiremez" açıklaması + kaynak
    ├── Yerel riskler         3 ProgressBar (kuraklık, sıcak, taşkın) + koruma oranları
    └── Bilgi kartları        InfoCard listesi
```

Grafik için Godot'ta hazır node yoktur; `line_chart.gd` bir `Control`'dür ve `_draw()` içinde `draw_polyline` kullanır. Veri `GameState.history`'den gelir.

### 2.10 EventPanel (B)

```
EventPanel (PanelContainer, event_panel.gd, ekran ortası, mouse_filter = STOP)
└── VBox
    ├── Title (Label)
    ├── Description (RichTextLabel)
    ├── MitigationLabel (Label)          "Yatırımların hasarı %X azaltacak"
    └── Responses (VBoxContainer)        her CrisisResponse için Button (parası yetmeyen kapalı)

Sonuç ayrı kutuda gösterilmez: `crisis_resolved` gelince panel kapanır, hasar yıl sonu raporunun "Kriz" bölümünde görünür.
```

### 2.11 YearReport (B)

```
YearReport (PanelContainer, year_report.gd)
└── VBox
    ├── Title (Label)                    "2043 yıl sonu raporu"
    ├── Budget (GridContainer)           gelir, gider, net
    ├── StatDeltas (GridContainer)       önce → sonra
    ├── Crises (VBoxContainer)
    ├── Warnings (VBoxContainer)
    └── ContinueButton (Button)          report_closed
```

Oyun sonunda aynı sahne `game_over(summary)` ile final ekranı olarak açılır (puan, not, "Ana menü").

---

## 3. Simülasyon mimarisi

Kural: **veri bir yerde, hesap bir yerde, yazma tek yerde.**

| Modül | Tür | Yapar | Yapmaz |
|---|---|---|---|
| `GameState` | autoload Node | Verileri tutar (`stats`, `plots`, `pending_crises`, `history`, `year_reports`, `build_log`, `crisis_log`, `missions`, `phase`, `rng_seed`). Getter'lar (`get_stats`, `get_building_on`, `built_definitions`). `GameController`'ın çağırdığı ayarlayıcılar. Her değişimde `stats_changed`. `reset()`. | Hesap yapmaz, kural kontrol etmez. |
| `GameController` | Node (Game içinde) | Oyuncu taleplerini dinler (`build_requested`, `end_turn_requested`, `crisis_response_chosen`, `report_closed`). Kural kontrolü (sözleşme §6.3). `GameState`'e yazan tek modül. | Yıl sonu hesabı yapmaz; bunu TurnManager'a bırakır. |
| `TurnManager` | Node | Yıl sonu adımlarını sıralar, faz makinesini tutar, tur sinyallerini yayar. Simülatörlerin sonuçlarını `GameController.apply_*` ile uygulatır. | Kendi formülü yoktur; oyuncu girdisi dinlemez. |
| `EconomySimulator` | `RefCounted`, statik fonksiyonlar | `compute_year(stats, buildings, balance) -> Dictionary` (gelir, gider, nüfus değişimi); `compute_resources(population, buildings, balance)` (enerji/su akışları, yenilenebilir payı); `final_score`. | Durum tutmaz, sinyal yaymaz. |
| `ClimateSimulator` | `RefCounted`, statik fonksiyonlar | Sektör emisyonları, risk seviyeleri, ekosistem değişimi; `Co2Scenario`'dan o yılın ppm değerini okur. | Küresel CO2'yi oyuncu yatırımıyla değiştirmez. |
| `EventManager` | `RefCounted`, statik fonksiyonlar | `plan_warnings`, `severity`, `assess` (tehlike/maruziyet/hassasiyet/uyum), `available_responses`, `validate`, `preview`, `resolve`. | Sinyal yaymaz, panel açmaz. |

Saf fonksiyonların faydası: Ekip B bunları sahne açmadan küçük bir test script'iyle sınayabilir ve iki modül birbirinin işini üstlenemez.

### 3.1 Faz makinesi (TurnManager)

```
build ──end_turn──► [kriz var mı?] ──evet──► crisis ──response──► (devam)
                          │ hayır                                   │
                          ▼                                         ▼
                    ekonomi → iklim → uyarı planlama → report ──report_closed──► yıl+1
                                                                      │
                                                     yıl > 2052 ? game_over : build
```

Kriz yanıtı beklenirken `TurnManager` `await` kullanmaz; `crisis` fazında kalır ve `GameController` yanıtı iletince `continue_after_crisis()` ile kaldığı adımdan devam eder. Bu, akışı hata ayıklamada izlenebilir tutar.

### 3.2 Rastgelelik

`GameState.rng_seed` ile kurulan tek bir `RandomNumberGenerator` `TurnManager`'da tutulur ve `EventManager`'a parametre olarak verilir. Aynı seed aynı oyunu üretir; demo için sabit seed kullanılabilir.

---

## 4. Veri yapıları (özel Resource sınıfları)

Hepsi `scripts/data/` altında, `class_name` ile, `extends Resource`. Alanlar `@export` ile Inspector'da düzenlenir.

### BuildingDefinition

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | StringName | Sözleşme §8 |
| `display_name` | String | |
| `short_description` | String | Kart üstündeki tek cümle |
| `category` | StringName | `energy`, `water`, `heat`, `food`, `waste`, `transport`, `coast` |
| `cost` | int | Kredi |
| `upkeep_per_year` | int | |
| `allowed_plot_kinds` | Array[StringName] | |
| `max_count` | int | Varsayılan 1 |
| `scene` | PackedScene | A'nın `b_<id>.tscn` dosyası |
| `icon` | Texture2D | İsteğe bağlı |
| `on_build_effects` | Dictionary | İnşa anında bir kez: `{"quality_of_life": 5}` |
| `yearly_effects` | Dictionary | Her yıl sonu: `{"water_security": 2}` |
| `emission_multipliers` | Dictionary | Sektör çarpanı: `{"energy": -0.30}` = enerji emisyonu %30 az |
| `risk_reduction` | Dictionary | Kriz hasarını azaltma: `{&"drought": 0.30}`. Anahtar `StringName` (risk_type ile aynı tip) |
| `energy_production`, `energy_consumption`, `water_production`, `water_consumption` | float | İsteğe bağlı kaynak akışları (oyun birimi/yıl); üretim yenilenebilir, negatif tüketim tasarruf |
| `recycled_water_production` | float | Geri kazanılmış su (içme suyu sayılmaz) |
| `components` | Dictionary | Tek yatırımdaki ayrı mekanikler, kartta gösterilir |
| `info_card` | InfoCard | |

### EventDefinition

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | StringName | `heatwave`, `drought`, `coastal_flood` … |
| `display_name`, `description` | String | |
| `risk_type` | StringName | `drought`, `heat`, `coastal_flood` |
| `earliest_year` | int | Bu yıldan önce gelmez |
| `scripted_year` | int | 0 değilse kriz tam bu yıl gelir (demo garantisi) |
| `base_probability` | float | Yıllık olasılık; risk seviyesiyle ölçeklenir |
| `lead_years` | int | Uyarı ile kriz arası, varsayılan 1 |
| `base_damage` | Dictionary | `{"credits": -150, "water_security": -20}` |
| `responses` | Array[CrisisResponse] | |
| `warning_text` | String | Uyarıda gösterilen cümle |
| `vulnerability_stats` | Dictionary | Hassasiyet ağırlıkları `{"water_security": 1.0}` |
| `visual_effect_id`, `affected_area`, `affected_plot_kinds` | StringName / Array | A'nın görselleri için (sözleşme v1.5) |
| `energy_production`, `energy_consumption`, `water_production`, `water_consumption` | float | İsteğe bağlı kaynak akışları (oyun birimi/yıl); üretim yenilenebilir, negatif tüketim tasarruf |
| `recycled_water_production` | float | Geri kazanılmış su (içme suyu sayılmaz) |
| `components` | Dictionary | Tek yatırımdaki ayrı mekanikler, kartta gösterilir |
| `info_card` | InfoCard | |

### CrisisResponse

`id: StringName`, `label: String`, `description: String`, `cost: int`, `damage_multiplier: float` (0..1), `extra_effects: Dictionary`, `required_building: StringName` (boş değilse yalnızca bu bina kuruluysa seçilebilir).

### InfoCard

`id: StringName`, `title: String`, `body: String` (BBCode serbest), `sources: Array[String]` (her satır: "Kurum, başlık, yıl, URL, erişim tarihi").

### BalanceConfig

Başlangıç değerleri (kredi, nüfus, göstergeler), `start_year`, `end_year`, kişi başı vergi, şehir taban gideri, nüfus büyüme katsayısı, sektör taban emisyonları, risk yıllık artışları, koruma üst sınırı (0.8). Tüm sayılar `GAME_DESIGN.md` §4'ten gelir.

### MissionDefinition

`id`, `title`, `description`, `stat` (stats anahtarı), `target`, `at_most` (emisyon gibi altına inilecek hedefler), `deadline_year`, `reward_credits`. Yıl sonunda `MissionTracker` değerlendirir; durum `GameState.missions` içinde (`active` / `done` / `failed`).

### Co2Scenario

`years: PackedInt32Array`, `ppm: PackedFloat32Array`, `scenario_name: String`, `source: String`. Eksik yıl için `ClimateSimulator` -1.0 döner ve arayüz "veri yok" yazar.

### GameCatalog

`buildings: Array[BuildingDefinition]`, `events: Array[EventDefinition]`, `lab_cards: Array[InfoCard]`, `missions: Array[MissionDefinition]`, `balance: BalanceConfig`, `co2: Co2Scenario`.

**Kombinasyon eklemek:** `data/synergies/<id>.tres` (SynergyDefinition: `requires` + etkiler) oluştur, `catalog.tres` → `synergies` dizisine ekle. `GameState.built_definitions()` onu otomatik dahil eder.

**Veri doğrulaması:** `Catalog.validate()` eksik maliyet, sahne, arsa türü, bilgi kartı ve yinelenen kimliği listeler; oyun açılırken uyarı olarak yazılır.

**Yeni bina eklemek:** `data/buildings/<id>.tres` oluştur, `catalog.tres` → `buildings` dizisine ekle, A `b_<id>.tscn` hazırlar ve `scene` alanına sürükler. Kod değişmez. Sözleşme §8'e satır eklenir.
**Yeni kriz eklemek:** `data/events/<id>.tres` oluştur, `catalog.tres` → `events` dizisine ekle. Yeni `risk_type` gerekiyorsa sözleşme değişikliğidir (A'nın efekt yazması gerekir).

Klasör taramak yerine katalog dizisi seçildi: dışa aktarılmış oyunda `.tres` dosyaları yeniden adlandırıldığı için klasör tarama hatalara açık; dizi ise hem editörde hem dışa aktarımda aynı çalışır.

---

## 5. Görsel ayarlar (A)

- Renderer: Forward+.
- `DirectionalLight3D`: gölgeler açık, `directional_shadow_mode` = PSSM 4 Splits, gölge bulanıklığı biraz artırılmış (yumuşak gölge).
- `WorldEnvironment`: ProceduralSkyMaterial, tonemap Filmic veya ACES, SSAO açık, hafif glow. SDFGI kullanılmaz (performans ve hackathon süresi).
- Low-poly modeller: Blender'da elle veya CC0 lisanslı hazır paketlerden. Her harici modelin lisansı `assets/models/LICENSES.md`'ye yazılır.
- Palet: terracotta çatı, kırık beyaz sıva, zeytin yeşili, turkuaz deniz. Ortak materyaller `assets/materials/` altında tekrar kullanılır.
- Felaket efektleri: sıcak için `WorldEnvironment` renk tonu + ısı pusu, kuraklık için zemin materyal rengi sararır, taşkın için `Sea` düzlemi `severity` oranında yükselir (Tween).

---

## 6. Test sahneleri

- **CitySandbox (A):** CityWorld örneği + küçük bir debug script'i. Tuşa basınca `EventBus.build_approved(&"U01", &"solar_plant")`, `crisis_started(...)` yayar. A, B'nin kodu olmadan bütün şehir davranışını test eder.
- **UISandbox (B):** CityWorld yerine boş Node3D + UI. Debug tuşları `plot_selected(&"U01", &"urban", true)` yayar.

İki sandbox da `scenes/dev/` altında, dışa aktarımda hariç tutulur.

---

## 7. Dışa aktarım

Windows Desktop preset, Godot 4.7.2 export template'leri ile. `export_presets.cfg` B'nin sahipliğindedir ve repoya eklenir. `scenes/dev/*` ve `tests/*` dışa aktarım filtresiyle hariç tutulur. Çıktı: `export/ANTALYA2040.exe` (PCK gömülü, tek dosya; `export/` git'e girmez).

Komut satırından: `<godot> --headless --path . --export-release "Windows Desktop" build/windows/ANTALYA2040.exe`. Teslim paketi: `build/ANTALYA2040_Windows_Demo.zip` (.exe + OKUBENI.txt). `build/` ve `export/` git dışında.

---

## 8. Dosya sahipliği ve çalışma kuralları

| Yol | Sahip | Diğer ekip |
|---|---|---|
| `scenes/world/**`, `scenes/buildings/**`, `scripts/world/**`, `assets/models/**`, `assets/materials/**`, `assets/shaders/**`, `assets/textures/**`, `scenes/dev/CitySandbox.tscn` | A | Dokunmaz |
| `autoload/catalog.gd`, `autoload/game_state.gd`, `tests/**`, `scripts/sim/**`, `scripts/ui/**`, `scripts/data/**`, `scenes/main/**`, `scenes/ui/**`, `data/**`, `assets/ui/**`, `assets/audio/**`, `scenes/dev/UISandbox.tscn` | B | Dokunmaz |
| `project.godot`, `export_presets.cfg`, `.gitignore`, `.gitattributes` | B | Değişiklik isterse PROGRESS.md'ye yazar |
| `autoload/event_bus.gd`, `docs/INTEGRATION_CONTRACT.md` | ORTAK | Sözleşme değişiklik süreci (sözleşme §11) |
| `docs/GAME_DESIGN.md`, `docs/PROJECT_ARCHITECTURE.md`, `CLAUDE.md` | ORTAK | Önce haber verilir, küçük commit, hemen push |
| `docs/PROGRESS.md` | ORTAK | Herkes yalnızca kendi ekip bölümünü düzenler |

İki özel durum:
- `data/buildings/<id>.tres` içindeki `scene` alanı A'nın sahnesine bağlanır. Bağlamayı **B** yapar; A sahne dosyasını push edip PROGRESS.md'de "hazır" işaretler.
- `Game.tscn` CityWorld'ü örnekler ama içini açmaz. CityWorld'ün kök node adı (`CityWorld`) ve kök script'i değişmez.

Kurallar:
1. Bir `.tscn` dosyasını aynı anda iki kişi açıp kaydetmez. Godot sahne dosyaları birleştirmede kolay bozulur.
2. Başkasının dosyasında hata görürsen düzeltme; PROGRESS.md'ye yaz veya sahibine söyle.
3. Her Claude oturumu işe başlamadan `CLAUDE.md` ve dört belgeyi okur, yalnızca kendi ekibinin dosyalarını değiştirir.
4. Sözleşmede olmayan bir sinyale veya node yoluna güvenen kod yazılmaz.
5. Godot editörünü `git pull`'dan önce kapat veya pull sonrası "Reload" seçeneğini kabul et; eski sahneyi kaydedip yeniyi ezme.

## 9. GitHub çalışma sistemi

Dal yapısı:

| Dal | Amaç | Kim push eder |
|---|---|---|
| `main` | Her an demo edilebilir sürüm | Yalnızca `develop`'tan birleştirme, gün sonunda |
| `develop` | Entegrasyon | PR ile; `contract:` commit'leri doğrudan (B) |
| `feature/city-world` | Ekip A'nın işi | A |
| `feature/simulation-ui` | Ekip B'nin işi | B |

Üç gün ve iki kişi için bu yapı yeterli; daha fazla dal açmayın. `develop`'u tutmanın nedeni: `main` jüri demosu için her zaman çalışır kalır.

Günlük döngü (her iki kişi):

```
git switch feature/<kendi-dalın>
git fetch origin
git merge origin/develop          # sabah ve her entegrasyon noktasından sonra
# ... çalış, Godot'ta oyunu çalıştırıp dene ...
git add <yalnızca kendi dosyaların>
git commit -m "world: arsa seçimi vurgusu"
git push origin feature/<kendi-dalın>
```

Entegrasyon noktaları (günde 3 kez, ör. 12:00, 17:00, 22:00):
1. A ve B kendi dallarına `origin/develop`'u birleştirir, oyunu çalıştırır, push eder.
2. A PR açar → `develop`'a birleşir. Sonra B, `develop`'u kendi dalına çeker ve PR açar → birleşir. Sırayla yapılır, aynı anda değil.
3. İkisi de `develop`'u çekip `Game.tscn`'i çalıştırır. Akış çalışıyorsa PROGRESS.md "Entegrasyon günlüğü"ne satır yazılır.
4. Gün sonu: `develop` oynanabilir durumdaysa `main`'e birleştirilir ve etiketlenir (`v0.1-gun1`).

Commit mesajı önekleri: `world:`, `sim:`, `ui:`, `data:`, `contract:`, `docs:`, `fix:`, `chore:`.

Repo dosyaları:
- `.gitignore`: `.godot/`, `*.tmp`, `export/`, `*.translation`.
- `.gitattributes`: `* text=auto eol=lf`; `*.glb`, `*.png`, `*.jpg`, `*.wav`, `*.ogg`, `*.ttf` için `binary`.
- `*.import` ve `*.uid` dosyaları repoya **eklenir** (Godot kaynak kimliklerini bunlarla tutar; eksik olursa diğer bilgisayarda bağlantılar kopar).
- 50 MB üstü dosya yok; büyük model gerekiyorsa sadeleştirilir.

## 10. Risk analizi

| Risk | Etki | Önlem |
|---|---|---|
| `.tscn` birleştirme çakışması | Sahne açılmaz, saatler kaybolur | Dosya başına tek sahip; Game.tscn yalnızca B'de; CityWorld yalnızca A'da |
| İki bilgisayarda farklı Godot sürümü | Dosya biçimi farkı, uid değişiklikleri | İkisi de 4.7.2 Standard; ilk gün `Help > About` ile kontrol |
| `.uid` / `.import` dosyalarının commit edilmemesi | Diğer bilgisayarda kayıp kaynak hataları | §9 kuralı; ilk kurulum commit'inde örnek bir sahne ile test |
| Sinyal adı veya parametre farkı | Sessizce hiçbir şey olmaz | Tek `event_bus.gd`; sözleşme yalnızca eklemeyle büyür; sandbox sahneleriyle test |
| Arayüze tıklayınca arkadaki arsanın seçilmesi | Yanlış inşaat | Paneller `mouse_filter = STOP`, dünya `_unhandled_input` |
| Entegrasyonun son güne kalması | Demo çalışmaz | Günde 3 entegrasyon noktası; Gün 1 akşamı uçtan uca akış zorunlu |
| 3D modellerin yetişmemesi | Boş şehir | Önce basit kutu/silindir yer tutucular; model sonra değişir, kod değişmez |
| Performans (gölge, SSAO, çok mesh) | Düşük FPS | Low-poly, ortak materyal, SDFGI yok, Gün 3 sabahı orta seviye PC'de test |
| Denge bozukluğu (çok kolay / imkansız) | Oyun sıkıcı | Tüm sayılar `.tres` dosyalarında; Gün 3'te 2–3 tam oyun testi |
| Doğrulanmamış bilimsel bilgi | Eğitim değeri ve güvenilirlik kaybı | Kaynaksız sayı yok kuralı; CO2 tablosunda senaryo adı ve kaynak zorunlu |
| İki Claude oturumunun birbirinin dosyasını değiştirmesi | Çakışma, bozulma | CLAUDE.md'de sahiplik kuralı; commit öncesi `git status` ile yalnızca kendi yollarını ekle |
| Windows export template eksikliği | Son gün teslim edilemez | Gün 1'de boş bir export denemesi |
