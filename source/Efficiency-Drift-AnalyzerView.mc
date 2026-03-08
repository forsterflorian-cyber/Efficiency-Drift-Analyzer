import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.FitContributor;

class EDAView extends WatchUi.DataField {

    // --- Konfiguration & Konstanten ---
    private const ALPHA_SPEED as Float = 0.20;
    private const ALPHA_HR as Float    = 0.03;
    private const ALPHA_DRIFT as Float = 0.05;
    private const WARMUP_MS as Number  = 180000; 
    private const DRIFT_DEADZONE as Float = 1.0;

    // --- Interne Berechnungs-Variablen ---
    private var hrA as Float = 0.0;
    private var paceA as Float = 0.0; 
    private var hrB as Float = 0.0;
    private var paceB as Float = 0.0; 
    private var m as Float = 0.0;
    private var b as Float = 0.0;

    // --- Status & Timer ---
    private var ewmaSpeed as Float = 0.0;
    private var ewmaHr as Float = 0.0;
    private var ewmaDrift as Float = 0.0;
    private var filterInitialized as Boolean = false;
    private var driftInitialized as Boolean = false;
    private var isConfigured as Boolean = false;
    private var mTimerTime as Number = 0; // Speichert die Zeit für onUpdate

    // --- UI & Lokalisierung ---
    private var lblAktPace as String = "";
    private var lblSollPace as String = "";
    private var lblSollHr as String = "";
    private var lblAktHr as String = "";
    private var isGerman as Boolean = false;

    private var valAktPace as String = "--:--";
    private var valSollPace as String = "--:--";
    private var strDrift as String = "--";
    private var valSollHr as String = "--";
    private var valAktHr as String = "--";
    
    private var bgColor as Number = Graphics.COLOR_WHITE;
    private var fgColor as Number = Graphics.COLOR_BLACK;

    // --- FIT Contribution ---
    private var driftField as Toybox.FitContributor.Field? = null;
    private var avgDriftField as Toybox.FitContributor.Field? = null;
    private const DRIFT_GRAPH_ID = 0;
    private const DRIFT_AVG_ID = 1;

    private var driftSum as Float = 0.0;
    private var driftCount as Number = 0;

    function initialize() {
        DataField.initialize();
        loadStrings();
        loadSettings();

        driftField = createField("metabolic_drift", DRIFT_GRAPH_ID, FitContributor.DATA_TYPE_FLOAT, { :displayLabel => "Drift", :units => "%" });
        avgDriftField = createField("avg_metabolic_drift", DRIFT_AVG_ID, FitContributor.DATA_TYPE_FLOAT, { :displayLabel => "Avg Drift", :units => "%" });
    }

    private function loadStrings() {
        lblAktPace = WatchUi.loadResource(Rez.Strings.lblAktPace) as String;
        lblSollPace = WatchUi.loadResource(Rez.Strings.lblSollPace) as String;
        lblSollHr = WatchUi.loadResource(Rez.Strings.lblSollHr) as String;
        lblAktHr = WatchUi.loadResource(Rez.Strings.lblAktHr) as String;
        isGerman = (lblSollPace.substring(0, 1).equals("E")); 
    }

    function loadSettings() as Void {
        try {
            hrA = Properties.getValue("hrA").toFloat();
            paceA = Properties.getValue("paceA").toFloat();
            hrB = Properties.getValue("hrB").toFloat();
            paceB = Properties.getValue("paceB").toFloat();
            isConfigured = (hrA > 0 && hrB > 0 && paceA > 0 && paceB > 0);
        } catch (e) {
            isConfigured = false;
        }
        calculateLinearModel();
    }

    private function calculateLinearModel() as Void {
        var v1 = (paceA > 0) ? 1000.0 / paceA : 0.0;
        var v2 = (paceB > 0) ? 1000.0 / paceB : 0.0;
        if (v2 - v1 != 0) {
            m = (hrB - hrA) / (v2 - v1);
            b = hrA - (m * v1);
        }
    }

    private function formatPace(speedInMs as Float) as String {
        if (speedInMs <= 0.2) { return "--:--"; }
        var secondsPerKm = 1000.0 / speedInMs;
        var minutes = (secondsPerKm / 60).toNumber();
        var seconds = (secondsPerKm.toNumber() % 60);
        return minutes.toString() + ":" + seconds.format("%02d");
    }

    function compute(info as Activity.Info) as Void {
        var curSpeed = info.currentSpeed;
        var curHr = info.currentHeartRate;
        mTimerTime = (info.timerTime != null) ? info.timerTime : 0;

        if (curSpeed == null || curHr == null || m == 0.0) {
            resetDisplay();
            return;
        }

        if (!filterInitialized) {
            ewmaSpeed = curSpeed.toFloat();
            ewmaHr = curHr.toFloat();
            filterInitialized = true;
        } else {
            ewmaSpeed = (ALPHA_SPEED * curSpeed) + ((1.0 - ALPHA_SPEED) * ewmaSpeed);
            ewmaHr = (ALPHA_HR * curHr) + ((1.0 - ALPHA_HR) * ewmaHr);
        }

        valAktPace = formatPace(curSpeed.toFloat());
        valAktHr = ewmaHr.toNumber().toString();

        if (!isConfigured) {
            strDrift = "SET-UP";
            resetDisplayStrings();
            return;
        }

        if (curSpeed <= 1.0 || ewmaSpeed <= 1.0) {
            strDrift = "STOP";
            resetDisplayStrings();
            return;
        }

        if (mTimerTime < WARMUP_MS) {
            strDrift = "Warm-up";
            resetDisplayStrings();
            bgColor = getBackgroundColor();
            fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            return;
        }

        var hrSoll = (m * ewmaSpeed) + b;
        var vSoll = (ewmaHr - b) / m;
        valSollPace = (vSoll <= 0.5) ? "LOW" : formatPace(vSoll);
        valSollHr = (hrSoll > 0) ? hrSoll.toNumber().toString() : "--";

        if (hrSoll > 0) {
            var rawDrift = ((ewmaHr / hrSoll) - 1.0) * 100.0;
            if (!driftInitialized) {
                ewmaDrift = rawDrift;
                driftInitialized = true;
            } else {
                ewmaDrift = (ALPHA_DRIFT * rawDrift) + ((1.0 - ALPHA_DRIFT) * ewmaDrift);
            }

            var displayDrift = (ewmaDrift.abs() < DRIFT_DEADZONE) ? 0.0 : ewmaDrift;
            updateColorsAndText(displayDrift);

            if (info.timerState == Activity.TIMER_STATE_ON) {
                if (driftField != null) { driftField.setData(displayDrift); }
                driftSum += displayDrift;
                driftCount++;
                if (avgDriftField != null && driftCount > 0) {
                    avgDriftField.setData(driftSum / driftCount);
                }
            }
        }
    }

    private function resetDisplay() {
        valAktPace = "--:--";
        resetDisplayStrings();
        strDrift = "--";
        bgColor = getBackgroundColor();
        fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    private function resetDisplayStrings() {
        valSollPace = "--:--";
        valSollHr = "--";
    }

    private function updateColorsAndText(driftPercent as Float) {
        var sign = driftPercent > 0 ? "+" : "";
        strDrift = sign + driftPercent.format("%.1f") + "%";
        if (driftPercent < 3.0) {
            bgColor = Graphics.COLOR_GREEN;
            fgColor = Graphics.COLOR_BLACK;
        } else if (driftPercent >= 3.0 && driftPercent <= 7.0) {
            bgColor = Graphics.COLOR_YELLOW;
            fgColor = Graphics.COLOR_BLACK;
        } else {
            bgColor = Graphics.COLOR_RED;
            fgColor = Graphics.COLOR_WHITE;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var pL = lblAktPace;
        var sPL = lblSollPace;
        var sHL = lblSollHr;
        var hL = lblAktHr;

        if (width < 180) {
            pL = "P:";
            sPL = isGerman ? "Erw.P:" : "Exp.P:";
            sHL = isGerman ? "Erw.H:" : "Exp.H:";
            hL = "H:";
        }

        var fOuter = Graphics.FONT_XTINY;
        var fInner = (height < 140) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var fDrift = (height < 140) ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        if (height > 200) { fDrift = Graphics.FONT_NUMBER_MEDIUM; }

        dc.drawText(width / 2, height * 0.12, fOuter, pL + valAktPace, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.30, fInner, sPL + valSollPace, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.48, fDrift, strDrift, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Sub-Label Hinweis Logik
        if (!isConfigured) {
            dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, "CHECK SETTINGS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (strDrift.equals("Warm-up")) {
            var remaining = (WARMUP_MS - mTimerTime) / 1000;
            if (remaining > 0) {
                dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, remaining.toString() + "s LEFT", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.drawText(width / 2, height * 0.72, fInner, sHL + valSollHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.88, fOuter, hL + valAktHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}