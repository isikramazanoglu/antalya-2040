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

## Sözleşme değişiklik talepleri

| Tarih | İsteyen | Değişiklik | Onay | Durum |
|---|---|---|---|---|
| 2026-10-31 | B | v1.2: `stats` enerji/su akışları (ekleme) | B içi, A etkilenmez | Yapıldı |
| 2026-10-30 | B | v1.1: `report.missions`, `summary.emission_reduction_pct` (ekleme) | B içi, A etkilenmez | Yapıldı |

## Entegrasyon günlüğü

| Tarih saat | develop commit | Çalışan akışlar | Sorunlar |
|---|---|---|---|
| 2026-10-31 | 2b93949 + B bağlama | Menü → Game, fare tıklamasıyla arsa seçimi, BuildPanel, 3 bina şehirde, 2043 sıcak hava ve 2049 taşkın krizi + efektler, kriz sırasında seçim kilidi (`tests/test_e2e_game.gd`, Mac) | Görev/uyarı yazıları açık zeminde zor okunuyordu, kenar çizgisi eklendi. Windows'ta oynanmadı. |

## Açık sorular

- Godot 4.7.2 Standard iki bilgisayarda da aynı mı? (Gün 0'da kontrol)
- CO2 senaryosu için hangi IPCC AR6 senaryosu kullanılacak? (B karar verir, kaynağı kartta yazar)
