# EDA (Efficiency Drift Analyzer) - Senior Review Bericht

## 1. Gesamturteil

**Release-Status: FAST BETA-REIF**

**Kurzbegründung:**
Das Projekt zeigt eine solide Architektur mit klarer Trennung der Verantwortlichkeiten. Die Module sind gut strukturiert und die Test-Abdeckung ist für kritische Bereiche vorhanden. Allerdings gibt es **konsistente Duplikationen** in Status-Konstanten zwischen EDAView und den extrahierten Modulen, die auf eine unvollständige Refactoring-Phase hindeuten. Die EDAView.mc Datei ist mit ~1200 Zeilen immer noch zu groß und enthält Logik, die in separaten Modulen bereits existiert.

**Hauptrisiken:**
1. Duplizierte Status-Konstanten (Status-Codes in EDAView vs. Magic Numbers in EDAStatusManager)
2. Nicht-refaktorierte Methoden in EDAView, die bereits in separaten Modulen existieren
3. Potenzielle Inklusion von `getDataDrivenGapMs()` in EDAFeatureFlags (Referenziert in EDAView, aber nicht definiert)

---

## 2. Kritische Probleme

### Problem 1: Duplizierte Status-Konstanten
- **Schweregrad: HOCH**
- **Betroffene Datei:** `source/Efficiency-Drift-AnalyzerView.mc` (Zeilen 38-52) und `source/EDAStatusManager.mc` (Zeilen 30-44)
- **Warum problematisch:** Status-Codes sind in EDAView als `private const` definiert (z.B. `STATUS_WAIT = 1`), während EDAStatusManager Magic Numbers verwendet. Dies führt zu:
  - Möglichen Inkonsistenzen bei Änderungen
  - Wartungsproblemen
  - Versteckten Bugs wenn Codes geändert werden
- **Konkrete Reparatur:** Entferne die Status-Konstanten aus EDAView und verwende nur die EDAStatusManager-Funktionen. Oder definiere die Konstanten in einem gemeinsamen `EDATypes.mc` Modul.

**Korrigierter Code (Vorschlag):**
```monkeyc
// In EDAView.mc - ENTFERNE diese Zeilen:
private const STATUS_VALUE as Number = 0;
private const STATUS_WAIT as Number = 1;
private const STATUS_PAUSE as Number = 2;
// ... etc.

// Stattdessen: Verwende EDAStatusManager für alle Status-Abfragen
private function getStatusLabel(statusCode as Number) as String {
    return EDAStatusManager.getStatusLabel(statusCode, /* alle Strings */);
}
```

### Problem 2: Nicht-definierte Feature-Flag-Funktion
- **Schweregrad: KRITISCH**
- **Betroffene Datei:** `source/EDAFeatureFlags.mc` und `source/Efficiency-Drift-AnalyzerView.mc`
- **Warum problematisch:** EDAView.mc referenziert `EDAFeatureFlags.getDataDrivenGapMs()` (Zeile 642), aber diese Funktion existiert nicht in EDAFeatureFlags.mc. Dies führt zu:
  - **Compile-Fehler** auf echten Geräten
  - App-Crash beim Start
- **Konkrete Reparatur:** Füge die fehlende Funktion in EDAFeatureFlags.mc hinzu.

**Korrigierter Code:**
```monkeyc
// In EDAFeatureFlags.mc - Füge diese Funktion hinzu:
function getDataDrivenGapMs() as Number {
    return getMaxDataDrivenGapMs();
}
```

### Problem 3: EDAView enthält Logik, die bereits extrahiert wurde
- **Schweregrad: MITTEL**
- **Betroffene Datei:** `source/Efficiency-Drift-AnalyzerView.mc`
- **Warum problematisch:** Obwohl die Module `EDALifecycleManager`, `EDAWorkloadSourceSelector`, und `EDAStatusManager` bereits extrahiert wurden, enthält EDAView.mc immer noch:
  - Duplizierte Workload-Source-Selection-Logik (Zeilen 900-950)
  - Duplizierte Lifecycle-Logik (Zeilen 300-350)
  - Duplizierte Status-Label-Funktionen (Zeilen 600-650)
- **Konkrete Reparatur:** Refaktoriere EDAView.mc, um die extrahierten Module konsistent zu nutzen.

---

## 3. Garmin-spezifische Risiken

### 3.1 Gerätekompatibilität
**Status: GUT**
- Manifest deckt 34 Geräte ab (enduro3, epix2, fenix7/8, fr165/255/265/955/965, marq2, venu2/3)
- `(:high_mem)` und `(:low_mem)` Annotationen für Speicher-optimierte Builds
- Font-Größen passen sich an Display-Höhe an (140px, 180px, 200px Schwellen)

**Risiko:** Keine explizite Prüfung für AMOLED vs. MIP Displays. Die Farbwahl (`COLOR_GREEN`, `COLOR_YELLOW`, `COLOR_RED`) könnte auf AMOLED anders aussehen.

### 3.2 Speicher / Performance
**Status: MITTEL**
- **EDADriftEngine:** 3 Arrays mit je 120 Elementen (`mDriftWeightedBuckets`, `mDriftValidBuckets`, `mDriftBucketKeys`)
  - Auf FR245 (low_mem) = ~1.4KB
  - Auf Fenix8 (high_mem) = ~2.8KB
  - **Risiko:** Könnte auf sehr speicherlimitierten Geräten (FR245) knapp werden

- **EDAView:** Enthält viele String-Variablen (~80 Strings)
  - String-Konkatenation in `refreshRenderCache()` bei jedem Update
  - **Risiko:** Wiederholte String-Allokationen im Hot-Path

- **EWMA-Filter:** Math.pow() und Math.E Verwendung
  - **Risiko:** Floating-Point-Operationen sind auf Garmin-Geräten langsam

**Empfehlung:**
1. Prüfe, ob EDADriftEngine-Buckets reduziert werden können (z.B. 60 statt 120)
2. Verwende String-Pooling für Status-Labels
3. Ersetze `Math.pow(Math.E, -x)` durch `Math.exp(-x)` wenn verfügbar

### 3.3 Background-Verhalten
**Status: UNKLAR**
- Kein Background-Service implementiert (nur Data Field)
- **Risiko:** Wenn die App im Hintergrund läuft (z.B. bei Multisport), könnte der Timer-State inkonsistent werden

### 3.4 Manifest / Permissions
**Status: GUT**
- Permissions: `FitContributor`, `Sensor`, `UserProfile` - alle notwendig
- Keine unnötigen Permissions
- **Store-Review-Risiko:** Keine erkennbar

### 3.5 Store-Review-Risiken
**Status: GUT**
- Keine Debug-Logs in Produktion (`ENABLE_DEBUG_LOGGING = false`)
- Keine unnötigen Permissions
- Klare App-Beschreibung
- **Risiko:** Keine erkennbar

---

## 4. Nächste Iteration

### 1. Hauptziel
**Refactoring der EDAView.mc Duplikationen und Behebung des fehlenden Feature-Flags**

### 2. Konkrete Änderungen (in Prioritätsreihenfolge)

1. **KRITISCH: Fehlende Funktion in EDAFeatureFlags.mc hinzufügen**
   ```monkeyc
   function getDataDrivenGapMs() as Number {
       return getMaxDataDrivenGapMs();
   }
   ```

2. **Status-Konstanten konsolidieren**
   - Erstelle `source/EDATypes.mc` mit gemeinsamen Status-Konstanten
   - Entferne Duplikate aus EDAView.mc
   - Aktualisiere EDAStatusManager.mc zum Import der Konstanten

3. **EDAView.mc Refactoring - Phase 1**
   - Entferne duplizierte Workload-Source-Selection-Logik
   - Verwende nur `EDAWorkloadSourceSelector` Methoden

4. **EDAView.mc Refactoring - Phase 2**
   - Entferne duplizierte Lifecycle-Logik
   - Verwende nur `EDALifecycleManager` Methoden

5. **EDAView.mc Refactoring - Phase 3**
   - Entferne duplizierte Status-Label-Funktionen
   - Verwende nur `EDAStatusManager` Methoden

6. **String-Optimierung**
   - Pooling für Status-Labels
   - Reduktion der String-Variablen in EDAView

### 3. Empfohlene Reihenfolge
1. Sofort: Problem 2 (getDataDrivenGapMs) - **Compile-Blocking**
2. Danach: Problem 1 (Status-Konstanten) - **Wartbarkeit**
3. Danach: Problem 3 (EDAView Refactoring) - **Code-Qualität**

### 4. Bewusst noch nicht angefasst
- Font-Optimierung für AMOLED/MIP
- Background-Service-Implementierung
- Performance-Benchmarks auf echten Geräten
- Erweiterung der Test-Abdeckung (ProfileResolver, FitExportState)

---

## 5. Abnahmekriterien

Diese Iteration ist **abgenommen**, wenn:

1. ✅ `EDAFeatureFlags.getDataDrivenGapMs()` existiert und korrekt implementiert ist
2. ✅ Keine duplizierte Status-Konstanten zwischen EDAView und EDAStatusManager existieren
3. ✅ EDAView.mc keine duplizierte Workload-Source-Selection-Logik enthält
4. ✅ EDAView.mc keine duplizierte Lifecycle-Logik enthält
5. ✅ Alle bestehenden Tests weiterhin grün sind
6. ✅ Die App auf mindestens 3 verschiedenen Geräten (FR245, Fenix7, Venu3) ohne Compile-Fehler startet