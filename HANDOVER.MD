==============================================================================
HANDOVER: EDA - Status: LOGIC REPAIRED / STAGING (v0.9.9)
==============================================================================

### ARCHITEKTUR-UPDATE (10-MAI-2026)
- Timer-Integritaet: Implementierung der "Catch-up Rule". Rollbacks < 5s 
  frieren den Zeitanker ein, anstatt Daten zu korrumpieren oder die Session 
  vorzeitig zu resetten.
- Soft Config Guard: Fehlende Kalibrierungswerte (hrA/paceA) blockieren nur 
  noch die Drift-Berechnung (Engine), nicht mehr das gesamte App-Lifecycle.
- Profil-Resilienz: STALE-Zustand (ID 4) puffert transiente API-Fehler. 
  Aktivitaetstypen werden nur beibehalten, wenn sie zuvor zweifelsfrei 
  AUTHORITATIVE waren.
- Speicherprofil: Strikt O(1). 120 Slots im Ringpuffer (10s Samples).

### STATUS-HIERARCHIE (UI)
1. CFG MISSING (Keine Kalibrierung vorhanden)
2. NOT SAVED (FIT-Export noch blockiert/Fallback-Phase)
3. TYPE UNKN (Fallback aktiv, Typ unbestaetigt)
4. STALE (Revalidierung temporaer fehlgeschlagen)

### KONFORMITAET
- SDK: 8.4.1 (Static Analysis bereinigt)
- FIT-IDs: profile_state (ID 2), avg_metabolic_drift (ID 1)
==============================================================================