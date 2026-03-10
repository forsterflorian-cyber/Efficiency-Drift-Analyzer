
# Changelog - Efficiency-Drift-Analyzer
## [0.9.13-alpha] - 2026-03-10
### Hinzugefuegt
- Responsive Rendering: Dynamische Messung der Textbreite in EDARenderer zur 
  Vermeidung von Clipping.
- Short-Strings: Zusaetzliche kurze Ressourcen-IDs fuer Statusmeldungen 
  implementiert (z. B. fuer fr55/fr245).
- Truncation: Automatisches Abschneiden (...) von Texten, die das visuelle 
  Budget ueberschreiten.

### Geaendert
- Architektur: View ubergibt nun dedizierte Short- und Full-String-Modelle 
  an den Renderer, um Render-Zyklen zu optimieren.
## [0.9.12-alpha] - 2026-03-10
### Geaendert
- Architektur: Interne Statusverwaltung von Literal-Strings auf numerische 
  Codes migriert.
- UI: Harte Status-Strings durch lokalisierte Ressourcen-IDs ersetzt.
- Lifecycle: Selektiver Reset der EDADriftEngine bei Settings-Updates. 
  Verhindert Datenverlust bei reinen System- oder Sprachwechseln.
- Engine: Bucket-Gewichtung in der Drift-Berechnung erfolgt nun proportional 
  zu den realen validen Millisekunden.

### Behoben
- Fix: STALE-Status behandelt alte Profile nicht mehr als autoritativ.
- Fix: Target-UI-Leak geschlossen (Sollwerte werden bei invaliden States 
  via resetTargetDisplay geloescht).
- Fix: Session-Summary wird bei transienten Gaps nicht mehr verworfen.

## [0.9.11-alpha] - 2026-03-10
### Geaendert
- Engine-Logik: Umstellung auf progressives Halbfenster-Modell (Hybrid-Filter).
- Warmup-Phase: Die ersten 3 Minuten fliessen nun direkt in den Puffer ein.
- Drift-Ausgabe: Startet exakt nach 3 Minuten (180.000 ms) statt nach 
  vollstaendiger Pufferfuellung.

### Hinzugefuegt
- Live-Data-Fallback: Anzeige roher HR/Pace-Werte waehrend der WAIT-Phase.
- Division-by-Zero-Guards: Absicherung fuer teilgefuellte Puffer-Splits.

## [0.9.10-alpha] - 2026-03-10
### Geaendert
- Fix: Einheiten-Fehler bei der Berechnung der erwarteten Herzfrequenz.
- Fix: Plausibilitaets-Pruefung fuer HR-Werte (Begrenzung auf 220 bpm).
- Korrektur: Interne Umrechnung von min/km in m/s fuer paceA.

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