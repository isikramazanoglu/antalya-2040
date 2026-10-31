# Değişiklik günlüğü

## Yayın adayı (2026-10-31, develop)
Tüm Prompt 10 işleri birleşik; v1.0 etiketi main'e birleştirme ve demo provasından sonra.

### Prompt 10B · Final şehir sunumu (A) ve entegrasyonu (B)
- "Şehrin dönüşümünü izle": 2040 binasız şehir → yatırımlar inşa yılına göre → geçmiş krizler ve koruma oranı → 2052 → karşılaştırma; sinematik kamera, Esc ile atlama.
- Sunum GameState'e yazmaz, bitince kamera ve rapor geri gelir. 1280×720 ve 1920×1080'de doğrulandı.
- Windows demo paketi 10B ile yeniden üretildi.

### Prompt 10C · Final entegrasyon ve kalite (B)
- Gerçek oyuncu gibi tam oynanış testi (`tests/test_playthrough.gd`): menüden 2052 final raporuna, tıklama ve UI düğmeleriyle.
- Düzeltme: BuildPanel'de alttaki yatırım kartları ayrıntı alanının arkasında kalıyordu; seçim yokken ayrıntı gizlenir, seçilen kart görünür alana kaydırılır.
- Denge simülasyonuna "ekonomik büyüme" senaryosu ve alt puan dökümü.
- Windows demo paketi: `build/windows/`, `build/ANTALYA2040_Windows_Demo.zip` (OKUBENI.txt ile); README ve bu günlük.

### Prompt 10A · Final değerlendirmesi (B) — sözleşme v1.9
Yıllık arşiv, 7 boyutlu final değerlendirmesi, final raporu, JSON dışa aktarma, final görsel sözleşmesi. 2040 başlangıç kaydındaki enerji/su eksikliği düzeltildi.

### Prompt 9A/9B · 12 yatırım
B: 6 kombinasyon, geri kazanılmış su ayrımı (v1.8), veri doğrulama, denge. A: 12 bina modeli yenilendi, krizde binalar tepki veriyor.

### Prompt 8 · İklim Laboratuvarı ve eğitim (B) — v1.7
A–D bölümleri, 17 kavramlık sözlük, eğitim kartları, öğrenme görevleri, doğrulanmış kaynaklar.

### Prompt 7A/7B · Kriz sistemi — v1.5, v1.6
B: risk temelli hasar, altyapıya bağlı müdahaleler, kriz aşama sinyali. A: aşamalı kriz görselleri, koruma halesi, rezervuar.

### Prompt 5–6 · Arayüz ve tam entegrasyon — v1.3, v1.4
B: profesyonel HUD, yatırım kartları, bildirimler, sahne/arsa kontrolü. A: seçim bırakma, kamera güvenli alan.

### Prompt 2–4 · Menü, şehir, ekonomi — v1.2
B: ana menü, enerji/su akışları. A: belediye meydanı, marina, rüzgâr, MultiMesh.

### Gün 0–3 · Prototipten oynanabilir oyuna — v1.0, v1.1
İskelet, sözleşme, 15 arsa, 12 yatırım, iklim simülasyonu, 3 kriz, görevler, İklim Laboratuvarı, Windows export.
