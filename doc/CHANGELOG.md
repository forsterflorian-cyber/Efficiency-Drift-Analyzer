# Changelog - Efficiency-Drift-Analyzer

## [0.9.9-alpha] - 2026-03-10
### Hinzugefuegt
- Soft-Config-Guard: 'CFG MISSING' Warnung statt App-Blockade.
- Timer-Catch-up: Schutz gegen Datenkorruption bei Jitter < 5s.
- Neutral-Mode-Sicherung: STALE setzt auf neutralen Modus zurueck, 
  sofern kein Vor-Erfolg (Authoritative) vorlag.

## [0.9.5-alpha] - 2026-03-10
### Hinzugefuegt
- Pausen-Kontinuitaet: Baseline-Erhalt bei Kurzstopps (< 300s).
- NaN-Rendering: Platzhalter "--" fuer invalide Live-Werte.

## [0.9.0-alpha] - 2026-03-10
### Geaendert
- Vollstaendige Modularisierung (Resolver, Engine, Renderer, ExportState).
- FIT_SPEC.json als maschinenlesbarer Vertrag hinzugefuegt.

## [0.5.0-alpha] - 2026-03-09
### Hinzugefuegt
- Profil-Zustandsmaschine (UNRESOLVED bis AUTHORITATIVE).
- Reversibler Fallback-Mechanismus.

## [0.2.x-alpha] - 2026-03-09
- Initialer Build mit O(1) Ringbuffer und FIT 2.0 Integration.