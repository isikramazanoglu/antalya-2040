extends Node
## ORTAK dosya. Sözleşme: docs/INTEGRATION_CONTRACT.md v1.0
## Yalnızca sinyal bildirimleri. Değişken, fonksiyon, mantık eklenmez.
## Değişiklik yalnızca sözleşme §11 süreciyle, yalnızca ekleme olarak.

# Sinyaller başka script'lerden yayılır; bu dosyada kullanılmamaları normal.
@warning_ignore_start("unused_signal")

# --- 3.1 Arsa ve inşaat ---
signal plot_selected(plot_id: StringName, plot_kind: StringName, is_empty: bool)  # A: CityWorld
signal plot_deselected  # A: CityWorld
signal build_requested(plot_id: StringName, building_id: StringName)  # B: BuildPanel
signal build_approved(plot_id: StringName, building_id: StringName)  # B: GameController
signal build_rejected(plot_id: StringName, building_id: StringName, reason: StringName)  # B: GameController

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
