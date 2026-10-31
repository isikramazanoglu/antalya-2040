# ANTALYA 2040 · İlerleme

Her ekip yalnızca kendi bölümündeki kutuları işaretler. Ortak bölümlere satır **eklenir**, var olan satır silinmez.
İşaret: `[ ]` yapılmadı, `[~]` sürüyor, `[x]` bitti ve kendi dalında çalışıyor, `[D]` develop'a birleşti.

Son güncelleme: 2026-10-30 · Aşama: **Gün 3, Ekip B işleri bitti; entegrasyon için Ekip A bekleniyor**
Repo: https://github.com/isikramazanoglu/antalya-2040 (gizli)

---

## Gün 0 · Kurulum (ikisi birlikte, 1–2 saat)

- [~] İki bilgisayarda Godot 4.7.2 Stable Standard kurulu (Mac: 4.7.2.stable.official doğrulandı; ikinci bilgisayar bekliyor)
- [~] GitHub reposu açıldı (gizli); ikinci kişi Collaborators'a eklenecek
- [x] `main`, `develop`, `feature/city-world`, `feature/simulation-ui` dalları açıldı ve gönderildi
- [x] B: iskelet commit'i `develop`'a: `project.godot` (Forward+, autoload'lar, Input Map, fizik katman adları), `.gitignore`, `.gitattributes`, `event_bus.gd`, `scripts/data/*.gd` boş Resource sınıfları, boş `catalog.tres`, `Game.tscn`, `MainMenu.tscn`
- [x] A: `CityWorld.tscn` kök node'u (boş zemin + kamera) iskelete eklendi, Game.tscn içinde açılıyor
- [ ] İki bilgisayarda da `develop` çekildi, oyun açıldı, hata yok
- [x] Windows export: Mac'te `export/ANTALYA2040.exe` üretildi (PCK gömülü, Game sahnesi ve 12 bina paketten yüklendi, dev/test hariç). Windows'ta çalıştırılması bekliyor.

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
- Açık (A): efektin genel şiddeti henüz koruma oranına bağlı değil; v1.6 talebi aşağıda.

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
- [ ] Birlikte: uçtan uca test, Windows export, `main`'e son birleştirme, `v1.0` etiketi
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

## Sözleşme değişiklik talepleri

| Tarih | İsteyen | Değişiklik | Onay | Durum |
|---|---|---|---|---|
| 2026-10-31 | B | v1.5: `crisis_stage_changed` + `result.severity/assessment` (ekleme) | A'nın kullanması isteğe bağlı | Yapıldı |
| 2026-10-31 | B | v1.4: ret nedenleri `scene_unavailable`, `unknown_plot` (ekleme) | B içi, A ret nedenlerini kullanmaz | Yapıldı |
| 2026-10-31 | A | v1.6: `crisis_stage_changed` info'suna `mitigation` (0..0.8, o risk için yatırımların koruma oranı) ve `advantages` (koruma sağlayan bina kimlikleri). Neden: Prompt 7B koruma düzeyini görselde B'nin değerinden almayı istiyor; şu an yalnızca `crisis_resolved` sonucunda var. | B onayı bekleniyor | Bekliyor |
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
