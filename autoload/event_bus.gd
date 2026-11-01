extends Node
## ORTAK dosya. Sözleşme: docs/INTEGRATION_CONTRACT.md
## Sürüm v1.10. Yalnızca sinyal bildirimleri. Değişken, fonksiyon, mantık eklenmez.
## Değişiklik yalnızca sözleşme §11 süreciyle, yalnızca ekleme olarak.

# Sinyaller başka script'lerden yayılır; bu dosyada kullanılmamaları normal.
@warning_ignore_start("unused_signal")

# --- 3.1 Arsa ve inşaat ---
signal plot_selected(plot_id: StringName, plot_kind: StringName, is_empty: bool)  # A: CityWorld
signal plot_deselected  # A: CityWorld
signal build_requested(plot_id: StringName, building_id: StringName)  # B: BuildPanel
signal build_approved(plot_id: StringName, building_id: StringName)  # B: GameController
signal build_rejected(plot_id: StringName, building_id: StringName, reason: StringName)  # B: GameController
signal plot_deselect_requested  # B: BuildPanel (kapat düğmesi, Esc) → A: CityWorld seçimi bırakır (v1.3)

# --- 3.2 Durum ve tur ---
signal stats_changed(stats: Dictionary)  # B: GameState
signal phase_changed(phase: StringName)  # B: TurnManager
signal end_turn_requested  # B: HUD
signal year_started(year: int)  # B: TurnManager
signal year_ended(report: Dictionary)  # B: TurnManager
signal report_closed  # B: YearReport
signal game_over(summary: Dictionary)  # B: TurnManager

# --- 3.3 Kriz ---
signal crisis_warned(warning: Dictionary)  # B: TurnManager
signal crisis_started(event_id: StringName, risk_type: StringName, severity: float)  # B: TurnManager
signal crisis_response_chosen(event_id: StringName, response_id: StringName)  # B: EventPanel
signal crisis_resolved(result: Dictionary)  # B: TurnManager
## v1.5: krizin yaşam döngüsü (görseller için). stage: warning, preparation, active, resolved, ended. info: sözleşme §5.6 (v1.6: mitigation, advantages)
signal crisis_stage_changed(event_id: StringName, stage: StringName, info: Dictionary)  # B: TurnManager

# --- 3.4 Final sunumu (v1.9, docs/FINAL_VISUAL_CONTRACT.md) ---
## Oyuncu final raporundaki "Şehrin dönüşümünü izle" düğmesine bastı. summary: game_over ile aynı sözlük.
signal final_presentation_requested(summary: Dictionary)  # B: FinalReport → A: CityWorld
## A'nın 2040 → 2052 sunumu bitti (veya hiç başlamadı); final raporu yeniden görünür.
signal final_presentation_finished  # A: CityWorld → B: FinalReport

# --- 3.5 İşletmeler ve çevre denetimi (v1.10, docs/BUSINESS_SYSTEM.md) ---
## Yeni işletme kuruldu ya da kayıttan geri yüklendi (info.restored). info: BusinessSimulator.visual_info sözlüğü.
signal business_spawned(info: Dictionary)  # B: GameController → A: CityWorld (sanayi yerine model koyar)
## Faaliyet durumu, ihlal seviyesi, duman yoğunluğu ya da yükseltmeler değişti. info: aynı sözlük.
signal business_updated(info: Dictionary)  # B: GameController → A
## İşletme kapandı; sanayi yeri boşaldı.
signal business_removed(business_id: StringName, site_id: StringName)  # B: GameController → A
