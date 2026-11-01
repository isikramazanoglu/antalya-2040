# ANTALYA 2040 · İşletmeler ve çevre denetimi (Prompt 13)

Sahip: **Ekip B** (oyun mantığı, veri, arayüz). Görseller (fabrika modelleri, duman) **Ekip A**'nın işidir; bu belgedeki §8 ikisinin arasındaki sözleşmedir.
Ana sözleşme eklemesi: `docs/INTEGRATION_CONTRACT.md` v1.10 §3.5.

> Bütün sayılar **oyun dengeleme değeridir**. Gerçek emisyon ölçümü, gerçek çevre mevzuatı ya da yasal sınır değildir; oyunda da öyle yazılır.

## 1. Mimari

| Parça | Dosya | Görev |
|---|---|---|
| İşletme türü (veri) | `scripts/data/business_type.gd`, `data/businesses/*.tres` (10 tür) | büyüklük, çalışan, katkı, enerji/su, sera gazı, hava, atık, kurulma ağırlığı |
| Denge ayarları | `scripts/data/balance_config.gd` → `data/balance.tres` | sanayi yerleri, üst sınır, olasılık, denetim kapasitesi, standartlar, ceza, kararlar |
| Hesap | `scripts/sim/business_simulator.gd` | saf fonksiyonlar: kurulma, etki, ihlal seviyesi, ceza, aylık/yıllık değişim, görsel veri |
| Durum | `GameState.businesses`, `business_seq`, `inspections_used` | tek kaynak; yalnızca GameController yazar |
| Oyuncu istekleri | `GameController.inspect_business / fine_business / order_business / resume_business` | kontrol zinciri, kasa, bildirim, sinyal |
| Takvim | `TurnManager.advance_month` → `GameController.business_month`; yıl sonu → `business_year` | aylık: haklar yenilenir, kararlar işler, yeni işletme gelebilir; yıllık: üretim dalgalanır |
| Arayüz | `scenes/ui/BusinessPanel.tscn`, `scripts/ui/business_panel.gd`, HUD "Sanayi" düğmesi | liste, ayrıntı, denetim, ceza, kararlar |
| Kayıt | `scripts/sim/save_game.gd`, `GameState.to_snapshot/apply_snapshot`, `TurnManager.save_state` | bütün oyun (§7) |

Tek para birimi **kredi** (`GameState.stats.credits`). İkinci bakiye yoktur.

## 2. Kendiliğinden kurulma

- İşletmeler yalnızca **sanayi yerlerine** (`balance.industrial_sites`, `I01`–`I08`) kurulur. Oyuncunun 15 arsasına (U, O, C) asla kurulmaz. Bir yere tek işletme.
- Her ay bir kez denenir (`BusinessSimulator.spawn`), olasılık: `business_spawn_chance (0,08) × nüfus çarpanı (nüfus/500, 0,5–2) × (1 − işletme sayısı / max_businesses)`.
- Boş yer yoksa ya da `max_businesses` (8) doluysa kurulmaz.
- Tür seçimi ağırlıklı (`spawn_weight`) ve koşullu:
  - nüfus `min_population` altındaysa tür gelmez
  - hava kirliliği `air_pollution_soft_cap` (50) üstündeyse çok kirleten türler (hava ≥ 6) ×0,2: çevre taşıma kapasitesi
  - su puanı < 40 ise çok su harcayan türler (su ≥ 4) ×0,3: altyapı yetersiz
  - nüfus > 550 ise lojistik ×1,5
- Rastgelelik TurnManager'daki ayrı, tohumlu üreteçten gelir (`_biz_rng`); kayıt ve yükleme sonrası aynı sırayla devam eder, kriz sırasını değiştirmez.

## 3. İşletme verisi (`GameState.businesses` öğesi)

```
{ "business_id": StringName "B001",     # kalıcı sayaç (business_seq); kapanan işletmenin kimliği yeniden verilmez
  "business_name": String,              # kurgusal ad, ör. "Toros Beton A.Ş."
  "business_type": StringName,          # data/businesses/<id>.tres
  "site_id": StringName,                # I01..I08 (prompttaki parcel_id)
  "established_year": int, "established_month": int,
  "production": float,                  # 0,6–1,4 (yıllık dalgalanma)
  "operational_status": &"active" | &"suspended" | &"closed",
  "suspended_months": int,
  "upgrades": { "filter": bool, "clean_energy": bool, "treatment": bool },
  "pending_improvements": [ { "order": StringName, "months_left": int } ],
  "inspection_history": [ { "inspection_id", "year", "month", "level", "air", "waste", "ghg", "air_ok", "waste_ok",
                            "filter", "treatment", "clean_energy", "previous_violations", "suggested_fine",
                            "fined": bool, "fine_paid": int, "order": StringName } ],
  "violation_history": [ { "inspection_id", "level", "year", "month" } ],
  "fines_paid": int, "fines_by_year": { year: int }, "escalation": int,
  "last_inspection": { "year", "month" } }
```

Ekonomi değerleri (katkı, çalışan) ile çevre değerleri (hava, atık, sera gazı) ayrı alanlardır; `BusinessSimulator.effective` ikisini birlikte hesaplar.

## 4. Ekonomi ve çevre etkisi

| Tür | Büyüklük | Çalışan | Katkı/yıl | Elektrik | Su | Sera gazı | Hava | Atık |
|---|---|---|---|---|---|---|---|---|
| Küçük üretim fabrikası | 1 | 40 | 20 | 2 | 1 | 2 | 4 | 2 |
| Ağır sanayi tesisi | 3 | 150 | 55 | 6 | 3 | 7 | 8 | 5 |
| Lojistik deposu | 2 | 60 | 30 | 2 | 0,5 | 3 | 3 | 1 |
| Beton santrali | 2 | 70 | 35 | 4 | 2 | 6 | 7 | 3 |
| Atık işleme tesisi | 2 | 50 | 25 | 2 | 2 | 3 | 4 | 6 |
| Kimya fabrikası | 3 | 90 | 50 | 5 | 4 | 5 | 6 | 8 |
| Gıda fabrikası | 2 | 80 | 30 | 3 | 4 | 2,5 | 2 | 5 |
| Tekstil fabrikası | 2 | 100 | 30 | 3 | 5 | 3 | 3 | 6 |
| Soğuk depolu alışveriş merkezi | 2 | 70 | 35 | 6 | 1 | 4 | 1 | 2 |
| Küçük sanayi atölyesi | 1 | 20 | 10 | 1 | 0,5 | 1 | 3 | 3 |

Birimler oyun birimidir. Ayrımlar:
- **Sera gazı** şehrin karbon salımına `emissions_by_sector.industry` kalemi olarak eklenir. Küresel atmosferik CO₂ (`global_co2_ppm`, NOAA ölçümü) **değişmez**.
- **Yerel hava kirliliği** ayrı bir endekstir: `stats.air_pollution = Σ hava × 2,5`, 0–100 arası. Yıllık etkisi: yaşam kalitesi −0,03 × endeks.
- **Atık ve atık su yükü** ayrı bir endekstir: `stats.waste_pollution = Σ atık × 2,0`. Yıllık etkisi: doğa −0,03 × endeks.
- **Enerji ve su tüketimi** şehrin ihtiyacına eklenir; temiz elektrik payı buna göre düşer.
- **Katkı** yıllık gelire eklenir (`report.business_income`, `income`'a dahil). Ay ay 1/12'si bütçeye işler.

Kararların etkisi (`balance.order_reduction`, ilgili kirleticiyi %60 azaltır, sıfırlamaz):
- **Filtre:** hava kirliliğini azaltır.
- **Arıtma:** atığı azaltır.
- **Temiz enerji:** sera gazının yalnızca enerji kaynaklı kısmını (`ghg_energy_share`) azaltır.

## 5. Denetim ve ceza

- **İhlal** verilerden belirlenir, görselden değil: `oran = en büyük(hava / air_standard (4), atık / waste_standard (4))`.
  - ≤ 1 uygun
  - ≤ 1,5 hafif ihlal
  - ≤ 2 orta ihlal
  - ≤ 3 ağır ihlal
  - \> 3 çok ağır ihlal
- **Kapasite:** her ay 3 ücretsiz denetim (`inspections_per_month`). Ek denetim 20 kredi; bütçe yetmezse gelecek ayı beklemek gerekir. Aynı işletme 3 ayda bir denetlenebilir (`inspection_cooldown_months`).
- **Ceza** = `fine_base (5) × büyüklük × seviye çarpanı [0,1,2,3,5] × (1 + önceki cezalar × 0,5) × (1 + 0,5 × gecikme)`, en çok `fine_cap` (120). Gecikme: süre verilip iyileştirme yapılmadıysa artar.
- Ceza kesilemeyen durumlar:
  - ihlal yoksa
  - bir denetime ikinci kez
  - aynı işletmeye aynı yıl ikinci kez (`fines_per_business_per_year`)

  Ceza kasaya girer ama **kirliliği azaltmaz**. Simülasyonda her ay denetleyip ceza kesen oyuncu yılda yalnızca 5–15 kredi topladı; ceza bir gelir kaynağı olmuyor.
- **Kararlar:** her denetime bir karar verilir.

| Karar | Süre | Etki |
|---|---|---|
| Filtre taktır | 4 ay | hava kirliliği azalır |
| Temiz enerjiye geçir | 6 ay | enerji kaynaklı sera gazı azalır |
| Atık arıtma kurdur | 4 ay | atık azalır |
| Süre ver | 3 ay | süre sonunda işletme %50 olasılıkla kendisi iyileştirir; yoksa gecikme artar ve bir sonraki ceza ağırlaşır |
| Faaliyeti durdur | — | katkı 0, emisyon %10'a iner; çalışanlar işsiz kalır (yaşam kalitesi −2 × çalışan / 100); "Yeniden aç" ile döner; 12 ay kapalı kalırsa işletme kapanır ve yeri boşalır |

  Dönüşüm sürerken işletmenin katkısı %30 düşer; yatırımı işletme öder, belediyeden kredi çıkmaz.

## 6. Arayüz

- **HUD "Sanayi" düğmesi** paneli açar: başta özet (işletme sayısı, hava ve atık kirliliği, kalan denetim hakkı), solda liste (ad, tür, yer, durum), sağda ayrıntı (ekonomi, kaynak, çevre, sistemler, süren kararlar, son 4 denetim, yeniden denetim tarihi).
- **Düğmeler:** Denetle (ücretsiz / 20 kredi), Ceza kes (+tutar), 5 karar, Yeniden aç. Kapalı düğmenin üstüne gelince nedeni yazar.
- **Bildirimler (toast):**
  - yeni işletme kuruldu
  - denetim sonucu
  - ceza ödendi
  - dönüşüm tamamlandı
  - süre doldu
  - faaliyet durduruldu
  - işletme kapandı
- Panel açıkken takvim durur (`ui_panel`). Yıl sonu raporunda "İşletmelerden gelen", "Çevre cezaları", "Ek denetimler" satırları var. İklim Laboratuvarı'nın karbon grafiklerinde "Sanayi" kalemi görünür.

## 7. Kayıt ve yükleme

- **Dosya:** `user://antalya2040_save.dat` (`SaveGame`), tek kayıt yuvası. Biçim Godot'nun ikili `store_var` biçimidir: türler korunur, yüklemede nesne kabul edilmez (`get_var(false)`).
- **Sürüm:** `VERSION = 1`; farklı sürüm yüklenmez. Eski kayıtta eksik anahtar varsa varsayılanı kalır.
- **İçerik:** GameState'in tamamı; arsalar, işletmeler, sayaçlar, bu ayki denetim sayısı. Ayrıca TurnManager'ın iç durumu (iki rastgele üretecin durumu, yıl başı değerleri, aylık bütçe toplamı, bu yılın cezaları) ve eğitim ilerlemesi.
- **Ne zaman kaydedilir:**
  - her yeni yılın başında (Ocak) otomatik
  - HUD'dan ana menüye dönerken
  - oyun bitince kayıt silinir

  Ana menüde "DEVAM ET" düğmesi çıkar.
- **Çoğalmaya karşı:** yalnızca build fazında kaydedilir; kriz ya da rapor ortası kayda girmez. Ceza işareti (`fined`) ve yıllık ceza sayısı kayıtta durur, aynı ihlale yeniden ceza kesilemez. İşletme kimlik sayacı kayıtta durur, kimlik tekrar etmez. Yüklemede yeni işletme oluşturulmaz; var olanlar `business_spawned(info.restored = true)` ile görsele yeniden bildirilir.
- **Testler** oyuncunun kaydına dokunmaz: `--script` ile çalışırken kayıt kapalıdır. `test_businesses.gd` kendi dosyasını açar ve sonunda siler.

## 8. Ekip A için görsel entegrasyon sözleşmesi

**Sanayi yerleri:** `I01`–`I08`. **Konumlarını Ekip A belirler** (arsalarda olduğu gibi: B kimliğe güvenir, A geometriyi tutar). Yerler oyuncunun arsalarıyla, yollarla ve meydanlarla çakışmamalı ve kamerada görünmeli. Öneri: kuzey yolu ile tarlalar arasında ya da rezervuar çevresinde bir sanayi şeridi. Ayrıca bina büyüklüğüne göre yaklaşık 6×6 birimlik taban.

**Sinyaller** (EventBus v1.10):
- `business_spawned(info)`: modeli `info.site_id` yerine koy. `info.restored == true` ise yükleme var demektir; büyüme animasyonu gerekmez. Aynı `business_id` için ikinci model kurma.
- `business_updated(info)`: duman, durum ve ihlal görselini güncelle.
- `business_removed(business_id, site_id)`: modeli kaldır.

**`info` sözlüğü** (`BusinessSimulator.visual_info`):

| Anahtar | Tip | Kullanım |
|---|---|---|
| `business_id` | StringName | benzersiz kimlik (B001…) |
| `business_type` | StringName | tür kimliği |
| `business_name` | String | etiket (isteğe bağlı) |
| `visual_id` | StringName | model eşleştirme anahtarı (aşağıda) |
| `site_id` | StringName | `I01`–`I08` |
| `operational_status` | StringName | `active`, `suspended` (duman yok, ışıklar sönük önerilir) |
| `violation_level` | int 0–4 | 0 uygun … 4 çok ağır (ör. kırmızı uyarı işareti) |
| `emission_level` | int 0–3 | sera gazı seviyesi (düşük … çok yüksek) |
| `smoke_intensity` | float 0–1 | duman yoğunluğu (hava kirliliği / 10) |
| `upgrades` | Dictionary | `filter`, `clean_energy`, `treatment` (ör. filtreli bacada beyaz duman, çatıda güneş paneli) |
| `restored` | bool | yalnızca yüklemede |

**`visual_id` eşleştirmesi** (önerilen model adları; A gerçek dosya yolları belli olunca `data/businesses/*.tres` → `visual_id`'yi değiştirmeyi B'den ister):

| Tür | visual_id |
|---|---|
| small_factory | `Industrial_SmallFactory` |
| heavy_factory | `Industrial_HeavyFactory` |
| logistics_warehouse | `Industrial_LogisticsWarehouse` |
| concrete_plant | `Industrial_ConcretePlant` |
| waste_facility | `Industrial_WasteFacility` |
| chemical_plant | `Industrial_ChemicalPlant` |
| food_factory | `Industrial_FoodFactory` |
| textile_plant | `Industrial_TextilePlant` |
| energy_intensive_commerce | `Commercial_EnergyIntensive` |
| small_workshop | `Industrial_SmallWorkshop` |

**Kurallar:**
- A'nın modelleri ekonomi ya da çevre hesabı yapmaz, GameState'e yazmaz.
- Duman yalnızca `smoke_intensity`'den sürülür.
- Kayıt ve yüklemede B bildirimi yeniden gönderir; A ayrıca bir şey saklamaz.
- **Bugün:** A dinlemiyorsa sistem çalışır; işletmeler panelde ve bildirimlerde görünür, haritada model yoktur.

## 9. Bilinen sınırlar

- Öncelikli ihbar (ağır ihlalde ücretsiz acil denetim) yok; her ay 3 ücretsiz hak bunun yerine geçiyor.
- `balance_sim.gd` yıl yıl ilerlediği için işletme kurulmaz (eski senaryolar aynı kalsın diye). İşletmeli dengeyi ay ay simüle eden ayrı bir ölçüm yapıldı (PROGRESS).
- Kayıt tek yuvalı; elle "Kaydet" düğmesi yok (otomatik ve menüye dönüşte).
- Görsel yerleşim Ekip A'yı bekliyor.
