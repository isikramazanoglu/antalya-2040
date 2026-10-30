# ANTALYA 2040 · Claude oturumları için kurallar

Godot 4.7.2 Stable Standard, GDScript, 3D. İki kişilik ekip, iki ayrı bilgisayar, iki ayrı Claude oturumu.

## İşe başlamadan
1. `docs/INTEGRATION_CONTRACT.md`, `docs/PROJECT_ARCHITECTURE.md`, `docs/GAME_DESIGN.md`, `docs/PROGRESS.md` oku.
2. Kullanıcıya hangi ekipte olduğunu sor: **A** (şehir ve 3D) veya **B** (simülasyon ve arayüz).
3. `git status` ve `git branch` ile doğru dalda olduğunu kontrol et (`feature/city-world` veya `feature/simulation-ui`).

## Kesin kurallar
- Yalnızca kendi ekibinin dosyalarını değiştir (sahiplik tablosu: PROJECT_ARCHITECTURE §8).
- Ekipler arası iletişim yalnızca `EventBus` sinyalleri ve sözleşme §4 fonksiyonlarıyla. Diğer ekibin node yollarına `get_node` ile erişme.
- `autoload/event_bus.gd` ve `docs/INTEGRATION_CONTRACT.md` yalnızca sözleşme §11 süreciyle, yalnızca ekleme olarak değişir.
- `GameState`'e yalnızca `GameController` yazar.
- Sayılar kodda değil `data/*.tres` dosyalarında durur.
- Kaynağı doğrulanmamış bilimsel sayı yazma.
- Bir `.tscn` dosyasını diğer ekip açıkken değiştirme; başkasının sahnesini kaydetme.
- Commit'te yalnızca kendi yollarını ekle (`git add <yol>`, `git add .` değil). Önekler: `world:`, `sim:`, `ui:`, `data:`, `contract:`, `docs:`, `fix:`, `chore:`.
- `.uid` ve `.import` dosyalarını commit'e dahil et; `.godot/` asla.
- İş bitince `docs/PROGRESS.md` içinde yalnızca kendi ekibinin kutularını işaretle.

## Doğrulama
macOS'ta Godot: `/Applications/Godot.app/Contents/MacOS/Godot`. Windows'ta kurulu yol farklıdır.
- Script hatası kontrolü: `<godot> --headless --path . --import`
- Sahneyi kısa çalıştırma: `<godot> --headless --path . --quit-after 120 res://scenes/main/Game.tscn`
- Ekip B akış testi: `<godot> --headless --path . --script res://tests/test_day1_flow.gd` (SONUÇ: TAMAM beklenir)
