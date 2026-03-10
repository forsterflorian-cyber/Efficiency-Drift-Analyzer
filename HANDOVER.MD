==============================================================================
HANDOVER: EDA - Status: RESPONSIVE UI & TEXT BUDGETING (v0.9.13)
==============================================================================

### ARCHITEKTUR-UPDATE (10-MAR-2026)
- Responsive Rendering: EDARenderer misst Textbreiten dynamisch via 
  getTextWidthInPixels() vor dem Zeichnen.
- Fallback-Logik: Einfuehrung von Short-Strings und dynamischer Truncation 
  (...) zur Vermeidung von UI-Clipping auf Low-Memory-Geraeten (z. B. fr245).
- View-Entlastung: Die View liefert parallele Full- und Short-Varianten 
  an die Render-Modelle, um Laufzeit-Overhead im OnUpdate-Zyklus zu minimieren.
- Lokalisierung: 'resources' und 'resources-de' um explizite Kurzformen fuer 
  Status- und Fehlermeldungen erweitert.

### STATUS-HIERARCHIE (UI)
1. CFG MISSING (Kurz: KONFIG FEHLT / NO CFG)
2. NOT SAVED (Kurz: NO SAV)
3. TYPE UNKN (Kurz: UNKN)
4. STALE (Degraded Mode)
5. WARMUP / WAIT

### KONFORMITAET
- Design: Relative Design-Vorgaben fuer alle Displaygroessen erfuellt.
- Build: Verifiziert fuer fr245 (Low-Mem) und fr955 (High-Mem).
==============================================================================