# ANTALYA 2040 · İklimin Geleceği · Oyun tasarımı

Sahip: ORTAK. Sayıları Ekip B dengeler; değişen sayı önce `data/balance.tres` veya ilgili `.tres` dosyasına, sonra buraya yazılır.

---

## 1. Özet

Oyuncu 2040 yılında Antalya kıyısından esinlenen küçük bir Akdeniz şehrinin yönetimini devralır. 2052'ye kadar her tur bir yıldır. Sınırlı bütçeyle belirlenmiş arsalara sürdürülebilir yatırımlar yapar, önceden haber verilen kuraklık, sıcak hava dalgası ve kıyı taşkınlarına hazırlanır. Oyunun sonunda şehrin yaşam kalitesi, su ve enerji güvenliği, ekosistemi ve emisyonları puanlanır.

Tür: 3D şehir kurma, strateji, ekonomi simülasyonu, iklim eğitimi, kriz yönetimi. Tek oyunculu. Orta zorluk.

## 2. Oyun döngüsü

1. Yıl başlar (2040).
2. Oyuncu şehri gezer, arsa seçer, yatırım kartlarını ve bilgi kartlarını okur, inşa eder.
3. HUD'daki uyarılara bakar, gerekirse koruyucu yatırım yapar.
4. "Yılı bitir" der.
5. Zamanı gelen kriz varsa müdahale seçer.
6. Yıl sonu raporunu okur.
7. 2052 sonunda final ekranı.

Toplam 13 yıl sonu (2040–2052 dahil).

## 3. Göstergeler

| Gösterge | Başlangıç | Aralık | Not |
|---|---|---|---|
| Kredi | 1000 | 0+ | Oyun parası |
| Nüfus | 500 | 0+ | |
| Su güvenliği | 60 | 0–100 | |
| Enerji güvenliği | 50 | 0–100 | Taslak başlangıç değeri |
| Yaşam kalitesi | 50 | 0–100 | |
| Ekosistem sağlığı | 60 | 0–100 | |
| Yerel emisyon | 100 | 0+ | Oyun birimi, sektör toplamı |

Bu değerler gerçek Antalya ölçümü değildir; oyun dengeleme değerleridir. Arayüzde de böyle belirtilir.

## 4. Kurallar ve taslak formüller

Hepsi `BalanceConfig` içinde katsayı olarak durur, kodda sabit sayı yazılmaz.

**Ekonomi**
- Gelir = nüfus × 0.5 kredi (500 kişi → 250/yıl).
- Gider = şehir taban gideri 100 + binaların `upkeep_per_year` toplamı.
- Kredi eksiye düşerse: o yıl yaşam kalitesi −5, yeni inşaat yapılamaz (kredi kontrolü zaten engeller).

**Nüfus**
- Yıllık değişim oranı = (yaşam kalitesi − 45) / 1000, −%3 ile +%4 arasında sınırlı.
- Su güvenliği 30'un altındaysa oran ayrıca −%2.

**Enerji ve su akışları (bilgi amaçlı)**
- Enerji talebi = nüfus × 0.1 + binaların `energy_consumption` toplamı. Yenilenebilir üretim = binaların `energy_production` toplamı (güneş 20). Yenilenebilir payı = üretim / talep (0–1); kalanı şebekeden, fosil kaynaklı kabul edilir.
- Su talebi = nüfus × 0.1 + binaların `water_consumption` toplamı (park 1, kent tarımı 2). Su arzı = 55 + binaların `water_production` toplamı (su depolama 10, geri kazanım 15).
- Bu akışlar İklim Laboratuvarı'nda ve yıl sonu raporunda gösterilir; puanı ve endeksleri doğrudan değiştirmez. Değerler oyun birimidir.

**Emisyon (yerel)**
- Sektör taban değerleri (500 nüfus için): enerji 40, ulaşım 25, binalar 20, atık 15.
- Sektör emisyonu = taban × (nüfus / 500) × (1 + o sektördeki `emission_multipliers` toplamı), en düşük %20'ye kadar iner.

**Riskler (0–100)**
- Başlangıç: kuraklık 40, sıcak 45, kıyı taşkını 30.
- Her yıl artış: kuraklık +2, sıcak +2, taşkın +1.5. Bu artış oyun içi bir eğilimdir, bilimsel tahmin değildir.
- Yıl sonunda hesaplanan risk **gelecek yılın** riskidir (uyarılar da gelecek yıl için planlanır).
- Gösterilen risk = ham risk × (1 − koruma oranı).
- Koruma oranı = o `risk_type` için tüm binaların `risk_reduction` toplamı, en çok 0.8.

**Ekosistem**
- Her yıl −1 (kentleşme baskısı) + binaların `yearly_effects` katkısı.
- Toplam emisyon 80'in altındaysa +1.

**Kriz hasarı**
- Uygulanan hasar = `base_damage` × (1 − koruma oranı) × seçilen müdahalenin `damage_multiplier` değeri.
- `scripted_year` dolu olan kriz yalnızca o yıl gelir (demo garantisi). Boşsa her yıl olasılık = `base_probability` × (gösterilen risk / 50).

**Final puanı**
- Puan = (su + enerji + yaşam kalitesi + ekosistem) / 4 + **kişi başı** emisyon azalma yüzdesi × 0.3 (en çok 30). Kişi başına bakılır ki şehri büyütmek cezalandırılmasın.
- Not: 85+ "İklim Lideri", 70+ "Dayanıklı Şehir", 50+ "Gelişen Şehir", altı "Risk Altında".

## 5. On iki yatırım (taslak sayılar)

| # | id | Ad | Maliyet | Gider/yıl | Ana etki | Risk koruması |
|---|---|---|---|---|---|---|
| 1 | `efficient_housing` | Enerji verimli konut bölgesi | 300 | 15 | Nüfus +100 (bir kez), yaşam +4, binalar emisyonu −%10 | sıcak 0.10 |
| 2 | `solar_plant` | Güneş enerjisi tesisi | 400 | 10 | Enerji +20, enerji emisyonu −%30 | – |
| 3 | `public_efficiency` | Kamu binalarında enerji verimliliği | 200 | 5 | Enerji +8, binalar emisyonu −%15 | – |
| 4 | `water_storage` | Su depolama ve kaçak azaltma | 250 | 10 | Su +15 | kuraklık 0.30 |
| 5 | `water_reuse` | Atık su geri kazanım tesisi | 350 | 20 | Su +20, ekosistem +3 | kuraklık 0.25 |
| 6 | `green_park` | Yeşil park ve gölgelendirme | 150 | 10 | Yaşam +8, ekosistem +5 | sıcak 0.25 |
| 7 | `cooling_center` | İklim serinleme merkezi | 200 | 15 | Yaşam +4 | sıcak 0.35 |
| 8 | `urban_farming` | İklime dayanıklı kent tarımı | 200 | 5 | Yaşam +4, ekosistem +2 | kuraklık 0.10 |
| 9 | `food_rescue` | Gıda kurtarma merkezi | 100 | 5 | Yaşam +5, atık emisyonu −%10 | – |
| 10 | `recycling_compost` | Geri dönüşüm ve kompost tesisi | 250 | 10 | Atık emisyonu −%35, ekosistem +3 | – |
| 11 | `transit_hub` | Düşük emisyonlu toplu taşıma merkezi | 400 | 20 | Ulaşım emisyonu −%35, yaşam +5 | – |
| 12 | `coastal_restoration` | Kıyı ekosistemi restorasyonu ve erken uyarı | 350 | 10 | Ekosistem +12 | taşkın 0.45 |

Hepsi `max_count = 1`. MVP üçlüsü: güneş (enerji/emisyon), su depolama (su/kuraklık), yeşil park (yaşam/sıcak).

Bütçe kontrolü: 13 yılda yaklaşık 2000–2800 kredi birikir; oyuncu 12 yatırımın hepsini alamaz, seçim yapmak zorunda kalır.

## 5b. Yatırım kombinasyonları (Prompt 9A)

İki yatırım birlikte kurulunca ek etki gelir. Kombinasyonlar `SynergyDefinition` (BuildingDefinition'dan türer) olarak `data/synergies/` altında tanımlıdır; `GameState.built_definitions()` etkin olanları binalarla aynı listede döndürür, böylece bonus tek yoldan bir kez uygulanır. Gideri ve maliyeti yoktur.

| Kombinasyon | Gereken | Ek etki |
|---|---|---|
| Akıllı enerji | Güneş + kamu verimliliği | Enerji talebi −4 |
| Su döngüsü | Su depolama + atık su geri kazanımı | Geri kazanılmış su +5, kuraklık hasarı −%10 |
| Serin şehir | Yeşil park + serinleme merkezi | Sıcak hasarı −%10 |
| Toprak döngüsü | Kent tarımı + kompost | Ekosistem +1/yıl, atık emisyonu −%5 |
| Gıda israfı yok | Gıda kurtarma + kompost | Atık emisyonu −%10 |
| Düşük karbonlu büyüme | Toplu taşıma + kamu verimliliği | Ulaşım −%5, binalar −%5 emisyon |

**Geri kazanılmış su:** atık su geri kazanım tesisi 15 birim geri kazanılmış su üretir; içme suyu arzına eklenmez, yalnızca su talebinin içme dışı kısmını (en çok %30) karşılar.

**Diğer 9A değişiklikleri:** kamu binalarında verimlilik sıcak hava hasarını %10 azaltır. Kıyı yatırımının iki bileşeni kartta ayrı gösterilir: restorasyon (ekosistem +12, taşkın −%30, "kıyı ekosistemine güven" müdahalesi) ve erken uyarı (taşkın −%15, "erken uyarı" müdahalesi).

## 6. Krizler

| id | risk_type | En erken | Demo yılı (`scripted_year`) | Taban hasar |
|---|---|---|---|---|
| `heatwave` | heat | 2042 | 2043 | yaşam −10, nüfus −10 kişi, kredi −100, enerji −8 |
| `drought` | drought | 2044 | 2046 | su −20, ekosistem −5, kredi −150 |
| `coastal_flood` | coastal_flood | 2046 | 2049 | kredi −250, ekosistem −8, yaşam −5 |

Her krizin üç müdahale seçeneği olur. Örnek, sıcak hava dalgası:

| response id | Seçenek | Maliyet | Hasar çarpanı |
|---|---|---|---|
| `open_cooling` | Serinleme alanlarını aç, yaşlılara ulaş | 60 | 0.6 |
| `shift_hours` | Açık hava çalışma saatlerini değiştir | 20 | 0.8 |
| `do_nothing` | Müdahale etme | 0 | 1.0 |

**Hasar hesabı (Prompt 7A):** taban × tehlike × maruziyet × hassasiyet × (1 − uyum) × müdahale çarpanı; müdahale maliyeti ve ek etkileri ayrıca eklenir.
- Tehlike = 0.5 + şiddet; şiddet = o yılın yatırımdan bağımsız ham riski / 100 (0.2–1).
- Maruziyet = nüfus / 500 (0.8–1.5).
- Hassasiyet = 1 + Σ ağırlık × (50 − gösterge) / 100 (0.6–1.5): kuraklıkta su güvenliği, sıcakta yaşam kalitesi + ekosistem, taşkında ekosistem.
- Uyum = binaların koruma oranı (en çok %80).
- Sıcak hava enerji güvenliğini de düşürür (klima talebi).

**Müdahaleler** (altyapı şartlı olanlar yalnızca o bina kuruluysa görünür; bütçe yetmeyen seçilemez):

| Kriz | Seçenek | Maliyet | Çarpan | Şart |
|---|---|---|---|---|
| Kuraklık | Su tasarrufu programı (yaşam −3) | 0 | 0.7 | – |
| | Acil su tedariki | 120 | 0.5 | – |
| | Su depolama altyapısını devreye al | 20 | 0.35 | Su depolama |
| | Verimli sulama ve tarım planı (ekosistem +2) | 30 | 0.5 | Kent tarımı |
| Sıcak hava | Acil enerji desteği (enerji +5) | 90 | 0.65 | – |
| | Serinleme merkezlerini devreye al | 20 | 0.4 | Serinleme merkezi |
| | Park ve gölgelendirme altyapısını kullan | 10 | 0.6 | Yeşil park |
| | Enerji talebini azaltma programı (enerji +3) | 20 | 0.8 | – |
| | Kamu binalarını serinleme alanı yap | 60 | 0.6 | – |
| Kıyı taşkını | Acil kıyı koruma önlemleri | 150 | 0.4 | – |
| | Riskli bölgelerde geçici tahliye (yaşam −2) | 80 | 0.6 | – |
| | Restore edilmiş kıyı ekosistemine güven | 0 | 0.5 | Kıyı restorasyonu |
| | Erken uyarı ve koordinasyon merkezini çalıştır | 30 | 0.35 | Kıyı restorasyonu |

Her krizde "Müdahale etme" (0 kredi, ×1.0) de vardır; böylece bütçesi biten oyuncu takılmaz.

Kriz aşamaları: risk uyarısı (yıl N sonu) → hazırlık (yıl N+1) → kriz (yıl N+1 sonu) → müdahale → sonuç ve hasar → yıl sonu raporu. Ayrıntı: `INTEGRATION_CONTRACT.md` §6.6.

## 7. İklim katmanları

**A. Yerel emisyonlar.** Enerji, ulaşım, binalar, atık sektörlerinde şehrin ürettiği sera gazı. Oyuncunun doğrudan etkilediği tek iklim değeri. Birimi oyun birimidir; arayüz "gerçek ton değeri değildir" notunu gösterir.

**B. Küresel atmosferik CO2 (ppm).** Yalnızca bilgi katmanıdır. Oyuncunun yatırımı bu sayıyı değiştirmez. İklim Laboratuvarı'nda şu mesaj verilir: tek bir şehrin emisyonu küresel yoğunluğa çok küçük katkı yapar; etki, dünyadaki bütün şehirlerin toplamıyla oluşur.

Veri kuralı:
- Geçmiş yıllar NOAA Global Monitoring Laboratory ölçümlerinden alınır (https://gml.noaa.gov/ccgg/trends/). `data/co2_scenario.tres` şu an 1959–2025 Mauna Loa yıllık ortalamalarını içerir (dosya tarihi 2026-10-09).
- 2040–2052 değerleri ölçüm değil, senaryodur. Henüz eklenmedi; oyun bu yıllar için "veri yok" gösterir. Bir IPCC AR6 senaryosundan (ör. SSP2-4.5) alınır ve arayüzde senaryo adıyla gösterilir.
- Kaynağı kontrol edilmemiş hiçbir sayı `co2_scenario.tres` dosyasına girmez. Değer yoksa oyun "veri yok" yazar.

**C. Yerel iklim riskleri.** Kuraklık, aşırı sıcak, kıyı taşkını. 0–100 oyun ölçeği. Yatırımlar riski değil hasarı azaltır; arayüzde ham risk ve korunmuş risk ayrı gösterilir.

## 8. Eğitim sistemi

- **Bilgi kartları:** her yatırım ve her kriz için bir `InfoCard`. Yapıda "Nedir? Neden önemli? Antalya'yla bağı" ve kaynak satırı.
- **Görevler:** yıl sonunda kontrol edilir, tamamlanınca ödül kredisi verilir, son yıl geçerse kaçar. HUD'da sol altta, raporda sonuçlarıyla görünür.

| id | Görev | Son yıl | Ödül |
|---|---|---|---|
| `water_75` | Su güvenliğini 75'e çıkar | 2045 | 50 |
| `quality_70` | Yaşam kalitesini 70'e çıkar | 2047 | 50 |
| `emissions_85` | Yerel emisyonu 85'in altına indir | 2048 | 50 |
| `ecosystem_65` | Ekosistem sağlığını 65'te tut | 2050 | 50 |

Hedef ödülleri Prompt 9A'da 100–150'den 50'ye indirildi: kombinasyonlarla birlikte yüksek ödüller ucuz binalardan başlayan stratejiyi "İklim Lideri"ne taşıyordu.
- **İklim Laboratuvarı:** dört sekme (yerel emisyonlar, küresel CO2, yerel riskler, bilgi kartları).
- **Grafikler:** yıllık geçmişten çizgi grafikler.

Kaynak kuralları:
- Kartta sayı varsa yanında kaynak olur. Kaynak yoksa sayı yazılmaz, kart nitel anlatır.
- Kaynak satırı biçimi: "Kurum, belge adı, yıl, URL, erişim tarihi".
- Aday kurumlar: IPCC AR6 raporları (https://www.ipcc.ch/report/ar6/syr/), NOAA GML, Meteoroloji Genel Müdürlüğü, T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı. Her URL eklenmeden önce açılıp kontrol edilir.
- Oyun değerleri ile gerçek veriler arayüzde karıştırılmaz: oyun değerleri "oyun ölçeği" etiketi taşır.

**Öğrenme görevleri (Prompt 8):** İklim Laboratuvarı'nın "Öğrenme" sekmesinde, yıl sonunda değerlendirilir, kaçmaz ve **kredi vermez** (10 kredilik ödül bile basit stratejileri "İklim Lideri"ne taşıyıp dengeyi bozdu).

| id | Görev | Koşul |
|---|---|---|
| `learn_clean_energy` | Temiz enerjiye geçiş | Güneş enerjisi tesisi kur |
| `learn_save_water` | Suyunu koru | Su depolama kur |
| `learn_cooler_city` | Daha serin bir şehir | Yeşil park kur |
| `learn_zero_waste` | Atıksız şehre doğru | Geri dönüşüm ve kompost tesisi kur |
| `learn_prepared` | Krize hazırlık | Bir krizi koruyucu yatırım varken karşıla |

**İklim sözlüğü:** 17 kavram (`data/glossary/`), her birinde tanım, örnek, oyundaki bağlantısı ve doğrulanmış kaynak (NASA, US EPA, NOAA, IEA, FAO, UNCCD, The Nature Conservancy, Ellen MacArthur Foundation, IPCC SROCC).

## 9. Denge ölçümü (Gün 3)

`tests/balance_sim.gd` beş stratejiyi otomatik oynatır (yılda en çok bir yatırım, krizde en iyi karşılanabilir müdahale):

| Strateji | Puan | Not | Görev | Kriz kredi kaybı |
|---|---|---|---|---|
| Hiçbir şey yapma | 38 | Risk Altında | 0/4 | −472 |
| En ucuzdan başla | 78 | Dayanıklı Şehir | – | – |
| Önce koruma | 78 | Dayanıklı Şehir | – | – |
| Yalnız emisyon | 69 | Gelişen Şehir | – | – |
| Karma | 79 | Dayanıklı Şehir | – | – |

(Prompt 9A sonrası; görev sütunu artık 9 görev içerdiği için ayrıntı `tests/balance_sim.gd` çıktısındadır.)

"İklim Lideri" (85+) hiçbir otomatik stratejiyle gelmiyor; bilinçli, dengeli oyun ister. Sayılar değişince simülasyon yeniden çalıştırılır.

## 10. Görsel ve kamera

Low-poly 3D, gerçekçi ışık, yumuşak gölge. Akdeniz mimarisi: beyaz sıva, terracotta çatı, turkuaz deniz, yeşil parklar. İzometrik perspektif kamera; yakınlaştırma, ±30° döndürme, harita sınırında duran kaydırma. Arayüz sade ve modern: yarı saydam koyu paneller, tek vurgu rengi (turkuaz), ikonlu gösterge çubuğu.

## 11. Kapsam dışı (hackathon)

Kaydet/yükle, bina yıkma ve yükseltme, çok oyunculu, serbest inşaat, gerçek harita verisi, ses dublajı, yerelleştirme (oyun yalnızca Türkçe).
