# Efficiency-Drift-Analyzer (EDA)

Professionelles Garmin DataField zur Echtzeit-Analyse der aeroben Entkopplung (Aerobic Decoupling). 
Das Tool führt ein "metabolisches Audit" durch, indem es die aktuelle Herzfrequenz gegen ein 
individuell kalibriertes Leistungs-Soll validiert.

## 1. Mathematisches Modell
Die App basiert auf einer Zwei-Punkt-Linear-Regression:
$HR = m * v + b$

Dabei werden zwei Nutzer-Ankerpunkte verwendet:
- Punkt A: Aerobe Schwelle (GA1 / Zone 2)
- Punkt B: Laktatschwelle (Pace & HR am Schwellenwert)

## 2. Konfiguration (Settings)
Die Kalibrierung erfolgt über die Connect IQ App oder Garmin Express. 
Pace-Werte müssen in Sekunden pro Kilometer (s/km) angegeben werden.

| Parameter | Beispiel (4:30 min/km) | Beispiel (6:00 min/km) |
|-----------|-----------------------|-----------------------|
| Pace      | 270                   | 360                   |
| HR        | 163 bpm               | 130 bpm               |

Wichtig: Die App zeigt "SET-UP" an, solange die Werte auf 0 stehen.

## 3. Daten-Filterung & Logik
- EWMA Pace Filter: Alpha 0.20 (~5s Glättung für reaktive Anzeige)
- EWMA HR Filter:   Alpha 0.03 (~30s Glättung gegen Cardiac Lag)
- EWMA Drift Filter: Alpha 0.05 (~20s Glättung des Ergebnisses)
- Warm-up: 180s Countdown vor Berechnungsstart (verhindert Fehlwerte bei Kaltstart).
- Deadzone: Drift-Werte innerhalb von +/- 1.0% werden als 0.0% stabilisiert.

## 4. Display-Layout
1. Pace:      Aktuelle Laufgeschwindigkeit (unverzögert)
2. Erw. Pace: Geschwindigkeit, die dem aktuellen Puls entspricht
3. DRIFT:     Prozentualer "Aufpreis" (Grün <3%, Gelb 3-7%, Rot >7%)
4. Erw. HR:   Ziel-Puls für die aktuelle Geschwindigkeit
5. HR:        Geglättete Echtzeit-Herzfrequenz

## 5. FIT-Logging
Die App schreibt zwei Felder direkt in die .FIT Datei:
- 'metabolic_drift': Zeitlicher Verlauf als Graph in Garmin Connect.
- 'avg_metabolic_drift': Durchschnittswert der Einheit (nach Warm-up).