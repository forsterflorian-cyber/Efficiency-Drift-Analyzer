# Changelog - Efficiency-Drift-Analyzer

## [0.2.4-alpha] - 2026-03-09
- Performance: Inkrementelle Drift-Berechnung (O(1)) fuer High-Mem.
- Robustheit: Zeitnormalisierte HR-Spike-Erkennung via deltaMs.
- Robustheit: 30s Timeout fuer Profil-Erkennung mit Fallback auf "Running".
- UX: Validierung von Benutzereinstellungen (min/max/required).
- UX: Praezisierung der Pace-Einheiten in den Einstellungen.
- Hygiene: Entfernung ungenutzter Background- und Layout-Ressourcen.

## [0.2.3-alpha] - 2026-03-09
- Behoben: "Lap-Starvation" - Analyse laeuft ueber Laps hinweg weiter.
- Neu: Trennung der FIT-Session-Werte bei Multisport-Wechseln.
- Fix: Analyse-Reset bei Einstellungs-Aenderungen waehrend der Aktivitaet.