# Changelog - Efficiency-Drift-Analyzer

## [0.2.2-alpha] - 2026-03-09
- Behoben: Session-Integritaet fuer isRunningActivity und Sportprofile.
- Optimierung: resolveActivityProfile() behandelt null-Werte jetzt sicher.

## [0.2.1-alpha] - 2026-03-09
- Korrektur der Regressions-Mathematik fuer Meilen-Einheiten.
- Umstellung auf festen Ringbuffer fuer :low_mem (Memory Safety).
- Implementierung von resetSessionState() fuer saubere Intervall-Wechsel.
- Warm-up Schutz (180s) basierend auf aktiver Zeit finalisiert.
- FIT-Session-Durchschnitt fuer Garmin Connect korrigiert.
- UI-Placeholder fuer Signalverlust (HR/GPS) hinzugefuegt.