# ANTALYA 2040 · İlerleme

Her ekip yalnızca kendi bölümündeki kutuları işaretler. Ortak bölümlere satır **eklenir**, var olan satır silinmez.
İşaret: `[ ]` yapılmadı, `[~]` sürüyor, `[x]` bitti ve kendi dalında çalışıyor, `[D]` develop'a birleşti.

Son güncelleme: 2026-10-31 · Aşama: **10A, 10B, 10C tamam ve `feature/simulation-ui`'de birleşik; sırada PR → develop, sonra main + v1.0**
Repo: https://github.com/isikramazanoglu/antalya-2040 (gizli)

---

## Gün 0 · Kurulum (ikisi birlikte, 1–2 saat)

- [x] İki bilgisayarda Godot 4.7.2 Stable Standard kurulu (Mac ve Windows: 4.7.2.stable.official)
- [x] GitHub reposu açıldı (gizli); iki kişi de yazıyor (A PR #2, #4, #7, #9, #12 açtı)
- [x] `main`, `develop`, `feature/city-world`, `feature/simulation-ui` dalları açıldı ve gönderildi
- [x] B: iskelet commit'i `develop`'a: `project.godot` (Forward+, autoload'lar, Input Map, fizik katman adları), `.gitignore`, `.gitattributes`, `event_bus.gd`, `scripts/data/*.gd` boş Resource sınıfları, boş `catalog.tres`, `Game.tscn`, `MainMenu.tscn`
- [x] A: `CityWorld.tscn` kök node'u (boş zemin + kamera) iskelete eklendi, Game.tscn içinde açılıyor
- [x] İki bilgisayarda da `develop` çekildi, oyun açıldı, hata yok (A, B'nin testlerini Windows'ta da çalıştırdı)
- [x] Windows export: Mac'te `export/ANTALYA2040.exe` üretildi (PCK gömülü, Game sahnesi ve 12 bina paketten yüklendi, dev/test hariç). A Windows'ta da üretip çalıştırdı (entegrasyon günlüğü).

## Gün 1 · Oynanabilir prototip (3 yatırım)

Hedef akşam: menü → şehir → arsa seç → 3 yatırımdan birini inşa et → bütçe düşer → yılı bitir → rapor → 2052 → final.

### Ekip A
- [x] CameraRig: kaydırma, yakınlaştırma, ±30° döndürme, sınırlar
- [x] Zemin, deniz düzlemi, ışık ve WorldEnvironment ilk ayar
- [x] BuildPlot sahnesi ve 15 arsa (sözleşme §7)
- [x] Işınla arsa seçimi, vurgu, `plot_selected` / `plot_deselected`
- [x] `phase_changed` ile seçimi kilitleme
- [x] Building taban sahnesi + büyüme animasyonu
- [x] Yer tutucu modeller: `b_solar_plant`, `b_water_storage`, `b_green_park`
- [x] `build_approved` → bina yerleştirme
- [x] CitySandbox sahnesi

### Ekip B
- [x] Resource sınıfları, `balance.tres`, 3 `BuildingDefinition`
- [x] Catalog ve GameState
- [x] GameController: inşaat kontrol zinciri (sözleşme §6.3)
- [x] EconomySimulator
- [x] TurnManager: faz makinesi (krizsiz)
- [x] HUD, BuildPanel (kartlar ayrı sahne değil, kodla oluşan Button)
- [x] YearReport ve final ekranı
- [x] MainMenu
- [x] UISandbox sahnesi

### Gün 1 notları (B)
- Test: `<godot> --headless --path . --script res://tests/test_day1_flow.gd` → 20 kontrol, hepsi geçiyor.
- 3 binanın `scene` alanı boş. A `b_solar_plant`, `b_water_storage`, `b_green_park` sahnelerini push edince B bağlayacak.
- `Game.tscn` şu an arsa seçemiyor; bu A'nın `plot_selected` işi. O zamana kadar arayüz `scenes/dev/UISandbox.tscn` ile denenir (tuşlar 1-4 arsa, 0 seçimi kaldır).
- Bilgi kartlarında sayı yok, `sources` boş. Kaynak eklenince sayı yazılabilir.
- Arayüz teması: `assets/ui/theme.tres`, `project.godot` → `gui/theme/custom`.

## Gün 2 · 12 yatırım, iklim, krizler

### Ekip A
- [x] Kalan 9 bina sahnesi (önce yer tutucu, sonra low-poly)
- [x] Akdeniz dekor: evler, yollar, ağaçlar, iskele, terracotta materyaller
- [x] DisasterFX: sıcak, kuraklık, taşkın
- [x] `crisis_started` / `crisis_resolved` bağlantısı
- [x] Deniz shader'ı (turkuaz)

### Gün 1–3 notları (A, Windows)
- Windows bilgisayarda Godot 4.7.2.stable.official kurulu (Mac ile aynı sürüm). `develop` (85a4b42) bu dala alındı; B'nin `test_day1_flow.gd` ve `test_day2_flow.gd` testleri Windows'ta da TAMAM.
- 12 bina sahnesi hazır: `scenes/buildings/b_<id>.tscn` (hepsi `Building.tscn`'den miras, low-poly). **B:** `data/buildings/*.tres` → `scene` alanları bağlanabilir. Bağlanana kadar CityWorld sözleşme §8'deki yoldan sahneyi kendisi bulur; boş kutu görünmez.
- Arsa yerleşimi: U01–U04 kuzey sıra, U05–U08 güney sıra (ana caddenin iki yanı), O01–O05 kuzeyde açık alan, C01/C02 kordonun güneyinde kıyıda. Arsa kimliği arsanın sol alt köşesinde yazar.
- Seçim: sol tık seç, boş yere sol tık / sağ tık / Esc bırak. Fare üstündeyken arsa hafif parlar. Faz `build` değilse seçim kapanır ve seçili arsa varsa `plot_deselected` yayılır.
- Kamera: WASD kaydır, Q/E ±30° döndür, tekerlek yakınlaş, orta tuş sürükle. Ayarlar `CameraRig` üzerinde `@export`.
- Kriz efektleri `severity` ile ölçeklenir: sıcak = sıcak ton + ısı pusu, kuraklık = zemin/bitki sararır + toz sisi, taşkın = deniz ve kordon şeridinde su yükselir + fırtına + yağmur. `crisis_resolved`'dan 1.5 sn sonra 3 sn'de söner.
- Sahne yeniden açılırsa CityWorld binaları `GameState.get_building_on` ile geri kurar.
- Dekor (evler, zeytinlik, palmiyeler, iskele, tekneler, şemsiyeler, dağlar) `scripts/world/city_decor.gd` ile sabit seed'le kodla kurulur; sahneye kaydedilmez, editörde de görünür.
- Test: `scenes/dev/CitySandbox.tscn` (B sıradaki bina, N hepsi, 1/2/3 kriz, R krizi bitir, P faz). Headless doğrulama: tıklama → `plot_selected`, faz kilidi, 12 bina, 3 efekt ve Game.tscn'de B ile uçtan uca inşaat; hepsi geçiyor.
- Performans (RTX 5060 Laptop, 1080p, vsync kapalı): boş şehir ~520 FPS, 12 bina ~500 FPS, taşkın + yağmur ~450 FPS, ~515 draw call. Orta seviye bir PC'de henüz denenmedi.
- Harici model yok (`assets/models/LICENSES.md`).
- Prompt 3 (A, 2026-10-31): belediye binası ve saat kuleli meydan, kordon meydanı, marina (deniz feneri, dalgakıran, yelkenliler), ağaçlarda hafif rüzgâr (`foliage.gdshader`), caddede dolaşan araçlar. Dekor artık MultiMesh ile çiziliyor. Boş arsa turkuaz, dolu arsa kehribar renkte parlar; etiket kimlik + tür gösterir ("U01 · KENT"). CityWorld'e görsel yerleştirme fonksiyonları eklendi: `get_plot_kind`, `is_plot_occupied`, `place_building` (başarısızsa false + uyarı). Sözleşme değişmedi.
- Prompt 5 sonrası (A, 2026-10-31): Seçilen arsa yan panellerin veya alt çubuğun arkasında kalırsa kamera onu yumuşakça görünür alana kaydırır (`CameraRig.bring_into_view`, güvenli alan `safe_area` ile ayarlanır). Açılış kadrajı sol panel payı kadar sağa kaydırıldı. Yalnızca A dosyaları.
- Prompt 6 (A, 2026-10-31): CityWorld `plot_deselect_requested`'e (v1.3) bağlandı; BuildPanel × veya Esc ile kapanınca arsa vurgusu kalkar ve `plot_deselected` yayılır. Kamera artık seçilen arsayı ortaya çekmek yerine yalnızca görünür alana girecek kadar kaydırır (alt çubuk arkasına kıyı arsası kaçmıyordu). Gerçek tıklama/tuşla 1280x720 ve 1920x1080'de denendi; A şehir testi + B'nin 7 testi (day1, day2, economy, integration, menu, e2e, ui) TAMAM.
- Prompt 7B (A, 2026-10-31): Kriz görselleri modüler: `DisasterFX` (yönetici) + `scripts/world/effects/` altında `HeatEffect`, `DroughtEffect`, `FloodEffect` (sahneleri `scenes/world/effects/`). CityWorld `crisis_stage_changed` (v1.5) ile sürülür: uyarı %15, hazırlık %30, kriz %100 (× şiddet), çözüldü %35 (toparlanma), bitti %0; aşama sinyali yoksa `crisis_started`/`crisis_resolved` yedek. Kuraklık: tarla, zeytinlik ve boş açık alan arsaları sararır, şehir zemini az, parklar hiç; yeni rezervuar (kuzey, `Reservoir.tscn`) su seviyesini GameState `water_security`'den alır. Sıcak: ölçülü sıcak ton, ısı pusu yalnızca uzakta. Taşkın: deniz + kordon suyu, kıyı restorasyonlu arsaya su girmez, erken uyarı ışığı yanıp söner. Koruyucu binalar (`risk_reduction`'da ilgili risk) çevresinde hare. Kriz aktif olunca etkilenen bölge ekran dışındaysa kamera yalnızca gerektiği kadar kayar. Efektler GameState'e yazmaz; bitince ışık, sis, materyaller başlangıç değerlerine döner. Prompt 7B'nin 15 testi + B'nin 8 testi TAMAM; 1080p 430–500 FPS (RTX 5060 Laptop).
- Açık (A): efektin genel şiddeti henüz koruma oranına bağlı değil; v1.6 talebi aşağıda. → Prompt 9B'de bağlandı.
- Prompt 9B (A, 2026-10-31) · 12 yatırımın 3D modelleri:
  - 12 bina sahnesi yeniden üretildi, kimlikler ve yollar aynı (`scenes/buildings/b_<id>.tscn`, B'nin `scene` bağlantıları değişmedi). İlk üç model (güneş, su deposu, park) korunup geliştirildi; diğer dokuzu prompttaki görsel özelliklerle zenginleştirildi (konut: iki blok, balkon gölgelikleri, ahşap güneş kırıcı, yeşil çatı · kamu: güneş kırıcı cephe, panel + yeşil çatı · geri kazanım: dikdörtgen havuzlar, kanal, filtreler, sazlık · serinleme: konsol gölge çatı, ısı pompaları, su oyun alanı · tarım: cam sera, yataklar, damla sulama · gıda: düz çatılı lojistik deposu, rampa, e-araç · geri dönüşüm: ayrıştırma binası, bölmeler, kompost sıraları · toplu taşıma: kanatlı peron, e-otobüs + pantograf, çimli tramvay hattı · kıyı: kumul sırtları, iskele, tahkimat, izleme istasyonu, uyarı direği, seviye ölçer).
  - Üretici: `scripts/world/dev/gen_buildings.py` (`py scripts/world/dev/gen_buildings.py .`). Ortak yerleşim standardını her modelde denetler: pivot arsa ortasında, arsa kenarından ≥ 0.2 m içeride, zeminin en fazla 0.12 m altına, yükseklik sınıfları (ground 3.2 · infra/public 4.2 · housing 5.2 · mast 5.6 m). Bina önü +z (kameraya bakar).
  - Ortak palet: `assets/materials/buildings/bld_*.tres` (krem, taş, terracotta, sönük turkuaz, zeytin yeşili, ölçülü metal). Şehir dekorunun materyallerine dokunulmadı.
  - `Building` (`building.gd`): `building_id`, `footprint`, `height_class` alanları; açılışta sabit parçalar materyal başına tek mesh'te birleşir. `Model/Live/Crisis_<risk_type>` kriz tepkileri: sıcakta serinleme merkezinde su sisi + tabela, parkta çeşme sisi; kuraklıkta tarımda gölge filesi, su deposunda gösterge ışığı; taşkında kıyı seviye ölçeri. Hiçbiri hesap yapmaz.
  - Koruma oranı (v1.6 `mitigation`) bağlandı: kriz görseli en fazla %40 hafifler (`CrisisEffect.damping`). Kuraklıkta bina bitkileri (park, yeşil çatı, tarım, kumul) tarlaya göre az solar (%30), bitince geri döner.
  - Testler `scripts/world/dev/` altına taşındı: `test_buildings.gd` (9B'nin 10 senaryosu × 12 model), `test_city.gd`, `test_city_fx.gd`, `test_deselect_real.gd`; hepsi TAMAM. B'nin 10 testi de TAMAM.
  - Performans (RTX 5060 Laptop, 1080p, vsync kapalı): 12 bina 470 FPS / 504 draw call (önceki modeller 481 / 492); detay yaklaşık 2 kat, nesne sayısı 1082 → 961. Orta seviye PC'de ölçüm hâlâ yapılmadı.
  - **B için:** (1) Kart küçük resimleri eski modellerden; yenileri `<godot> --path . --script res://scripts/world/dev/render_thumbnails.gd -- <klasör>` ile üretilir (320×220 şeffaf, aynı adlar), `assets/ui/thumbnails/`'e kopyalamak B'de. (2) İstenirse `export_presets.cfg` → `exclude_filter`'a `scripts/world/dev/*` eklenebilir (yalnızca test/araç).
- Prompt 10B (A, 2026-10-31) · Final şehir sunumu (FINAL_VISUAL_CONTRACT.md):
  - `CityWorld` `final_presentation_requested`'i dinler (FinalReport'taki "Şehrin dönüşümünü izle" düğmesi böylece görünür), sunum bitince `final_presentation_finished` yayar. Sözleşme değişmedi.
  - `scripts/world/final_presentation.gd` (CityWorld'ün çocuğu, kodla kurulur): 1) 2040 binasız şehir, genel görünüm (kıyı dahil) · 2) dönüşüm: `city_2052.builds` yıl sırasıyla, her yatırımın arsasına yaklaşılır, bina inşa animasyonuyla belirir; `GameState.crisis_log`'daki krizler kendi yılında kısa tekrar (B'nin şiddet ve `mitigation` değeriyle, koruyan binaların adı) · 3) 2052 son yerleşim (`city_2052.plots`) + kıyı / yeşil alan / enerji-su-gıda / kent merkezi kamera turu (yalnızca yatırım olan bölgeler) · 4) aynı açıdan 2040 görüntüsü ↔ canlı 2052 kayan perde, yatırımlı arsalar hafif parlar. Süre ~55–65 sn (B'nin 120 sn yedeğinin altında). Esc atlar.
  - Sunum B'nin arayüzünün üstündeki kendi katmanında (CanvasLayer 50) tam ekran, aynı 3D dünyayı gösteren SubViewport'ta çizilir; bu sürede ana görünümün 3D çizimi kapalıdır (şehir iki kez çizilmez), arkadaki arayüze tıklanamaz. B'nin node'larına dokunulmadı. Ekrandaki sayılar `summary`'den okunur (yatırım sayısı, `emission_reduction_pct`, `score`/`grade`); hesap yok.
  - `CityWorld.show_city_state(plots, animate)` (sözleşmede önerilen ad) + `show_plot_state`, `restore_city_state`: yalnızca görsel; gerçek binalar gizlenir/gösterilir, yerleşimde olup şehirde olmayan (ya da farklı) bina geçici kopyayla çizilir, sonra silinir. `GameState`'e yazmaz, `place_building` çağırmaz. Bilinmeyen kimlik → arsa boş + uyarı; `summary.city_2052` yoksa sunum atlanır ve hemen bitiş yayılır.
  - `CameraRig`: `cinematic` (oyuncu girdisi kapalı), `get_view`/`set_view`, `glide_to`, `play_tour` (sözleşme §D). Sunum bitince kamera oyuncunun son görünümüne döner.
  - Test: `scripts/world/dev/test_final_presentation.gd` (gerçek Game.tscn 2052'ye kadar; kabul ölçütleri 1–6, Esc, geçici kopya, bilinmeyen kimlik, eksik summary, yatırımsız oyun; 28 kontrol) 1280×720 ve 1920×1080'de TAMAM. B'nin 11 testi + A'nın diğer 4 testi TAMAM. Windows export (geçici klasöre) hatasız, exe açılıyor.
  - Performans (RTX 5060 Laptop, 1080p, vsync kapalı): normal 481 FPS, sunum boyunca ortalama 427 FPS.
  - Bilinen sınır: ısı pusu (ekran efekti) ana görünümde çizildiği için sunumdaki sıcak hava tekrarında görünmez; sıcak ton, sis ve koruma hareleri görünür. Rezervuarın su seviyesi sunumda 2052 değerinde kalır.
- 10C sonrası kontrol (A, 2026-10-31): develop 1b255c9 alındı; B'nin 12 testi (`test_playthrough` 1280×720 ve 1920×1080 dahil) + A'nın 5 testi TAMAM. `test_final_presentation.gd` titrekliği giderildi: [6]'daki sabit 5,5 sn bekleme ve 0,6 sn'lik bitiş beklemeleri koşul beklemesine çevrildi (yavaş makinede ilk sahne 5,5 sn'yi aşabiliyordu); FPS 20'ye kısılarak da TAMAM. Kontrol mesajı düşerse sunumun durumunu yazar. Kodda: art arda iki sunumda kararma tween'leri çakışmasın diye önceki durdurulur. Windows: güncel develop'tan export alındı, `ANTALYA2040.exe` pencereli açılıyor, hata yok (release şablonu dış test script'i çalıştırmadığı için exe içinde otomatik sunum testi yapılamadı; elle oynanabilir).
- FPS ölçümü (A, 2026-10-31, Windows, gerçek Game.tscn, vsync kapalı; ortalama / en düşük 1 sn). Orta seviye PC yerine aynı dizüstünün işlemciye gömülü **Intel UHD Graphics** kartı kullanıldı (`--gpu-index 1`); orta seviye bir masaüstü kartından daha zayıf olduğu için alt sınır sayılmalı.

  | Kart · çözünürlük | Normal (boş) | Normal (8 bina) | Kriz anı (2049 taşkın) | Final sunumu |
  |---|---|---|---|---|
  | Intel UHD · 1280×720 | 120 / 120 | 113 / 100 | 108 / 107 | 113 / 99 |
  | Intel UHD · 1920×1080 | 63 / 62 | 62 / 57 | 59 / 58 | 60 / 53 |
  | RTX 5060 Laptop · 1280×720 | 268 / 232 | 311 / 271 | 297 / 271 | 226 / 190 |
  | RTX 5060 Laptop · 1920×1080 | 231 / 218 | 225 / 218 | 223 / 220 | 211 / 179 |

  Ölçüm sırasında bulunan ve düzeltilen: final sunumunun ayrı görünümü pencere ne olursa olsun 1920×1080 tabanda çiziliyordu (720p'de 2,25 kat piksel); artık pencerenin gerçek boyutunda çizer. Intel UHD 720p'de final sunumu 68 → 113 FPS.
- **Prova tamam** (A, 2026-11-01, Windows, develop 3e8ad68):
  - Tam test turu: B'nin 6 headless testi + 6 pencereli testi (`test_playthrough` dahil) 1280×720 ve 1920×1080'de, A'nın 5 testi iki çözünürlükte (`test_final_presentation` 28 kontrol), derleme kontrolü hatasız; hepsi TAMAM. `balance_sim` B'nin sonuçlarıyla aynı (74 / 67 / 41 / 37).
  - Windows export: `build/windows/ANTALYA2040.exe` (110 MB) pencereli açılıyor, hata yok.
  - Demo provası export edilmiş exe ile, jüri akışına göre elle yapıldı (menü → yatırım → İklim Laboratuvarı → kriz → 2052 → "Şehrin dönüşümünü izle", Esc ile atlama, rapora ve ana menüye dönüş): sorun yok.
  - FPS: yukarıdaki tablo (orta seviye PC yerine Intel UHD).
- Görsel revizyon 2 (A, 2026-11-01) · Arsa temizliği ve vurgu sistemi:
  - Normal oyunda arsa kimlik etiketleri ("U01 · KENT") gizli; silinmedi, `BuildPlot/VisualOverlay/DebugOverlay/Label` altında. Açmak için: CityWorld Inspector → `show_debug_overlay`, CitySandbox'ta F3. Ayrı ızgara mesh'i yoktu; ızgara görüntüsü arsa zeminleri + etiketlerdi (zemin tasarımı görsel revizyon 5'te).
  - Vurgu: arsa kenarında ince çerçeve (tek mesh, arsa boyutu başına paylaşılır) + hover/seçimde hafif dolgu. Paylaşılan materyaller `assets/materials/plot_state_*.tres`, `plot_fill_*.tres` (Inspector'dan ayarlanır). Renkler: kurulabilir #65E4B7, hover #44D8E8, seçili #77CFFF, uygun değil (dolu arsada hover) #E5A36A. Animasyon yalnızca hover/seçimde, yavaş (2,4 sn) ve yalnızca saydamlık. Eski pad parlaması ve `plot_highlight.tres` kaldırıldı.
  - Durumlar: normal → yok; build fazında fare üstü → turkuaz (dolu arsada turuncu); **inşaat modu = build fazında bir arsa seçili (yatırım paneli açık)** → diğer boş arsalar ince yeşil çerçeve, dolu arsalar parlamaz; seçili → mavi (fare başka yere gitse de kalır); build dışı faz → hepsi kapalı. Mevcut ışın testi ve `set_selected`/`set_hovered` kullanıldı, ikinci seçim sistemi yok, `_selected` değişmedi.
  - Not (B): HUD'daki "İnşaat" düğmesi (arsa seçmeden panel) şehre bildirilmiyor; o anda da uygun arsaların görünmesi istenirse bir EventBus sinyali gerekir (sözleşme değişikliği, şimdilik yapılmadı).
  - Test: `scripts/world/dev/test_plot_visuals.gd` (26 kontrol, gerçek fare olaylarıyla) 1280×720 ve 1920×1080'de TAMAM; `test_city`, `test_deselect_real` yeni vurgu durumlarına uyarlandı. B'nin 12 testi iki çözünürlükte + A'nın 6 testi TAMAM. Önce/sonra görüntüleri: `build/visual_reference/` (git dışında).
- Görsel revizyon 3 (A, 2026-11-01) · Işık ve Akdeniz atmosferi (yalnızca `CityWorld.tscn` Environment/Sky/Sun, `ground.tres`, `heat_effect.gd`):
  - Godot 4.7.2, Forward+ (değişmedi). Tek WorldEnvironment (CityWorld.tscn içinde gömülü; oyun, ana menü ve CitySandbox aynı sahneyi kullanır), kamerada ayrı Environment yok, tek ışık `Sun`.
  - Gökyüzü: üst #79B9D8, ufuk #D9E8E9. Ortam ışığı gökyüzü yerine sabit renk #A8D4E0 × 0,45 (açık gökyüzü sahneyi düzleştiriyordu; gölgeler artık hafif serin). Tonemap ACES (Filmic/AgX denendi: Filmic sarı, AgX donuk), exposure 0,95, white 6. Kontrast 1,14, doygunluk 1,08 (önce 1,2). Glow 0,3, bloom 0 (beyazlar patlamasın). Sis 0,0012 → 0,0006.
  - Güneş: #FFF0DC × 1,75 (önce 1,35), yön aynı. Gölge: opaklık 1, blur 1,2, angular distance 0 → 0,35° (PCSS, yumuşak kenar), max mesafe 160 → 120 (en uzak zoom'da şehrin tamamı gölgeli), 4 parça + blend splits.
  - SSAO: yarıçap 1,2, yoğunluk 1,5 (önce 2,0), güç 1,2, detail 0,5, light affect 0.
  - Materyal: yalnızca şehir zemini `ground.tres` nötrleştirildi (0,72/0,66/0,48 → 0,74/0,71/0,60; sıcak güneşle birlikte sahneyi sarıya boyuyordu). Asfaltın mor görünmesi ortam ışığından kaynaklanıyordu, materyale dokunulmadı.
  - Sıcak hava efekti yeni ışığa göre ölçeklendi (güneş tonu 0,5 → 0,3, enerji +%20 → +%8, sis): şehir turuncuya boyanmıyor.
  - FPS (gerçek Game.tscn, vsync kapalı, normal / 8 bina / kriz / final): Intel UHD 1080p 63 / 62 / 58 / 56 (önce 63 / 62 / 59 / 60), Intel UHD 720p 118 / 116 / 107 / 106 (önce 120 / 113 / 108 / 113). RTX 5060 değerleri güç durumuna göre oynadığı için karşılaştırma dışı (bu oturumda 1080p 455–464 normal, 720p kriz ~770). RTX 720p'de 7 ölçümün 2'sinde kriz/final sırasında ~0 FPS donma görüldü, sonraki 3 ölçümde (pencere durumu kaydıyla) tekrar etmedi; sebep kanıtlanamadı.
  - **B için (project.godot):** SSAO kalitesi/half size, yumuşak gölge filtre kalitesi ve 3D kenar yumuşatma (MSAA) varsayılanda; değişiklik istenirse B'nin dosyası.
  - Testler: A'nın 6 testi + B'nin day1, crises, final, menu, integration, playthrough testleri TAMAM. Önce/sonra: `build/visual_reference/prompt3/`.
- Görsel revizyon 4 (A, 2026-11-01) · İzometrik kamera ve kompozisyon (kamera script'i değişmedi; yalnızca sahne/Inspector):
  - Önce: perspektif, FOV 32, eğim -50°, yatay dönüş 0 (yollar ekran eksenlerine paralel), hedef (-6, 0, 0), açılış uzaklığı 74, zoom 22–95.
  - Sonra: perspektif, FOV 38, eğim -43°, yatay dönüş 35° (`CityWorld.tscn` CameraRig dönüşü; script açılışta okur, Q/E ±30° bunun çevresinde), hedef (-6,9, 0, -2,6) (şehir sol panelin sağında), açılış 90, zoom 22–105 (`CameraRig.tscn`).
  - Denenen: A ortografik -42°/35°, B ortografik -48°/45°, C perspektif -42°/35°/FOV 40, C2 -45°/40°/36, C3 -40°/30°/38. Ortografik temiz ama ufuk ve derinlik kayboluyor; ayrıca zoom script'te kamera uzaklığıyla yapıldığı için ortografikte zoom çalışmaz (script değişikliği gerekirdi). Perspektifte dağlar, zeytinlik, çapraz kıyı şeridi ve bina cepheleri birlikte görünüyor.
  - DoF: normal oyunda yok. Yalnızca final sunumunun kendi kamerasında çok hafif uzak bulanıklık (`CameraAttributesPractical`, odak kameranın baktığı nokta, miktar 0,05). Intel UHD 1080p'de sunum 53 → 45 FPS (efektin maliyeti); kapatmak için `final_presentation.gd` → `DOF_AMOUNT`/`dof_blur_far_enabled`.
  - FPS (Game.tscn, vsync kapalı; normal / 8 bina / kriz / sunum): Intel UHD 1080p 60 / 59 / 56 / 45, Intel UHD 720p 113 / 109 / 103 / 86, RTX 5060 1080p 438 / 419 / 388 / 291.
  - Arsa seçimi yeni açıyla 3 zoom ve iki çözünürlükte ekrandaki her arsanın merkezinde doğru arsayı buluyor. `test_plot_visuals.gd` gerçek imleci de yapay olayın konumuna taşır (test sırasında fare kımıldarsa karışmasın).
  - Testler: B'nin 12 testi iki çözünürlükte, A'nın 7 testi TAMAM. Önce/sonra: `build/visual_reference/prompt4/`.
- Görsel revizyon 5 (A, 2026-11-01) · Şehir tasarımı, yol ağı ve kamera navigasyonu:
  - Yollar (`city_decor.gd`, yalnızca görsel): hiyerarşi — ana cadde koyu asfalt + kenar çizgileri + kesik orta çizgi, kuzey yolu orta çizgi + kuzeyinde paralel otopark (park etmiş araçlar), mahalle yolları açık asfalt çizgisiz, kordon taş yaya yolu. Bordürlü kaldırımlar (0,75), kavşak ağızlarında kesilir, köşelerde birleşir. Bütün kavşak ağızlarında yaya geçidi, dur çizgileri, ana caddede dönüş okları. Ana caddede aydınlatma direği + sokak ağacı, kordonda direkler. Asfalt ve kaldırımda hafif gürültü dokusu (`assets/materials/city/`). Yol ve parsel koordinatları değişmedi.
  - Evler: 1–3 kat (kat yüksekliği 1,4 birim ≈ 3,2 m), duvar renkleri krem/beyaz/hardal/gül/taş, iki görünen cephede (ön +z, yan +x) her katta pencere, kapı, %55 balkon, %45 panjur; kırma çatı ya da düz dam (güneş kolektörü, pergola, saksılı teras); tek katlıların bir kısmında ön bahçe çiti. Ana caddeye bakan sırada zemin katta vitrin, tente, boş tabela alanı (marka yok). Araçlar: gövde + kabin camı + tekerlek + lambalar, renk başına paylaşılan tek mesh. Dekor paleti ortak bina paletine taşındı. Şehrin batı/doğusuna kırsal tarım alanı, zeytinlik iki yana genişledi (kamera kenara gidince boş zemin görünmesin).
  - Arsalar: boş arsa zeminleri dokulu (kent taş kaplama, açık alan çayır, kıyı kum) + tür kenarlığı (kent taş bordür, açık alan/kıyı ahşap; `BuildPlot/Edge`). Seçim çerçevesi kenarlığın üstüne alındı (y 0,2).
  - Kamera (`camera_rig.gd`, yalnızca girdi/hareket): ok tuşları (Input Map'te yok, project.godot B'nin; fiziksel tuş olarak okunur), orta tuşla zemini tutup sürükleme (imleç altındaki nokta birebir), tuş arayüzde bırakılınca sürükleme takılmaz, yazı alanı odaktayken klavye kaydırmaz. Sabit açı: `CameraRig.tscn` → `rotate_limit_deg = 0` (Q/E döndürmez; final sunumunun sinematik dönüşleri çalışır). Sınır `Rect2(-30, -28, 62, 41)`. Pan hızı zoom'la ölçekli (uzakta ~3 kat).
  - Not (B, README): kontrol tablosunda Q/E "döndür" yazıyor; artık sabit açı, ok tuşları da kaydırıyor.
  - Testler: yeni `scripts/world/dev/test_camera_nav.gd` (18 kontrol, gerçek tuş/fare olaylarıyla) iki çözünürlükte TAMAM; B'nin 12 testi iki çözünürlükte + A'nın 7 testi TAMAM.
  - FPS (Game.tscn, vsync kapalı; normal / 8 bina / kriz / sunum): Intel UHD 1080p 58 / 56 / 53 / 43 (önce 60 / 59 / 56 / 45), Intel UHD 720p 107 / 104 / 98 / 81, RTX 5060 1080p 411 / 394 / 367 / 277. Draw call 229 → 366 (MultiMesh).
  - Bilinen: kaldırım rengi çevre zeminine yakın (bordür çizgisi sınırı belirtiyor); en uzak zoom'da tam köşede kara parçasının kenarı seçilebiliyor.
- Görsel revizyon 6 (A, 2026-11-01) · Revizyon 5 eksikleri (yalnızca A dosyaları; arayüz, theme.tres, project.godot B'de kaldı):
  - Kaldırım: çevre zeminden (0,74/0,71/0,60) koyu, sıcak gri taş (0,64/0,625/0,59), bordür açık (0,86) → asfalt | açık bordür | gri kaldırım | bej zemin ayrımı. Meydan/kordon açık döşemesi ayrı materyal (`city/paving_light.tres`).
  - Sahil: kumsalın başında yeni taş sahil yolu (`SEAFRONT`): deniz tarafında korkuluk (kumsala inen merdiven açıklıklarıyla), denize bakan banklar, saksılar, aydınlatma, 4 pergolalı dinlenme alanı; kıyı arsaları ve iskele boş. Kordon: kenarlarda koyu taş bant + açık orta şerit, palmiye sırasında bank + saksı.
  - Peyzaj: ana caddenin kavşak köşelerinde taş çiçeklikler, ev girişlerinde saksı (%50), dükkân önlerinde iki saksı; çiçek renkleri `city/flower_*.tres`.
  - Meydanlar: belediye meydanında taş kenar bandı, çeşme çevresinde açık taş halka, köşe çiçeklikleri, ağaç grubu, çeşmeye bakan banklar, revak önünde saksılar; kordon meydanında şemsiyeli kafe masaları ve saksılar.
  - Harita kenarı: sebep zemin geometrisiydi (kara kutusu x = ±110'da biter, yanlarda kapatıcı yok → en uzak zoom'da kenar ve arkasında gökyüzü). Zemin büyütülmedi, kamera sınırı değişmedi; Toros etekleri batı ve doğuya uzatıldı (yan tepeler), köşeler doğal manzarayla kapandı.
  - Prompt 6 tam metni (A, 2026-11-01, ikinci tur): kaldırım prompt paletine alındı (#A99C87 sıcak koyu bej taş, hücresel taş plaka dokusu; bordür #847F72 koyu) — asfalt | koyu bordür | bej kaldırım | açık zemin. Sahil yolu ve kordonda bank yönü düzeltildi (banklar artık denize bakıyor; belediye meydanında çeşmeye). **Statik insan figürleri** (projede insan modeli yoktu; kapsül/küre low-poly, ~0,78 birim ≈ 1,75 m; oturan, yürüyen, ayakta; 7 kıyafet, 4 pantolon, 3 ten rengi; yapay zekâ yok): bankta oturanlar, kordonda yürüyenler, sahilde denize bakanlar, meydanlarda küçük gruplar, kafede oturanlar — hepsi tek mesh'te birleşik (materyal başına bir yüzey). Kıyı mobilyası: çöp kutuları, iki yönlendirme tabelası, bisiklet parkı, dürbünlü seyir noktası. Saksı türleri: terracotta, taş, krem beton, modern koyu, kase; çalı + çiçek ya da küçük süs zeytini; 2-3'lük gruplar; çiçeklere hafif sarı eklendi. Bina çevreleri: kapı önü taş, %25 alçak taş bahçe duvarı, %20 yan ağaç; otopark kenarında çalılar. Meydanlara dekoratif lamba ve insanlar.
  - Uzak zoom testi (merkez, kuzeydoğu, kuzeybatı köşe, güneybatı): kara kenarı görünmüyor, deniz-kara arası boşluk yok; sınırlar aynı.
  - FPS (Intel UHD 1080p; 8 bina / sunum): 55 / 41; draw call 638 (insanlar birleştirilmeden önce 892). Not: `test_camera_nav` 720p'de bir kez sürükleme kontrolünü düşürdü, 3 tekrarda TAMAM (masaüstü imleci araya giriyor; oyunda karşılığı yok).
  - **B için (README):** Kontroller tablosunda "Q / E: kamerayı döndür" artık geçersiz. Gerçek kontroller (test_camera_nav ile doğrulandı): WASD ve ok tuşları ekran yönünde kaydırır, orta tuşla sürükleme (zemini tutup çekme), tekerlek yakınlaşma; açı sabit (Q/E döndürmez). README güncellemesi B'de.
  - Testler: A'nın 7 testi iki çözünürlükte + test_final_presentation, B'nin day1, crises, final, menu, e2e, integration, playthrough testleri TAMAM.
  - FPS (Intel UHD 1080p; normal / 8 bina / kriz / sunum): 55 / 53 / 50 / 40 (revizyon 5 sonu 58 / 56 / 53 / 43); RTX 5060 1080p 404 / 389 / 360 / 273. Önce/sonra: `build/visual_reference/prompt5/_rev6_*.png`.
- Görsel revizyon 7 (A, 2026-11-01) · Akdeniz bina kütüphanesi (yalnızca dekor; yatırım/arsa kimlikleri, BuildingDefinition, katalog değişmedi):
  - Üretici: `scripts/world/dev/gen_building_library.gd` (Godot `--script`; Blender ya da harici model yok). SurfaceTool ile özel geometri: kiremit sıralı kırma/beşik çatılar, saçak ve oluk, girintili pencere + çerçeve + denizlik, panjur, balkon kapısı, babalı / cam / dolu korkuluklu balkonlar, kapı çerçevesi + basamak + saçak, baca, iniş borusu, klima, damda güneş enerjili su ısıtıcısı, pergola, çiçeklik.
  - 12 model `assets/buildings/<kategori>/` altında (`.tres` ArrayMesh + önizleme `.tscn`): residential_house_a (klasik, kırma çatı, panjur), residential_house_b (modern, iki kademe, ahşap kaplama, güneş kırıcı), mediterranean_house_c (geleneksel Antalya: taş zemin, ahşap cumba, beşik çatı), apartment_midrise_a (4 kat), apartment_modern_b (5 kat, kaydırmalı cam balkonlar, çatı terası), apartment_urban_c (6 kat, çıkmalar, zemin dükkân, damda su ısıtıcıları), villa_modern_a (L kütle, havuz, pergola), villa_mediterranean_b (revak, teras kanadı, bahçe duvarı), commercial_shop_a (vitrin, tente, boş tabela bandı), commercial_shop_b (tek kat, köşe vitrin), public_building_a (cam giydirme + güneş kırıcı, bayrak direkleri), public_building_b (okul/sosyal tesis, şerit pencere, yeşil çatı, paneller). 240–2300 üçgen/model. Palet `assets/materials/architecture/arch_*.tres` (prompt renkleri: cephe #E8DDC8, taş #D6C8AE, çatı #C97960/#A85F4D, korkuluk #6D7776, çerçeve #8A938F, cam #8FB8C2, ahşap #A97C59).
  - Yerleşim (`city_decor.gd`): eski kutu evler (`_house`, `_roof`) kaldırıldı. Mahalle kuralı: ana cadde cephesinde dükkânlar, kuzeyde apartman bloğu, kıyı şeridinde villa ve alçak evler, kenarlarda villalar, iki kamu yapısı arsaların iki yanında (x -29 ve 25, kamera sınırı içinde). Yüksek modeller arsaların ve caddenin kamera tarafına konmaz. Sıra paketleme (model tabanı kadar yer + 0,3–1,1 ara), cephe rengi çeşitlemesi (4 ton, aynı mesh'in kopyası).
  - Performans: yerleşen binalar mahalle başına birleşik mesh (materyal başına yüzey), üç katman: kütle (gölgeli), cephe ayrıntısı (gölgesiz), ince ayrıntı (gölgesiz, 80 birimden uzakta gizlenir = LOD). Bina üçgeni toplam ~77 bin.
  - FPS (Game.tscn 1080p; normal / 8 bina / kriz / sunum): Intel UHD 48 / 49 / 47 / 39 (revizyon 6: 55 / 53 / 50 / 40; aynı ölçümde binalar gizliyken 53), RTX 5060 257 / 253 / 236 / 202. Draw call 566–869.
  - Testler: A'nın 7 testi + B'nin 12 testi TAMAM. Önce/sonra: `build/visual_reference/prompt7/` (`once_*`, `sonra_*`, `galeri_*`).
  - Lisans: `docs/ASSET_LICENSES.md` (bütün varlıklar proje içinde üretildi; harici varlık yok).
  - Prompt 8'e kalanlar: insanlar statik (kemik/animasyon yok), yaya rotaları ve NPC davranışı yok, araçlar sabit şeritte basit hareket; bina girişlerinde insan/araç etkileşimi yok.
- Görsel revizyon 8 (A, 2026-11-01) · Yaşayan şehir: iskeletli ve animasyonlu insanlar (yalnızca görsel; GameState, nüfus, ekonomi, UI, autoload değişmedi):
  - Karakterler: Quaternius "Ultimate Animated Character Pack" (CC0), 12 model `assets/characters/pedestrians/qt_*.glb` (günlük ×7, yaşlı ×2, takım elbise ×2, beyaz önlüklü ×1; 2,3–8,5 bin üçgen, 23 kemik). Ölçek 0,235 → yetişkin ≈ 0,78 birim ≈ 1,8 m. Paketteki ten rengi glTF'de neredeyse siyah geldiği için ten / gömlek / pantolon / takım / saç renkleri oyunda kişiye özgü verilir (4 ten, 9 gömlek, 6 pantolon, 7 saç). Kenney Mini Characters denendi, oranları çok "chibi" olduğu için eklenmedi. Lisans: `docs/ASSET_LICENSES.md`.
  - Animasyonlar: Walk (döngü, hız ayak kaymasın diye animasyondan ölçüldü: 0,54 birim/sn), Idle (döngü), SitDown son karesi oturma pozu. Konuşma jesti animasyonu pakette yok (Victory/Punch gibi uygun olmayanlar kullanılmadı).
  - `scripts/world/pedestrians.gd` (CityWorld/Pedestrians düğümü, autoload değil): 7 kapalı Path3D rotası (kordon, ana cadde iki kaldırım, kuzey yolu, 3 mahalle sokağı, belediye meydanı çeşme halkası), PathFollow3D ile 58 yürüyen (aynı rotada eşit aralık ve aynı hız → iç içe geçmez; 8 yan yana çift; köşeler yuvarlatılmış; faz ve hız ±%5 farklı). Oturan / bekleyenler Decor'un kaydettiği 47 yerde (27 bank ve kafe sandalyesi, sahil korkuluğunda denize bakanlar, meydan grupları, dükkân önleri ve bazı ev kapıları): kameraya en yakın 8 kişi canlı Idle, diğerleri iskelet pozundan pişmiş tek mesh.
  - Animasyon LOD: animasyonlar elle ilerletilir — 60 birimden yakında her kare, 125'e kadar 15 Hz, daha uzakta ya da ekran dışında durur (yürüyüş sürer); gölge yalnızca yakındakilerde. Çarpışma şekli yok.
  - Dekor (`city_decor.gd`): eski kapsül insanlar kaldırıldı (`_person` artık yer kaydeder; rastgele sayı sırası korunduğu için şehir yerleşimi aynı). Bank insan ölçeğinde (oturak 0,12, derinlik 0,22), kafe masası 0,3 + sandalyeler, meydan ahşap oturakları alçaldı.
  - Test: yeni `scripts/world/dev/test_pedestrians.gd` (26 kontrol: sayılar, Walk döngüsü ve faz farkı, yön, ayak yüksekliği, rotaların arsa / bina tabanına girmemesi, oturanlar, çarpışma yok, arsa tıklaması, LOD, WASD, GameState aynı). A'nın 8 testi + B'nin 12 testi TAMAM.
  - FPS (Game.tscn 1080p, aynı oturumda önce → sonra; normal / 8 bina / kriz / sunum): Intel UHD 64 / 62 / 59 / 48 → 57 / 56 / 53 / 43; RTX 5060 160 / 160 / 147 / 139 → 148 / 139 / 133 / 115 (bu oturumda dizüstü genel olarak revizyon 7 ölçümünden yavaş). Maliyetin çoğu iskelet deformasyonu ve karakter üçgenleri; draw call 763 → 1263.
  - Önce/sonra: `build/visual_reference/prompt8/` (`_karsilastirma_1/2.png`, `_yuruyus.png` kare dizisi).
  - Prompt 9'a kalanlar: araçlar hâlâ kutu gövdeli ve sabit şeritte, yaya geçitlerinde araç–yaya etkileşimi yok, park ayrı alan olarak yok (meydanlar ve sahil dinlenme alanları kullanılıyor), bisikletli / tekerlekli sandalyeli kişi yok.
- Görsel revizyon 9 (A, 2026-11-01) · Araçlar, dekoratif trafik, toplu taşıma (yalnızca görsel; GameState, ekonomi, emisyon, nüfus, UI, autoload değişmedi):
  - Araç kütüphanesi: `scripts/world/dev/gen_vehicle_library.gd` → `assets/vehicles/` (8 model: şehir arabası 3,9 m, sedan 4,7 m, kompakt SUV 4,6 m, elektrikli 4,8 m, belediye otobüsü 11,1 m, minibüs 6,1 m, teslimat vanı 5,3 m, bisiklet 1,9 m). Yan profilden kalıplanan gövde + daha dar kabin, ön / arka cam şeritleri, yan camlar, farlar, stoplar, sinyaller, tamponlar, aynalar, kapı çizgileri, boş plakalar; ayrı tekerlekler (lastik + jant + kollar). Ön yön -Z, pivot zeminde. 9 renkli kontrollü palet (`VehicleLibrary.PAINT_COLORS`); otobüs belediye beyazı + turkuaz şerit, yazı / marka yok. Kenney Car Kit (CC0) değerlendirildi, kullanılmadı.
  - Trafik (`scripts/world/traffic.gd`, CityWorld/Traffic, autoload değil): eski kutu arabalar ve `city_decor` trafik kodu kaldırıldı. Ana cadde ve kuzey yolunda kapalı Path3D rotaları (sağdan akış, iki şerit, uçlarda yuvarlak U dönüşü — yeniden konumlama / ışınlanma yok), PathFollow3D ile 17 araç (12 cadde: otobüs, minibüs, van, 9 otomobil; 5 kuzey yolu). Basit takip: öndeki araca 2,2 birimde yavaşlar, 0,55'te durur (üst üste binmez); yaya geçidinde yaya varken bekler; otobüs belediye meydanı durağında 5 sn durur. Yumuşak hızlanma / fren, tekerlekler hızla orantılı döner (yalnızca yakın ve görünür araçlarda).
  - Yaya uyumu (`pedestrians.gd`): yayalar geçitte araç varken bekler (Idle), aynı şeritte arkadakiler araya mesafe bırakır. Kordona araç girmez.
  - Park: kuzey yolu otopark ceplerinde ve mahalle yollarının kenarında paralel park (27 araç; kaldırımda değil, geçit ağızları boş), tek birleşik mesh. Bisiklet rafları kütüphane bisikletiyle. Otobüs durağı (sundurma, bank, tabela, bekleyenler) ve ana caddenin üç kavşağında dekoratif trafik ışıkları (mantıksız, sabit).
  - Test: yeni `scripts/world/dev/test_traffic.gd` (18 kontrol; hızlandırılmış ~80 sn: yolda kalma, çakışmama, yön, tekerlek, otobüs durağı, yaya–araç çakışmaması, park yerleri, arsa tıklaması, ok tuşu, GameState aynı). A'nın 9 testi + B'nin 12 testi TAMAM.
  - FPS (Game.tscn 1080p, aynı oturumda önce → sonra; normal / 8 bina / kriz / sunum): Intel UHD 44 / 45 / 43 / 36 → 42 / 43 / 42 / 35; RTX 5060 243 / 237 / 222 / 187 → 231 / 228 / 216 / 175. Draw call +210.
  - Prompt 10'a kalanlar: bisiklet süren karakter yok (pakette sürüş animasyonu yok; yalnızca park edilmiş bisikletler), mahalle sokaklarında hareketli trafik yok (yalnızca park), trafik ışıkları dekoratif, araç farları gece için yok (oyunda gece yok), otobüs tekerlekleri gövde altında az görünüyor.
- Prompt A14 (A, 2026-11-01) · Sanayi işletmeleri ve baca dumanı (yalnızca görsel; işletme kurma, emisyon, ceza, denetim, kredi, UI B'de, değişmedi):
  - Sanayi yerleri I01–I08 (`scripts/world/industry.gd` → `SITES`): kuzey sanayi şeridi z −34,5, x ±12 / ±21 / ±30 / ±39; 6 × 6 beton saha, köşe direkleri, önünde servis yolu. Oyuncu arsaları, yollar ve rezervuarla çakışmaz (testte denetlenir); Decor bu alanlara ağaç koymaz. Kamera sınırı kuzeye genişletildi (`CameraRig.tscn` bounds z −28 → −36) ki şerit yakın zoom'da da gezilebilsin.
  - Modeller (`scripts/world/dev/gen_industrial_library.gd` → `assets/industrial/`): küçük üretim fabrikası (testere dişli çatı, iki katlı ofis, kepenk, tek baca), ağır sanayi tesisi (tuğla ana bina, çelik hol, iki bantlı baca, silolar, borular, konveyör), lojistik deposu (dört yükleme rampası, saçaklar, camlı ofis, havalandırma egzozu). Her modelde ayrı ışıklı pencere mesh'i, `Upgrade_clean_energy` (çatı güneş paneli) ve `Upgrade_treatment` (arıtma tankı).
  - 10 işletme türü 3 modele eşlenir (`MODEL_FOR_VISUAL`): SmallFactory / FoodFactory / TextilePlant / SmallWorkshop → küçük fabrika; HeavyFactory / ChemicalPlant / ConcretePlant / WasteFacility → ağır sanayi; LogisticsWarehouse / Commercial_EnergyIntensive → depo. B'nin `visual_id`'leri değişmeden kullanılır; B'nin `data/businesses/*.tres` dosyasında değişiklik gerekmez.
  - EventBus v1.10: `business_spawned` → model (aynı kimliğe ikinci model yok; `restored` ise animasyonsuz), `business_updated` → duman / ışık / yükseltme / uyarı, `business_removed` → kaldır. Sahne açılırken `GameState.businesses` doluysa oradan da kurulur.
  - Duman: baca başına `GPUParticles3D` (yükselir, rüzgârla kayar, büyür, saydamlaşır; ışıksız, gölgesiz; 5 sn ömür, en çok 40 parçacık). Yalnızca `smoke_intensity`'den: düşük açık ve seyrek, yüksek yoğun ve koyu gri; `filter` → beyaz, ince, saydam; `suspended` → duman yok, pencereler sönük; `violation_level` ≥ 3 → kırmızı "!" işareti.
  - Test: yeni `scripts/world/dev/test_industry.gd` (25 kontrol; B'nin gerçek akışı: `BusinessSimulator.create` + `_publish`, `inspect_business` → `order_business(suspend)` → `resume_business`; dumanın ekranda gerçekten hareket ettiği piksel farkıyla ölçülür) 1920x1080 ve 1280x720'de TAMAM. Görüntüler: `build/visual_reference/a14/`.
  - Kalan: 10 tür için ayrı model yok (3 model); kimya / beton / atık tesislerine özgü silüet sonra eklenebilir.
- Prompt A12 (A, 2026-11-01) · İnşaat gösterimi kamerası (yalnızca kamera; inşaat doğrulaması, ekonomi, UI değişmedi):
  - Tetik: mevcut `EventBus.build_approved` (yalnızca GameController onaylayınca gelir). `city_world.gd` binayı yerleştirdikten sonra `showcase_building(plot_id)` çağırır; açılışta GameState'ten geri kurulan binalar ve final sunumu gösterim yapmaz. B tarafında yeni sinyal ya da değişiklik gerekmedi.
  - `camera_rig.gd` `showcase(box)`: 0,9 sn yaklaşma (sinüs yumuşatma) → 2 sn gösterim → 0,9 sn önceki görünüme dönüş (~3,8 sn). Açı değişmez; hedef kamera sınırlarıyla kırpılır (kenardaki arsada en yakın kadraj). Tek Tween (`_glide`) kullanılır; yeni gösterim, `set_view`, `glide_to` eskisini öldürür (eski geri çağrılar çalışmaz). Art arda inşaatta en son yapı gösterilir, dönüş ilk görünüme olur.
  - Yakınlık bina boyutundan: kutu = binanın görsel parçalarının Model'e göre kutusu (büyüme animasyonundaki ölçekten bağımsız); kadraj = max(yatay kenar, 1,3 × yükseklik) + 2 m, × 3,2 → konut ~25, 8 m'lik güneş tesisi ~30; zoom_min (22) – zoom_max arası. Bina yoksa / silindiyse arsa karesi.
  - Oyuncu önceliği: gösterim sırasında WASD / ok tuşları, tekerlek, sol ya da orta sürükleme, arsa seçimi gösterimi o anki konum ve yakınlıkta bitirir (eski görünüme dönülmez, sıçrama yok). Arayüz tıklamaları kamerayı etkilemez.
  - Test: yeni `scripts/world/dev/test_showcase.gd` (23 kontrol, gerçek inşaat akışı: küçük / büyük / park, başarısız inşaat, dönüş, dört elle müdahale türü, kenar arsa ve art arda inşaat, silinmiş bina, sinematik mod, sonrasında seçim) 1920x1080 ve 1280x720'de TAMAM.
- Prompt A11 (A, 2026-11-01) · Sol tuşla harita sürükleme (yalnızca kamera / seçim girdisi; oyun mantığı, UI, project.godot değişmedi):
  - `camera_rig.gd`: sol tuş haritada basılıyken imleç 8 pikselden (viewport) fazla giderse sürükleme başlar; mevcut orta tuş sürüklemesiyle aynı "zemini tut" yöntemi (imlecin altındaki zemin noktası imleçle gider → yakın zoom'da az, uzakta çok kayar, açı ve yakınlık sabit). Eşik aşıldığında basıştan beri biriken hareket tek seferde uygulanır. Arayüzün tükettiği tıklamalar `_unhandled_input`'a gelmediği için panel / düğme / menü üstünde başlayan sürükleme haritayı oynatmaz; tuş arayüzde bırakılırsa sürükleme takılmaz (tuş maskesinden anlaşılır). Sürükleme artık sınırda durur (önceden orta tuşla sınırın dışına taşıp geri yaylanıyordu).
  - `city_world.gd`: arsa seçimi sol tuş **bırakılınca** yapılır (önceden basınca); bırakılan basış sürüklemeye dönüştüyse tıklama sayılmaz (`CameraRig.was_left_drag()`), sürüklenirken fare üstü vurgusu kapalı. B'nin testlerindeki bas–bırak tıklamaları aynı çalışır.
  - Test: `test_camera_nav.gd`'ye 12 sol sürükleme kontrolü (arsa üstünden sürükleme seçmiyor, titreşimli kısa tıklama seçiyor, arayüzde başlayan sürükleme, arayüzde bırakma, yakın/uzak zoom hassasiyeti, sınır, sürükleme sonrası tıklama); 1920x1080 ve 1280x720'de 30/30 TAMAM.
  - B için not: dokunmatik / kalem desteği yok (yalnızca fare). Seçimin bırakmada olması arayüz tarafında bir değişiklik gerektirmiyor.
- **Görsel revizyon 5 ve 6 · plan değişti (A, 2026-11-01):** İkisini de **A yapıyor** (önceki "B'ye devir" kararı iptal). B, `scripts/world/**`, `scenes/world/**`, `scenes/buildings/**`, `assets/materials/**` dosyalarında çalışmasın. Revizyon 6'nın arayüz kısmı (`scenes/ui`, `scripts/ui`, `assets/ui/theme.tres`) ve `project.godot` ayarları B'nin dosyaları: A önce ne değişeceğini PROGRESS'e yazar ve B ile anlaşır. Aşağıdaki notlar çalışma kaynağıdır.
  - Dekor (evler, yollar, ağaçlar, marina, trafik): `scripts/world/city_decor.gd`, sabit seed + MultiMesh, sahneye kaydedilmez. Ortak bina paleti `assets/materials/buildings/bld_*.tres`; dekor hâlâ eski, daha doygun `assets/materials/*.tres` paletini kullanıyor.
  - Arsalar: `scenes/world/BuildPlot.tscn` + `scripts/world/build_plot.gd` (Pad zemini, VisualOverlay/Highlight çerçeve, DebugOverlay etiket). Vurgu durumları `highlight_state()`; `_selected` B'nin test_integration'ı için korunmalı.
  - Bina modelleri elle düzenlenmez: `py scripts/world/dev/gen_buildings.py .` (arsa sınırı, zemin, yükseklik standardı denetlenir), küçük resimler `scripts/world/dev/render_thumbnails.gd`.
  - Işık/kamera: `scenes/world/CityWorld.tscn` (Environment, Sun, CameraRig dönüşü), `scenes/world/CameraRig.tscn`; `camera_rig.gd` zoom'u kamera uzaklığıyla yapar (ortografik için script değişmeli).
  - Revizyon 4'te görülen eksikler (5 için): dekor evlerinin yan cepheleri boş (yeni açıda görünüyor), yollarda kaldırım/bordür/yaya geçidi/sokak ağacı yok, boş arsalar düz bej kare, araçlar iki kutu, kordon düz.
  - Revizyon 6 için: kenar yumuşatma (MSAA), yumuşak gölge filtre kalitesi, SSAO kalite ayarları `project.godot`'ta varsayılan (görsel olarak en büyük kalan kazanç).
  - Görsel kontrol: önce/sonra görüntüleri A'nın bilgisayarında `build/visual_reference/` (git dışında). Testler: B'nin 12 testi + `scripts/world/dev/test_*.gd` (7 test; `test_final_presentation` ~2,5 dk, `test_plot_visuals` gerçek fare olaylarıyla). FPS: aynı dizüstünün Intel UHD'si (`--gpu-index 1`) zayıf kart ölçüsü olarak kullanıldı.

### Ekip B
- [x] 12 `BuildingDefinition` + bilgi kartları
- [x] ClimateSimulator (sektör emisyonları, riskler, ekosistem, CO2 okuma)
- [~] `co2_scenario.tres`: NOAA 1959–2025 ölçümü eklendi; 2040–2052 senaryo değeri yok (oyun "veri yok" gösterir)
- [x] EventManager + 3 `EventDefinition` + müdahaleler
- [x] TurnManager kriz fazı
- [x] EventPanel, HUD uyarı listesi
- [x] ClimateLab ve LineChart

### Gün 2 notları (B)
- Testler: `test_day1_flow.gd` ve `test_day2_flow.gd`, ikisi de TAMAM.
- 12 binanın `scene` alanı A'nın `b_<id>.tscn` sahnelerine bağlandı (2026-10-31).
- Kriz takvimi (demo): sıcak hava 2043, kuraklık 2046, kıyı taşkını 2049. Uyarı bir yıl önce gelir.
- Bilgi kartları nitel; kaynak satırları boş. Sunumdan önce her karta kaynak eklenmeli (özellikle "Akdeniz havzası" cümlesi için IPCC AR6).
- A için: `crisis_started(event_id, risk_type, severity)` ve `crisis_resolved(result)` yayılıyor, efektler bağlanabilir.

## Gün 3 · Cila ve teslim

Öğlen 12:00 özellik dondurma. Sonrası yalnızca hata düzeltme ve denge.

- [x] A: ışık/gölge cilası, kamera hissi, performans testi (yalnızca RTX 5060 dizüstünde; orta seviye PC testi kaldı)
- [x] B: denge (5 stratejili simülasyon, GAME_DESIGN §9), görevler (4 görev), arayüz teması (ilerleme çubukları)
- [~] Birlikte: uçtan uca test ✓ (test_playthrough), final sunumu ✓ (A 10B, B entegrasyonu), Windows export ✓ (build/, 10B dahil yeniden üretildi); kalan: `main`'e son birleştirme ve `v1.0` etiketi
- [x] Sunum için 2 dakikalık demo senaryosu (aşağıda; krizler sabit yıllı, seed gerekmez)

---

### Demo senaryosu (2 dakika, script ile doğrulandı)

1. Ana menü → **Yeni oyun**.
2. 2040: O01'e **Güneş enerjisi tesisi**, U01'e **Yeşil park**. Bilgi kartını göster. → **Yılı bitir**, raporda emisyon düşüşü.
3. 2041: O02'ye **Su depolama**. → Yılı bitir.
4. 2042: Yılı bitir. Raporda **2043 sıcak hava dalgası uyarısı**; HUD'da uyarı satırı.
5. 2043: U02'ye **İklim serinleme merkezi** (hazırlık). → Yılı bitir → **kriz paneli**: "Yatırımların hasarı %60 azaltacak". "Serinleme alanlarını aç" seç. Raporda hasar yalnızca −84 kredi.
6. **İklim Laboratuvarı**: Yerel emisyonlar grafiği → Küresel CO2 (NOAA ölçümü, "şehrin bu eğriyi tek başına değiştiremez") → Yerel riskler.

### Gün 3 notları (B)
- Emisyon bonusu kişi başı emisyona göre (büyüyen şehir cezalandırılmıyor).
- Sözleşme v1.1: rapora `missions`, final özetine `emission_reduction_pct` eklendi (yalnızca ekleme, A etkilenmez).
- `export_presets.cfg` hazır; Windows export'u için 4.7.2 şablonları gerekir.

### Prompt 2-4 notları (B, 2026-10-31)
- Prompt 2: Ana menüye OYUN HAKKINDA penceresi, arkada Ekip A'nın şehri (girdiye kapalı), giriş animasyonu. `tests/test_menu.gd` TAMAM. Mimari çelişkiler raporlandı; mevcut yapı korundu.
- Prompt 3: Ekip A'nın işi; salt okunur kontrol edildi (15 kriterin 13'ü tam). A için açık: belediye binası + meydan, ağaçlarda rüzgâr, isteğe bağlı MultiMesh, orta seviye PC'de FPS.
- Prompt 4: Enerji/su akışları ve yenilenebilir payı eklendi (sözleşme v1.2). `tests/test_economy.gd` Prompt 4'ün 12 testini gerçek denge değerleriyle çalıştırır: TAMAM. Talimattaki örnek maliyetler (güneş 250, su 200) yerine denge simülasyonundaki değerler (400, 250) korundu; `construction_turns` yok, inşaat anlık.
- Bilinen: kredi bilinçli olarak eksiye düşebilir (borç; o yıl yaşam −5). Endeksler 0–100, nüfus ≥ 0.

### Prompt 5 notları (B, 2026-10-31) · Arayüz
- HUD üç bölüm: üst bar (logo, yıl ilerlemesi, animasyonlu bütçe, nüfus), sol kaynak paneli (ikon, değer, çubuk, renk + durum yazısı; enerji ve su için üretim/talep), alt menü (İnşaat, İklim Laboratuvarı, Şehir bilgileri, Son rapor, Ayarlar, Ana menü, Yılı bitir).
- BuildPanel: bina küçük resmi, ad, açıklama, maliyet, gider, arsa türü, etki etiketleri; seçilince Temel fayda / İklim bağlantısı / Stratejik avantaj + açılır ayrıntılı bilgi. Yetersiz bütçede düğme kapalı ve neden yazılı.
- Yeni: bildirimler, Şehir bilgileri, Ayarlar (tam ekran, V-Sync), "Son rapor". İklim Laboratuvarı'na Enerji ve su, Ekosistem sekmeleri; emisyonda önceki yıla göre değişim ve yatırım etkileri. Yıl sonu raporu tablo hâlinde.
- `tests/test_ui.gd`: 20 kabul kriteri, 1280×720 ve 1920×1080'de TAMAM. Diğer 5 test ve denge simülasyonu değişmedi.
- A için: BuildPanel kapanınca arsa vurgusu kalıyor (`plot_deselected` A'nın). İstenirse sözleşmeye "arayüz seçimi bırak" isteği eklenebilir.
- Sözleşme değişikliği yok.

### Prompt 6 notları (B, 2026-10-31) · Tam entegrasyon
- Denetim: sinyaller, fonksiyon imzaları, node yolları, 15 arsa kimliği (benzersiz, sözleşme §7 ile aynı), 12 bina sahnesi ↔ BuildingDefinition uyumlu. A ve UI GameState'e yazmıyor.
- Eklenen: GameController kontrol zincirine `scene_unavailable` ve `unknown_plot` (sözleşme v1.4, işlem durum değişmeden reddedilir = bölünmez); emisyonlar ve enerji/su akışları inşaatta hemen güncelleniyor (`ClimateSimulator.compute_emissions`); HUD'a Yerel emisyon kartı ve enerji dengesi; Türkçe ret mesajları talimattaki ifadelere çekildi.
- `tests/test_integration.gd`: Prompt 6'nın 17 senaryosu (21 kontrol) 1280×720 ve 1920×1080'de TAMAM, konsolda hata/uyarı yok. Diğer 6 test ve denge simülasyonu değişmedi.
- Bilerek korunan: arsa türleri urban/open/coastal (talimattaki enerji/su/yeşil/kıyı değil), maliyetler 400/250/150 (talimattaki 250/200/150 "örnek").

### Prompt 7A notları (B, 2026-10-31) · Kriz sistemi
- Mevcut yaşam döngüsü korundu (uyarı → hazırlık yılı → kriz → müdahale → sonuç → rapor); eklenenler:
  - Hasar = taban × tehlike × maruziyet × hassasiyet × (1 − uyum) × müdahale (GAME_DESIGN §6). Şiddet artık yatırımdan bağımsız ham riskten; uyum iki kez sayılmıyor.
  - Altyapıya bağlı müdahaleler (su deposu, kent tarımı, serinleme merkezi, park, kıyı restorasyonu). Müdahale bütçe/altyapı kontrolü artık TurnManager'da da var (geçersiz seçim durumu değiştirmez).
  - Sıcak hava enerji güvenliğini düşürür. Uyarı metinleri talimattaki cümleler.
  - Kriz paneli: risk seviyesi, hasar dökümü, yatırım avantajları, seçenek → olası etkiler → onay. HUD uyarısında kalan hazırlık süresi.
  - Sözleşme v1.5: `crisis_stage_changed` (A için isteğe bağlı).
- `tests/test_crises.gd`: 12 test sorusu (22 kontrol) TAMAM. Diğer 7 test TAMAM. Denge: hiçbir şey 38, koruyucu 77, karma 81; hazırlıklı şehrin kriz kaybı 145, hazırlıksızın 472.
- Kriz yılları sabit (2043, 2046, 2049): sonuç tekrarlanabilir, oyuncu sürekli felaketle cezalandırılmaz.

### Bilgi kartı kaynakları (B, 2026-10-31)
- 16 kartın 14'üne kaynak eklendi: IEA (güneş, binalar, ulaşım), US EPA (ısı adası, su geri kazanımı, kompost/gıda atığı), WHO (sıcak ve sağlık), UNCCD (kuraklık), FAO (tarım suyu), NOAA GML (CO2). Her adres 2026-10-31'de açıldı; başlık ve içerik kartın konusuyla karşılaştırıldı.
- Sıcak hava kartındaki "Akdeniz havzası en çok etkilenen bölgeler arasında" cümlesi çıkarıldı: WHO sayfasında yok, IPCC sayfaları otomatik erişime kapalı olduğu için doğrulanamadı.
- İki kıyı kartına (`card_coastal_restoration`, `card_event_coastal_flood`) IPCC SROCC (2019) eklendi; sayfa otomatik erişime kapalı olduğu için B geliştiricisi tarayıcıda açıp başlığı doğruladı. Artık 16 kartın hepsi kaynaklı; kartlarda sayı yok.
- Akdeniz cümlesi çıkarılmış durumda; geri eklemek için IPCC AR6 WGII CCP4 (https://www.ipcc.ch/report/ar6/wg2/chapter/ccp4/) tarayıcıda doğrulanmalı.

### Prompt 8 notları (B, 2026-10-31) · İklim Laboratuvarı ve eğitim
- Laboratuvar 6 sekme: A Emisyonlar (endeks, son yıl ve başlangıca göre değişim, yenilenebilir pay, birikimli göreli azaltım, sektör çizgi + dağılım sütun grafiği, "neden değişti"), B Küresel CO₂ (NOAA 1959–2025, BİLİMSEL ÖLÇÜM etiketi, gelecek senaryosu yok notu, ölçek farkı, 7 kavram), C Kaynaklar (enerji, su, atık, ekosistem), D Riskler ve dayanıklılık (EventManager/ClimateSimulator değerleri, ilgili yatırımlar, açılan müdahaleler, uyarı, son kriz, öneri), Sözlük (17 kavram), Öğrenme (5 görev + ilerleme). Her grafikte başlık, birim, dönem, veri türü etiketi.
- Simülasyonda olmayan veriler uydurulmadı ve açıkça yazıldı: toplam atık miktarı (ton), su rezervi ve su verimliliği, "diğer şehir faaliyetleri" sektörü, 2040–2052 CO₂ senaryosu.
- Eğitim kartı: yatırım ilk kez yapıldığında küçük, kapatılabilir kart; aynı kart bir oyunda bir kez. HUD'a "Bilgi arşivi" düğmesi. Final ekranında başlangıç ↔ final tablosu (sözleşme v1.7) ve öğrenme özeti.
- Öğrenme görevleri kredi vermez (denge: 10 kredi bile basit stratejileri 85 puana taşıdı). Krizler GameState.crisis_log'a kaydediliyor (Laboratuvar D ve Şehir bilgileri okur).
- `tests/test_education.gd`: Prompt 8'in 20 testi (23 kontrol) 1280×720 ve 1920×1080'de TAMAM.

### Prompt 9A notları (B, 2026-10-31) · 12 yatırım ve kombinasyonlar
- 12 yatırımın hepsi zaten veri, sahne, küçük resim, bilgi kartı ve kaynakla çalışıyordu; ilk üçü dokunulmadan korundu.
- Eklenen: 6 kombinasyon (SynergyDefinition, tek hesap yolu), geri kazanılmış suyun içme suyundan ayrılması (sözleşme v1.8), `Catalog.validate()`, kamu verimliliğine sıcak koruması, kıyı yatırımının iki bileşeni, BuildPanel kartında tema + kombinasyon durumu, Laboratuvar C'de kombinasyon listesi ve geri kazanılmış su.
- Denge: kombinasyonlar ucuz-önce stratejisini 87'ye çıkardı; hedef ödülleri 50'ye indirildi → hiçbir otomatik strateji "İklim Lideri"ne ulaşmıyor (38/78/78/69/79), en fazla 10 bina.
- Bilerek değişmeyen: arsa türleri urban/open/coastal (A'nın haritası, sözleşme §7), inşaat anlık (`construction_turns` yok), mevcut dosya adları.
- Ekip A için yeni model gerekmiyor: 12 bina sahnesi mevcut (`scenes/buildings/b_<id>.tscn`); kombinasyonların görseli yok.
- `tests/test_investments.gd`: 18 test sorusu (25 kontrol) TAMAM.

### Prompt 10A notları (B, 2026-10-31) · Final simülasyon ve değerlendirme
- Yıllık arşiv: `GameState.year_reports` (her yılın raporu), `build_log` (yatırım, yıl, maliyet), `crisis_log`; `history` zaten vardı. Yeni göstergeler: `waste_recovery`, `climate_resilience` (merkezi, ClimateSimulator).
- `FinalEvaluator`: 7 alt puan + ağırlıklı genel puan, 2040 ↔ 2052 karşılaştırması (yön ve yüzde, sıfıra bölme yok), toplamlar; eski tek formül kaldırıldı. Not ve sonuç metni puana göre değişir.
- `FinalReport` paneli: genel değerlendirme, alt puan grafiği, karşılaştırma tablosu, Ekonomi/Enerji/Su/Ekosistem/İklim ve afetler/Yatırımlar bölümleri, 4 grafik, JSON dışa aktarma (`user://reports/`). YearReport artık yalnızca yıllık rapor.
- Düzeltilen hata: 2040 başlangıç kaydı enerji/su akışları hesaplanmadan alınıyordu.
- Sözleşme v1.9 + `docs/FINAL_VISUAL_CONTRACT.md`: final sunum sinyalleri, `city_2040`/`city_2052`, kabul ölçütleri. Sunum bitiş sinyali gelmezse Esc / 120 sn yedeği.
- `tests/test_final.gd` 30 kontrol TAMAM.
- **Ekip A için iş listesi:** (1) `final_presentation_requested(summary)`'i dinle, (2) 2040 görünümü (binasız) ↔ 2052 yerleşimi (`city_2052.plots`, `builds[].year`) geçişi, (3) kamera turu, (4) isteğe bağlı: `GameState.crisis_log`'dan geçmiş krizlerin kısa tekrarı, (5) bitişte `final_presentation_finished`. Ayrıntı: FINAL_VISUAL_CONTRACT.md.

### Prompt 10C notları (B, 2026-10-31) · Final entegrasyon, kalite, Windows demo
- GitHub: Ekip A'nın 10B'si henüz yok (`feature/city-world` = develop). 10C'nin final sunum kısmı onu bekliyor; geri kalanı tamam.
- Testler: B'nin 12 testi (pencereliler 1280×720 ve 1920×1080) + A'nın 4 şehir testi TAMAM. Yeni `tests/test_playthrough.gd`: gerçek oyuncu gibi menüden 2052'ye (6 yatırım, 3 kriz panelden, Laboratuvar 6 sekme, final raporu); konsolda hata/uyarı yok.
- Bulunan ve düzeltilen hata (yüksek): BuildPanel'de alttaki kartlar ayrıntı alanının arkasında kalıyordu (kent arsasında park ve serinleme merkezi tıklanamıyordu). Seçim yokken ayrıntı gizlenir; seçilen kart görünür alana kaydırılır.
- Senaryolar (balance_sim): A sürdürülebilir 74, B ekonomik büyüme 41 (ekonomi 100 ama uyum 4, en büyük kriz kaybı), C hazırlıksız 37, D dengeli 67. Not: hiç harcamayan strateji ekonomi alt puanında 100 alır; ağırlığı %15 olduğu için genel puan yine en düşük.
- Performans (bu Mac, M5, 1280×720, vsync kapalı): kriz anında ~234 FPS. Orta seviye Windows PC ölçümü A'da.
- Windows demo: `build/windows/ANTALYA2040.exe` (110 MB, PCK gömülü) + `OKUBENI.txt`, `build/ANTALYA2040_Windows_Demo.zip` (38 MB). Paket Mac'te `--main-pack` ile proje klasörü olmadan 2052'ye kadar oynandı, hata yok. .exe'nin Windows'ta çalıştırılması A'da.
- Düşük: headless/çıkışta görülen "RID leaked at exit" satırları kapanış sırasında; oyun sırasında hata yok.

### Prompt 10B entegrasyonu (B, 2026-10-31)
- A'nın 10B'si (PR #18, develop 10a1c98) `feature/simulation-ui`'ye birleştirildi (f7a1456), çakışma yok. A yalnızca kendi dosyalarına dokunmuş (scripts/world, assets/shaders, PROGRESS A bölümü).
- Testler: B'nin 12 testi (pencereliler 1280×720 ve 1920×1080) + A'nın 5 testi (test_city, test_city_fx, test_buildings, test_deselect_real, test_final_presentation 29 kontrol) TAMAM. balance_sim sonuçları 10C ile aynı (74 / 41 / 37 / 67).
- Gerçek pencerede tam oyun + "Şehrin dönüşümünü izle" (1280×720 ve 1920×1080): düğme görünür, sunum ~54 sn (2040 binasız → yıl yıl yatırımlar ve krizler → 2052 → karşılaştırma), bitişte rapor geri geliyor, GameState değişmiyor, kamera eski görünüme dönüyor, arayüzle çakışma yok. FINAL_VISUAL_CONTRACT kabul ölçütlerinin 6'sı da sağlandı (hiç yatırım yok durumu A'nın testinde).
- Windows demo yeniden üretildi (10B dahil): `build/windows/ANTALYA2040.exe` (110 MB) + `OKUBENI.txt`, `build/ANTALYA2040_Windows_Demo.zip` (38 MB). Pakette final_presentation var, tests/ ve dev/ yok; `--main-pack` ile açılıyor, script hatası yok.
- A'ya not (düşük): `test_final_presentation.gd` 1920×1080'de bir kez [6] kenar durumlarında 3 kontrol düşürdü, iki tekrarda TAMAM. Zamanlamaya bağlı titreklik; oyunda karşılığı görülmedi.

### Prompt 10 · Görsel cila (B, Ekip A adına, 2026-11-01, dal `feature/visual-polish`)
Emre'nin kredisi bittiği için kullanıcı kararıyla B yaptı. Ayrı dalda ve PR ile; Emre incelesin. Çalışan sistem yeniden yazılmadı, yalnızca ölçülen sorunlar düzeltildi.
- **Denetim** (gerçek Game.tscn, 1920×1080, 12 görünüm, yakın/orta/uzak zoom): debug yazısı, havada/gömülü model, kara-deniz sınırı sorunu görülmedi. Ölçek tutarlı: 1 birim ≈ 2,3 m (kat 1,4); sedan 2,06 birim ≈ 4,7 m, otobüs 4,84 ≈ 11 m, yaya 0,75–0,89 ≈ 1,75–2 m.
- **Kenar yumuşatma** (`project.godot`, B dosyası): SMAA açıldı (`anti_aliasing/quality/screen_space_aa=2`). Final sunumu SubViewport'u ayarı ana görünümden kopyalıyor. Bu Mac'te (M5, 1920×1080, vsync kapalı, uzak/orta/yakın) denenenler: ayarsız 116/106/99, FXAA 112/103/96 (bulanık), SMAA 107/99/93, MSAA 2x/4x %20–25 düşüş. MSAA zayıf kartta (Intel UHD 1080p ~42–57) 40'ın altına indirebileceği için seçilmedi.
- **Otobüs tekerlekleri** (`gen_vehicle_library.gd` → `city_bus.tscn`, `city_bus_body.tres`): tekerlekler gövdenin içindeydi (x 0,47; gövde yarı genişliği 0,545) ve tam boy alt kaplama onları örtüyordu. Tekerlekler x 0,51'e alındı, alt kaplamada tekerlek boşlukları açıldı. Diğer araç dosyaları yeniden üretimde yalnızca kimlik/sayı gürültüsü değiştiği için geri alındı.
- **Tekrar eden binalar** (`city_decor.gd`): dükkân sırasında aynı model art arda 5 kez geliyordu. `_pick_model` komşuyla aynı modeli seçmez (havuzda başka yoksa aynısı kalır).
- **Boş cadde önü** (`city_decor.gd`, `_frontage_tree`): ana cadde kaldırımı ile dükkân cephesi arasında 2,4 birimden geniş boşluk kalırsa ortasına küçük zeytin ağacı. Yaya rotaları kaldırımda olduğu için rotaya girmez.
- **Final sunumu alt yazısı** (`final_presentation.gd`): parlak zeminde zor okunuyordu; kontur koyulaştı, yumuşak koyu gölge eklendi.
- **Headless hata** (`pedestrians.gd`): pencere olmadan 41 kez "skin registered with a valid skeleton" + `get_surface_count on null` yazıyordu. Headless'ta bake atlanır, ayrıca null kontrolü var. Pencereli oyun değişmedi.
- **FPS sonrası** (bu Mac, SMAA dahil): 1920×1080 108/100/93, 1280×720 171/150/162. Intel UHD'de ölçülmedi (Windows gerekir; Emre ölçebilir).
- **Testler:** B'nin 12 + A'nın 9 testi 1280×720 ve 1920×1080'de, 34 çalıştırmanın hepsi TAMAM; balance_sim değişmedi. Gerçek pencerede final sunumu: düğme görünür, ~55 sn, rapor geri geliyor, GameState ve kamera değişmiyor.
- **Ekran görüntüleri** (gerçek oyun, arayüz gizli, 1920×1080, JPG): `docs/screenshots/01_city_overview.jpg`, `02_coastal_promenade.jpg`, `03_urban_district.jpg`, `04_public_space.jpg`, `05_city_life.jpg`, `06_closeup_architecture.jpg` (klasörde `.gdignore`: oyun paketine girmez).
- **Yapılmadı / test edilmedi:** ışık ve atmosfer ayarları değiştirilmedi (görsel revizyon 3 sonucu korunuyor); LOD eklenmedi (FPS yeterli, ölçülmüş bir darboğaz yok); bisiklet süren karakter, mahalle sokaklarında hareketli trafik ve trafik ışıklarının trafiği yönetmesi hâlâ yok (Emre'nin notu); yayaların birbirinin içinden geçip geçmediği yalnızca A'nın `test_pedestrians.gd`'si ve görüntülerle kontrol edildi; Windows'ta çalıştırılmadı.

### Prompt 13 notları (B, 2026-11-01) · İşletmeler, çevre denetimi, kayıt
- Ayrıntı: `docs/BUSINESS_SYSTEM.md`; sözleşme v1.10 (§3.5 üç yeni sinyal, `stats.air_pollution/waste_pollution`, `emissions_by_sector.industry`, rapor alanları).
- Kullanıcı kararları: işletmeler oyuncunun 15 arsasına değil ayrı **sanayi yerlerine** (I01–I08) kurulur; konumları Ekip A belirler. Projede kayıt sistemi yoktu; **bütün oyun için kayıt** kuruldu.
- 10 işletme türü (`data/businesses/`), ay ay kendiliğinden kurulma (nüfus, boş yer, doluluk, hava kirliliği tavanı, su durumu, lojistik ihtiyacı), en çok 8 işletme. Katkı tek para birimi kredi olarak gelire ve ay ay bütçeye eklenir.
- Sera gazı karbon salımına "Sanayi" kalemi olarak eklenir; yerel hava kirliliği ve atık yükü ayrı endeksler (yaşam kalitesi ve doğa yıllık düşer). Küresel CO₂ ölçümü değişmez.
- Denetim: ayda 3 ücretsiz hak, ek denetim 20 kredi, aynı işletme 3 ayda bir. İhlal verilerden (hava/atık ÷ oyun standardı). Ceza ihlale bir kez ve işletme başına yılda bir kez; kirliliği azaltmaz. Kararlar: filtre, temiz enerji, atık arıtma (sıfırlamaz, %60 azaltır), süre ver, faaliyeti durdur / yeniden aç.
- Denge ölçümü (ay ay 13 yıl, `bizsim`): ilk ölçümde her ay denetleyip ceza kesen oyuncu yılda 135–285 kredi topluyordu (işletme gelirinden fazla). Taban ceza 15 → 5, tavan 250 → 120, yılda bir ceza sınırı; sonra yılda 5–15 kredi. Kirlilik etkisi 0,06/0,05 → 0,03/0,03. Pasif oyunda 13 yılda ~5 işletme, yılda ~135 kredi katkı, yaşam kalitesi ~12 puan daha düşük. `balance_sim.gd` yıl yıl ilerlediği için işletme kurmaz; eski senaryo sonuçları değişmedi.
- Kayıt: `user://antalya2040_save.dat` (ikili, sürüm 1, nesne yüklenmez). Her Ocak ve ana menüye dönerken otomatik; oyun bitince silinir; ana menüde "DEVAM ET". Yalnızca build fazında kaydedilir (ceza/ödül çoğalmaz). Testler (`--script`) oyuncunun kaydına dokunmaz.
- Arayüz: HUD "Sanayi" düğmesi → İşletmeler ve çevre denetimi paneli (liste, ayrıntı, denetim, ceza, kararlar); bildirimler; yıl sonu raporunda işletme geliri, çevre cezaları, ek denetimler; Laboratuvar karbon grafiklerinde "Sanayi".
- Testler: yeni `tests/test_businesses.gd` (promptun 16 senaryosu + kayıt/yükleme) TAMAM; B'nin 13 testi + A'nın 10 testi iki çözünürlükte TAMAM. `test_ui` emisyon grafiği 5 kaleme, `test_months` rapor toplamı ceza/denetim satırlarına uyarlandı. `test_integration` ve `test_playthrough` Ekip A12 inşaat gösterimi bitene kadar bekliyor (tıklama ıskalıyordu).
- Ekip A için: sanayi yerlerinin konumu ve 10 modelin eşleştirmesi (`visual_id`), `business_spawned/updated/removed` dinleyicisi, duman `smoke_intensity`'den. Ayrıntı: BUSINESS_SYSTEM.md §8.

### Prompt 15 notları (B, 2026-11-01) · Sanayi görsel entegrasyonu
- Ekip A'nın A14'ü (PR #32, develop b160ca0) `feature/simulation-ui`'ye birleştirildi (fast-forward). A yalnızca kendi dosyalarına ve PROGRESS/ASSET_LICENSES'taki kendi satırlarına dokunmuş.
- Entegrasyon için B'de kod değişikliği gerekmedi: A'nın `scripts/world/industry.gd` dosyası sözleşme v1.10'u birebir kullanıyor. `business_spawned` → model, `business_updated` → duman/ışık/uyarı, `business_removed` → kaldır; kayıttan yüklemede `GameState.businesses`'tan kurar. Duman yalnızca `smoke_intensity`'den; filtre → beyaz duman, `suspended` → duman yok.
- Model eşleşmesi (A'nın `MODEL_FOR_VISUAL`, B'nin `visual_id`'leri değişmedi):
  - `assets/industrial/small_factory.tscn` ← küçük fabrika, gıda, tekstil, atölye
  - `assets/industrial/heavy_factory.tscn` ← ağır sanayi, kimya, beton, atık işleme
  - `assets/industrial/logistics_warehouse.tscn` ← lojistik deposu, soğuk depolu alışveriş merkezi
- Testler (her biri bir kez): A'nın `test_industry.gd` (B'nin gerçek akışıyla; 1280×720) 25/25 TAMAM: doğru model, duman ekranda hareket ediyor, düşük yoğunlukta açık duman, filtrede beyaz, faaliyet durunca duman kesiliyor, yeniden açılınca ışıklar yanıyor, kayıttan yükleme. B'nin `test_businesses.gd` TAMAM. Gerçek oyunda aylık kurulma (`business_month`) atık tesisi ve ağır sanayiyi kuzey sanayi şeridinde dumanıyla gösterdi. Oyun sahnesi hatasız açılıyor.
- Eksik: haritada fabrikaya tıklayıp seçme yok; A'nın sanayi görselinde çarpışma şekli yok, B'de dünya ışını yok. İşletme seçimi bugün HUD "Sanayi" panelinden yapılıyor (ad, tür, emisyon, uygunluk, denetimler, kararlar). 10 tür 3 modeli paylaşıyor. Tam test turu teslim sonrasına bırakıldı.

### Prompt 16 notları (B, 2026-11-01) · Final entegrasyon ve teslim
- Entegrasyon: iki ekibin bütün işleri main'de (v1.2, 0a41116). feature/city-world'de main dışında commit yok; çakışma yok.
- Testler (her biri bir kez, Mac M5, 1280×720):
  - açılış ve ana döngü: `test_menu`, `test_playthrough` (menüden 2052 finaline) TAMAM
  - kamera: `test_camera_nav` (WASD, ok tuşları, sol ve orta tuşla sürükleme, tekerlek, sınırlar) ve `test_showcase` (inşaat sonrası yakınlaştırma, elle müdahale) TAMAM
  - arayüz: `test_ui` TAMAM
  - takvim ve ekonomi: `test_months` TAMAM
  - işletme ve görsel: aynı kodda az önce `test_industry` 25/25 ve `test_businesses` TAMAM
- Quiz sistemi (aylık quiz, kredi kurtarma sınavı, quiz çözülmeden ay geçişini engelleme) **projede yok**; son dakikada eklenmedi.
- Ekran görüntüleri: `docs/screenshots/final/` (7 adet, gerçek oyun, 1920×1080). İşletmelerin hemen kurulması için nüfus elle 620 yapıldı; bu yüzden görüntülerde karbon 135.
- Teslim: GitHub Release v1.2 (`ANTALYA2040_Windows_v1.2.zip`). Yerel klasör `build/ANTALYA2040_Teslim/` (exe, OKUBENI.txt, ekran görüntüleri).
- Windows build Mac'te üretildi ve `--main-pack` ile pencerede hatasız açıldı. **Windows'ta çalıştırılmadı.**
- Bilinen eksikler: quiz sistemi; haritada fabrikaya tıklayarak seçme (işletmelere "Sanayi" panelinden ulaşılıyor); 10 tür 3 modeli paylaşıyor; Windows ve zayıf ekran kartında FPS ölçülmedi.

### Teslim hotfix (B, 2026-11-01 23:15) · Zorunlu iklim sorusu
- `scripts/ui/climate_quiz.gd` (HUD tarafından arayüzün en üstüne eklenir): her ay geçişinden (MonthClock) ve "Yıl sonuna atla"dan önce tam ekran soru. Doğru cevap verilmeden ay ilerlemez; yanlışta doğru cevap ve açıklama gösterilir, tekrar denenir; Esc, panel kapatma ve arkadaki düğmeler atlatmaz. Doğru cevaptan sonra geçiş bir kez çalışır.
- 10 soruluk banka (soru, 4 seçenek, doğru indeks, açıklama ayrı alanlar); sıra rng_seed + sayaçla döner. Bir ayda çözülen soru o ay yeniden sorulmaz. `GameState.quiz_count / quiz_done_key` kayda girer.
- Test (bir kez, gerçek Game.tscn): açılıyor, yanlışta ay geçmiyor, Esc/panel atlatmıyor, doğruda ay 1 → 2, sonraki ayda yeni soru. `--script` testlerinde quiz kapalı; test_months, test_businesses, test_day1 TAMAM.

### Jüri demo akışı (5–7 dk, sabit kriz yılları, ek demo modu gerekmez)
1. Giriş (30 sn): ana menü, arkada canlı şehir; "Oyun hakkında".
2. 2040 şehri (45 sn): HUD; kaynak paneli, enerji üretim/tüketim, yerel emisyon.
3. Yatırım (1 dk): O01'e güneş, U01'e park; kartta etki ve eğitim özeti, bütçe düşer, bilgi kartı çıkar, emisyon hemen düşer.
4. İklim Laboratuvarı (1 dk): A emisyonlar → B küresel CO₂ ("şehrin bu eğriyi tek başına değiştiremez") → D riskler ve öneri.
5. Afet (1,5 dk): 2042 sonu uyarı → 2043'te serinleme merkezi (hazırlık) → kriz paneli: koruma %70, "Serinleme merkezlerini devreye al", olası etkiler → rapor.
6. Final dönüşümü (1 dk): yılları ilerlet (2046, 2049 krizleri), 2052 → "Şehrin dönüşümünü izle" (~55 sn; Esc ile atlanır).
7. Sonuç raporu (45 sn): genel puan, en güçlü/zayıf alan, 2040↔2052 tablosu, grafikler; ana mesaj.

## Sözleşme değişiklik talepleri

| Tarih | İsteyen | Değişiklik | Onay | Durum |
|---|---|---|---|---|
| 2026-10-31 | B | v1.5: `crisis_stage_changed` + `result.severity/assessment` (ekleme) | A'nın kullanması isteğe bağlı | Yapıldı |
| 2026-10-31 | B | v1.4: ret nedenleri `scene_unavailable`, `unknown_plot` (ekleme) | B içi, A ret nedenlerini kullanmaz | Yapıldı |
| 2026-10-31 | B | v1.9: final sunum sinyalleri, summary/report/stats eklemeleri (ekleme) | A'nın kullanması isteğe bağlı; final sunum için A'ya iş listesi | Yapıldı |
| 2026-10-31 | B | v1.8: `stats.recycled_water`, `recycled_water_used` (ekleme) | B içi | Yapıldı |
| 2026-10-31 | B | v1.7: `summary.start_stats` (ekleme) | B içi | Yapıldı |
| 2026-10-31 | A | v1.6: `crisis_stage_changed` info'suna `mitigation` (0..0.8, o risk için yatırımların koruma oranı) ve `advantages` (koruma sağlayan bina kimlikleri). Neden: Prompt 7B koruma düzeyini görselde B'nin değerinden almayı istiyor; şu an yalnızca `crisis_resolved` sonucunda var. | B onayladı | B ekledi (2026-10-31) |
| 2026-10-31 | B (öneri) | v1.3: `plot_deselect_requested` (parametresiz). Yayan: B · BuildPanel (kapat düğmesi, Esc). Dinleyen: A · CityWorld → seçimi bırakır ve `plot_deselected` yayar. Neden: panel kapanınca arsa vurgusu kalıyor. | A onayladı (2026-10-31) | B ekledi (2026-10-31); A'nın CityWorld'de dinlemesi bekleniyor |
| 2026-10-31 | B | v1.2: `stats` enerji/su akışları (ekleme) | B içi, A etkilenmez | Yapıldı |
| 2026-10-30 | B | v1.1: `report.missions`, `summary.emission_reduction_pct` (ekleme) | B içi, A etkilenmez | Yapıldı |

## Entegrasyon günlüğü

| Tarih saat | develop commit | Çalışan akışlar | Sorunlar |
|---|---|---|---|
| 2026-10-31 | f373ba7 + A kamera (Windows) | Windows'ta `export/ANTALYA2040.exe` üretildi (4.7.2 şablonları, 105 MB) ve çalıştırıldı: ana menü, arka plan şehri, Türkçe karakterler doğru; log'da hata yok. A şehir testi + B'nin 6 testi (day1, day2, economy, menu, e2e, ui) TAMAM. | Panel kapanınca arsa vurgusu kalıyor (v1.3 sinyali bekleniyor). Orta seviye PC'de FPS ölçülmedi. |
| 2026-10-31 | 2b93949 + B bağlama | Menü → Game, fare tıklamasıyla arsa seçimi, BuildPanel, 3 bina şehirde, 2043 sıcak hava ve 2049 taşkın krizi + efektler, kriz sırasında seçim kilidi (`tests/test_e2e_game.gd`, Mac) | Görev/uyarı yazıları açık zeminde zor okunuyordu, kenar çizgisi eklendi. Windows'ta oynanmadı. |

## Açık sorular

- ~~Godot 4.7.2 Standard iki bilgisayarda da aynı mı?~~ Çözüldü: Mac ve Windows'ta 4.7.2.stable.official (Gün 0).
- CO2 senaryosu için hangi IPCC AR6 senaryosu kullanılacak? (B karar verir, kaynağı kartta yazar) · Durum: v1.0 sonrasına ertelendi; şimdilik NOAA 1959–2025 ölçümü var, 2040–2052 için oyun "veri yok" gösterir.
