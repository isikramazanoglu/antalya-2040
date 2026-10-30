# ANTALYA 2040 · İlerleme

Her ekip yalnızca kendi bölümündeki kutuları işaretler. Ortak bölümlere satır **eklenir**, var olan satır silinmez.
İşaret: `[ ]` yapılmadı, `[~]` sürüyor, `[x]` bitti ve kendi dalında çalışıyor, `[D]` develop'a birleşti.

Son güncelleme: 2026-10-30 · Aşama: **Gün 1, Ekip B işleri bitti (Mac), A bekleniyor, GitHub'a gönderilmedi**

---

## Gün 0 · Kurulum (ikisi birlikte, 1–2 saat)

- [~] İki bilgisayarda Godot 4.7.2 Stable Standard kurulu (Mac: 4.7.2.stable.official doğrulandı; ikinci bilgisayar bekliyor)
- [ ] GitHub reposu açıldı, iki kişi de yazma yetkili
- [ ] `main`, `develop`, `feature/city-world`, `feature/simulation-ui` dalları açıldı
- [x] B: iskelet commit'i `develop`'a: `project.godot` (Forward+, autoload'lar, Input Map, fizik katman adları), `.gitignore`, `.gitattributes`, `event_bus.gd`, `scripts/data/*.gd` boş Resource sınıfları, boş `catalog.tres`, `Game.tscn`, `MainMenu.tscn`
- [x] A: `CityWorld.tscn` kök node'u (boş zemin + kamera) iskelete eklendi, Game.tscn içinde açılıyor
- [ ] İki bilgisayarda da `develop` çekildi, oyun açıldı, hata yok
- [ ] Windows export denemesi (boş proje) çalıştı · export template'leri henüz kurulu değil

## Gün 1 · Oynanabilir prototip (3 yatırım)

Hedef akşam: menü → şehir → arsa seç → 3 yatırımdan birini inşa et → bütçe düşer → yılı bitir → rapor → 2052 → final.

### Ekip A
- [ ] CameraRig: kaydırma, yakınlaştırma, ±30° döndürme, sınırlar
- [ ] Zemin, deniz düzlemi, ışık ve WorldEnvironment ilk ayar
- [ ] BuildPlot sahnesi ve 15 arsa (sözleşme §7)
- [ ] Işınla arsa seçimi, vurgu, `plot_selected` / `plot_deselected`
- [ ] `phase_changed` ile seçimi kilitleme
- [ ] Building taban sahnesi + büyüme animasyonu
- [ ] Yer tutucu modeller: `b_solar_plant`, `b_water_storage`, `b_green_park`
- [ ] `build_approved` → bina yerleştirme
- [ ] CitySandbox sahnesi

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
- [ ] Kalan 9 bina sahnesi (önce yer tutucu, sonra low-poly)
- [ ] Akdeniz dekor: evler, yollar, ağaçlar, iskele, terracotta materyaller
- [ ] DisasterFX: sıcak, kuraklık, taşkın
- [ ] `crisis_started` / `crisis_resolved` bağlantısı
- [ ] Deniz shader'ı (turkuaz)

### Ekip B
- [ ] 12 `BuildingDefinition` + bilgi kartları
- [ ] ClimateSimulator (sektör emisyonları, riskler, ekosistem, CO2 okuma)
- [ ] `co2_scenario.tres` kaynaklı verilerle (kaynak satırı zorunlu)
- [ ] EventManager + 3 `EventDefinition` + müdahaleler
- [ ] TurnManager kriz fazı
- [ ] EventPanel, HUD uyarı listesi
- [ ] ClimateLab ve LineChart

## Gün 3 · Cila ve teslim

Öğlen 12:00 özellik dondurma. Sonrası yalnızca hata düzeltme ve denge.

- [ ] A: ışık/gölge cilası, kamera hissi, performans testi
- [ ] B: denge (2–3 tam oyun), görevler (vakit kalırsa), arayüz teması
- [ ] Birlikte: uçtan uca test, Windows export, `main`'e son birleştirme, `v1.0` etiketi
- [ ] Sunum için 2 dakikalık demo senaryosu (sabit seed)

---

## Sözleşme değişiklik talepleri

| Tarih | İsteyen | Değişiklik | Onay | Durum |
|---|---|---|---|---|

## Entegrasyon günlüğü

| Tarih saat | develop commit | Çalışan akışlar | Sorunlar |
|---|---|---|---|

## Açık sorular

- Godot 4.7.2 Standard iki bilgisayarda da aynı mı? (Gün 0'da kontrol)
- CO2 senaryosu için hangi IPCC AR6 senaryosu kullanılacak? (B karar verir, kaynağı kartta yazar)
