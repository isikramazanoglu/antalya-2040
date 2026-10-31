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
  - Test: `scripts/world/dev/test_final_presentation.gd` (gerçek Game.tscn 2052'ye kadar; kabul ölçütleri 1–6, Esc, geçici kopya, bilinmeyen kimlik, eksik summary, yatırımsız oyun; 29 kontrol) 1280×720 ve 1920×1080'de TAMAM. B'nin 11 testi + A'nın diğer 4 testi TAMAM. Windows export (geçici klasöre) hatasız, exe açılıyor.
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

- Godot 4.7.2 Standard iki bilgisayarda da aynı mı? (Gün 0'da kontrol)
- CO2 senaryosu için hangi IPCC AR6 senaryosu kullanılacak? (B karar verir, kaynağı kartta yazar)
