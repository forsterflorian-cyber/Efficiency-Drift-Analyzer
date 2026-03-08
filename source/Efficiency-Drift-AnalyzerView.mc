import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.FitContributor;
import Toybox.System;

class EDAView extends WatchUi.DataField {

    (:high_mem)
    private const ALPHA_SPEED as Float = 0.20;

    (:high_mem)
    private const ALPHA_HR as Float = 0.10;
    private const MIN_VALID_HR as Float = 100.0;
    private const MIN_VALID_POWER as Float = 30.0;
    private const MAX_VALID_POWER as Float = 700.0;
    private const MAX_RUNNING_PACE_PER_KM as Float = 480.0;
    private const MAX_HR_JUMP_PER_SEC as Float = 20.0;
    private const MIN_SPLIT_VALID_MS as Number = 600000;
    private const MAX_DRIFT_PERCENT as Float = 50.0;
    private const SPLIT_BUCKET_MS as Number = 10000;
    private const CALIBRATION_DISTANCE_FACTOR as Float = 1000.0;

    private var mDistanceFactor as Float = 1000.0;

    (:high_mem)
    private var hrA as Float = 0.0;

    (:high_mem)
    private var paceA as Float = 0.0;

    (:high_mem)
    private var hrB as Float = 0.0;

    (:high_mem)
    private var paceB as Float = 0.0;

    (:high_mem)
    private var m as Float = 0.0;

    (:high_mem)
    private var b as Float = 0.0;

    (:high_mem)
    private var ewmaSpeed as Float = 0.0;

    (:high_mem)
    private var ewmaHr as Float = 0.0;

    (:high_mem)
    private var filterInitialized as Boolean = false;

    private var mTimerTime as Number = 0;
    private var activityProfileResolved as Boolean = false;
    private var isRunningActivity as Boolean = true;
    private var lastActiveTimerTime as Number? = null;
    private var lastAcceptedTimerTime as Number? = null;
    private var lastAcceptedHr as Float? = null;

    private var splitWeightedEf as Array<Float> = [];
    private var splitValidMs as Array<Number> = [];
    private var driftSum as Float = 0.0;
    private var driftCount as Number = 0;

    private var lblAktPace as String = "";
    private var lblAktHr as String = "";

    (:high_mem)
    private var lblSollPace as String = "";

    (:high_mem)
    private var lblSollHr as String = "";

    (:high_mem)
    private var isGerman as Boolean = false;

    private var valAktPace as String = "--:--";
    private var strDrift as String = "--";
    private var valAktHr as String = "--";

    (:high_mem)
    private var valSollPace as String = "--:--";

    (:high_mem)
    private var valSollHr as String = "--";

    private var bgColor as Number = Graphics.COLOR_WHITE;
    private var fgColor as Number = Graphics.COLOR_BLACK;

    private var driftField as Toybox.FitContributor.Field? = null;
    private var avgDriftField as Toybox.FitContributor.Field? = null;
    private const DRIFT_GRAPH_ID = 0;
    private const DRIFT_AVG_ID = 1;

    function initialize() {
        DataField.initialize();
        loadStrings();
        loadSettings();
        setNeutralColors();

        driftField = createField("metabolic_drift", DRIFT_GRAPH_ID, FitContributor.DATA_TYPE_FLOAT, { :displayLabel => "Drift", :units => "%" });
        avgDriftField = createField("avg_metabolic_drift", DRIFT_AVG_ID, FitContributor.DATA_TYPE_FLOAT, { :displayLabel => "Avg Drift", :units => "%" });
    }

    (:high_mem)
    private function loadStrings() as Void {
        lblAktPace = WatchUi.loadResource(Rez.Strings.lblAktPace) as String;
        lblSollPace = WatchUi.loadResource(Rez.Strings.lblSollPace) as String;
        lblSollHr = WatchUi.loadResource(Rez.Strings.lblSollHr) as String;
        lblAktHr = WatchUi.loadResource(Rez.Strings.lblAktHr) as String;
        isGerman = true;
    }

    (:low_mem)
    private function loadStrings() as Void {
        lblAktPace = "P:";
        lblAktHr = "H:";
    }

    (:high_mem)
    function loadSettings() as Void {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.paceUnits == System.UNIT_STATUTE) {
            mDistanceFactor = 1609.34;
        } else {
            mDistanceFactor = 1000.0;
        }

        hrA = getNumericProperty("hrA");
        paceA = getNumericProperty("paceA");
        hrB = getNumericProperty("hrB");
        paceB = getNumericProperty("paceB");
        calculateLinearModel();
    }

    (:low_mem)
    function loadSettings() as Void {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.paceUnits == System.UNIT_STATUTE) {
            mDistanceFactor = 1609.34;
        } else {
            mDistanceFactor = 1000.0;
        }
    }

    (:high_mem)
    private function getNumericProperty(key as String) as Float {
        var value = Properties.getValue(key) as Numeric?;
        if (value == null) {
            return 0.0;
        }

        return value.toFloat();
    }

    private function toFloatOrNull(value as Numeric?) as Float? {
        if (value == null) {
            return null;
        }

        return value.toFloat();
    }

    private function toNumberOrZero(value as Numeric?) as Number {
        if (value == null) {
            return 0;
        }

        return value.toNumber();
    }

    (:high_mem)
    private function calculateLinearModel() as Void {
        m = 0.0;
        b = 0.0;

        var v1 = (paceA > 0.0) ? CALIBRATION_DISTANCE_FACTOR / paceA : 0.0;
        var v2 = (paceB > 0.0) ? CALIBRATION_DISTANCE_FACTOR / paceB : 0.0;
        var deltaV = v2 - v1;

        if (deltaV.abs() > 0.0001) {
            m = (hrB - hrA) / deltaV;
            b = hrA - (m * v1);
        }
    }

    (:high_mem)
    private function resetTargetDisplay() as Void {
        valSollPace = "--:--";
        valSollHr = "--";
    }

    (:low_mem)
    private function resetTargetDisplay() as Void {
    }

    private function resolveActivityProfile() as Void {
        if (activityProfileResolved) {
            return;
        }

        try {
            var profileInfo = Activity.getProfileInfo();
            if (profileInfo != null) {
                isRunningActivity = (profileInfo.sport == Activity.SPORT_RUNNING);
            }
        } catch (e) {
            isRunningActivity = true;
        }

        activityProfileResolved = true;
    }

    private function formatPace(speedInMs as Float) as String {
        if (speedInMs <= 0.2) {
            return "--:--";
        }

        var secondsPerUnit = mDistanceFactor / speedInMs;
        var minutes = (secondsPerUnit / 60).toNumber();
        var seconds = secondsPerUnit.toNumber() % 60;
        return minutes.toString() + ":" + seconds.format("%02d");
    }

    private function setNeutralColors() as Void {
        bgColor = getBackgroundColor();
        fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    private function setStatus(statusText as String) as Void {
        strDrift = statusText;
        setNeutralColors();
    }

    (:high_mem)
    private function updateLiveDisplay(speed as Float?, hr as Float?) as Void {
        if (filterInitialized) {
            valAktPace = formatPace(ewmaSpeed);
            valAktHr = ewmaHr.toNumber().toString();
            return;
        }

        if (speed != null) {
            valAktPace = formatPace(speed);
        } else {
            valAktPace = "--:--";
        }

        if (hr != null) {
            valAktHr = hr.toNumber().toString();
        } else {
            valAktHr = "--";
        }
    }

    (:low_mem)
    private function updateLiveDisplay(speed as Float?, hr as Float?) as Void {
        if (speed != null) {
            valAktPace = formatPace(speed);
        } else {
            valAktPace = "--:--";
        }

        if (hr != null) {
            valAktHr = hr.toNumber().toString();
        } else {
            valAktHr = "--";
        }
    }

    (:high_mem)
    private function updateDisplayFilters(speed as Float?, hr as Float?) as Void {
        if (speed == null || hr == null) {
            return;
        }

        if (!filterInitialized) {
            ewmaSpeed = speed;
            ewmaHr = hr;
            filterInitialized = true;
        } else {
            ewmaSpeed = (ALPHA_SPEED * speed) + ((1.0 - ALPHA_SPEED) * ewmaSpeed);
            ewmaHr = (ALPHA_HR * hr) + ((1.0 - ALPHA_HR) * ewmaHr);
        }

        updateLiveDisplay(speed, hr);
    }

    (:low_mem)
    private function updateDisplayFilters(speed as Float?, hr as Float?) as Void {
        updateLiveDisplay(speed, hr);
    }

    (:high_mem)
    private function getDisplaySpeed(speed as Float?) as Float? {
        if (filterInitialized) {
            return ewmaSpeed;
        }

        return speed;
    }

    (:low_mem)
    private function getDisplaySpeed(speed as Float?) as Float? {
        return null;
    }

    (:high_mem)
    private function getDisplayHr(hr as Float?) as Float? {
        if (filterInitialized) {
            return ewmaHr;
        }

        return hr;
    }

    (:low_mem)
    private function getDisplayHr(hr as Float?) as Float? {
        return null;
    }

    (:high_mem)
    private function updateTargetDisplay(displaySpeed as Float?, displayHr as Float?) as Void {
        resetTargetDisplay();

        if (!isRunningActivity || displaySpeed == null || displayHr == null || m.abs() <= 0.0001) {
            return;
        }

        var hrSoll = (m * displaySpeed) + b;
        if (hrSoll > 0.0) {
            valSollHr = hrSoll.toNumber().toString();
        }

        var vSoll = (displayHr - b) / m;
        if (vSoll > 0.2) {
            valSollPace = formatPace(vSoll);
        }
    }

    (:low_mem)
    private function updateTargetDisplay(displaySpeed as Float?, displayHr as Float?) as Void {
        resetTargetDisplay();
    }

    private function getSampleDelta(timerTime as Number) as Number {
        var previous = lastActiveTimerTime;
        lastActiveTimerTime = timerTime;

        if (previous == null || timerTime <= previous) {
            return 0;
        }

        return timerTime - previous;
    }

    private function pacePerKmSeconds(speed as Float?) as Float? {
        if (speed == null || speed <= 0.0) {
            return null;
        }

        return CALIBRATION_DISTANCE_FACTOR / speed;
    }

    private function isHrOutlier(hr as Float, timerTime as Number) as Boolean {
        var previousHr = lastAcceptedHr;
        var previousTimer = lastAcceptedTimerTime;
        if (previousHr == null || previousTimer == null) {
            return false;
        }

        var deltaMs = timerTime - previousTimer;
        if (deltaMs <= 0 || deltaMs > 1000) {
            return false;
        }

        return (hr - previousHr).abs() > MAX_HR_JUMP_PER_SEC;
    }

    private function getWorkloadMetric(speed as Float?, power as Float?) as Float? {
        if (power != null) {
            return power;
        }

        if (isRunningActivity && speed != null && speed > 0.0) {
            return speed;
        }

        return null;
    }

    private function validateSample(speed as Float?, hr as Float?, power as Float?, timerTime as Number) as String? {
        if (hr == null) {
            return "NO HR";
        }

        if (hr < MIN_VALID_HR) {
            return "LOW HR";
        }

        if (isHrOutlier(hr, timerTime)) {
            return "SPIKE";
        }

        if (power != null) {
            if (power < MIN_VALID_POWER) {
                return "LOW P";
            }

            if (power > MAX_VALID_POWER) {
                return "SPIKE";
            }
        }

        if (isRunningActivity) {
            var runPace = pacePerKmSeconds(speed);
            if (runPace == null || runPace > MAX_RUNNING_PACE_PER_KM) {
                return "LOW PACE";
            }
        } else if (power == null) {
            return "NO PWR";
        }

        return null;
    }

    private function clampDrift(value as Float) as Float {
        if (value > MAX_DRIFT_PERCENT) {
            return MAX_DRIFT_PERCENT;
        }

        if (value < -MAX_DRIFT_PERCENT) {
            return -MAX_DRIFT_PERCENT;
        }

        return value;
    }

    private function ensureBucket(bucketIndex as Number) as Void {
        while (splitWeightedEf.size() <= bucketIndex) {
            splitWeightedEf.add(0.0);
            splitValidMs.add(0);
        }
    }

    private function recordValidSample(timerTime as Number, deltaMs as Number, ef as Float, hr as Float) as Void {
        if (deltaMs <= 0 || ef <= 0.0) {
            return;
        }

        var bucketIndex = (timerTime / SPLIT_BUCKET_MS).toNumber();
        ensureBucket(bucketIndex);

        splitWeightedEf[bucketIndex] = (splitWeightedEf[bucketIndex] as Float) + (ef * deltaMs);
        splitValidMs[bucketIndex] = (splitValidMs[bucketIndex] as Number) + deltaMs;

        lastAcceptedTimerTime = timerTime;
        lastAcceptedHr = hr;
    }

    private function computeDriftFromSplits() as Float? {
        var halfTimerTime = mTimerTime / 2;
        var split1Weighted = 0.0;
        var split2Weighted = 0.0;
        var split1Ms = 0;
        var split2Ms = 0;

        for (var i = 0; i < splitWeightedEf.size(); i += 1) {
            var bucketWeighted = splitWeightedEf[i] as Float;
            var bucketMs = splitValidMs[i] as Number;

            if (bucketMs <= 0) {
                continue;
            }

            var bucketStart = i * SPLIT_BUCKET_MS;
            if (bucketStart < halfTimerTime) {
                split1Weighted += bucketWeighted;
                split1Ms += bucketMs;
            } else {
                split2Weighted += bucketWeighted;
                split2Ms += bucketMs;
            }
        }

        if (split1Ms < MIN_SPLIT_VALID_MS || split2Ms < MIN_SPLIT_VALID_MS) {
            return null;
        }

        if (split1Ms <= 0 || split2Ms <= 0) {
            return null;
        }

        var split1Ef = split1Weighted / split1Ms;
        var split2Ef = split2Weighted / split2Ms;

        if (split1Ef <= 0.0 || split2Ef <= 0.0) {
            return null;
        }

        return clampDrift(((split1Ef / split2Ef) - 1.0) * 100.0);
    }

    private function updateDriftDisplay(driftPercent as Float) as Void {
        var sign = driftPercent > 0.0 ? "+" : "";
        strDrift = sign + driftPercent.format("%.1f") + "%";

        if (driftPercent < 3.0) {
            bgColor = Graphics.COLOR_GREEN;
            fgColor = Graphics.COLOR_BLACK;
        } else if (driftPercent <= 7.0) {
            bgColor = Graphics.COLOR_YELLOW;
            fgColor = Graphics.COLOR_BLACK;
        } else {
            bgColor = Graphics.COLOR_RED;
            fgColor = Graphics.COLOR_WHITE;
        }
    }

    private function updateFitFields(driftPercent as Float) as Void {
        if (driftField != null) {
            driftField.setData(driftPercent);
        }

        driftSum += driftPercent;
        driftCount += 1;

        if (avgDriftField != null && driftCount > 0) {
            avgDriftField.setData(driftSum / driftCount);
        }
    }

    function compute(info as Activity.Info) as Void {
        resolveActivityProfile();

        mTimerTime = toNumberOrZero(info.timerTime as Numeric?);

        var curSpeed = toFloatOrNull(info.currentSpeed as Numeric?);
        var curHr = toFloatOrNull(info.currentHeartRate as Numeric?);
        var curPower = toFloatOrNull(info.currentPower as Numeric?);

        updateLiveDisplay(curSpeed, curHr);
        updateTargetDisplay(getDisplaySpeed(curSpeed), getDisplayHr(curHr));

        if (info.timerState != Activity.TIMER_STATE_ON) {
            lastActiveTimerTime = null;
            setStatus("PAUSE");
            return;
        }

        var deltaMs = getSampleDelta(mTimerTime);
        if (deltaMs <= 0) {
            setStatus("WAIT");
            return;
        }

        var validationError = validateSample(curSpeed, curHr, curPower, mTimerTime);
        if (validationError != null) {
            setStatus(validationError);
            return;
        }

        var workload = getWorkloadMetric(curSpeed, curPower);
        if (curHr == null || workload == null || curHr <= 0.0 || workload <= 0.0) {
            setStatus("WAIT");
            return;
        }

        var ef = workload / curHr;
        if (ef <= 0.0) {
            setStatus("WAIT");
            return;
        }

        updateDisplayFilters(curSpeed, curHr);
        updateTargetDisplay(getDisplaySpeed(curSpeed), getDisplayHr(curHr));
        recordValidSample(mTimerTime, deltaMs, ef, curHr);

        var driftPercent = computeDriftFromSplits();
        if (driftPercent == null) {
            setStatus("WAIT");
            return;
        }

        updateDriftDisplay(driftPercent);
        updateFitFields(driftPercent);
    }

    (:high_mem)
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
        if (height > 200) {
            fDrift = Graphics.FONT_NUMBER_MEDIUM;
        }

        dc.drawText(width / 2, height * 0.12, fOuter, pL + valAktPace, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.30, fInner, sPL + valSollPace, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.48, fDrift, strDrift, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (strDrift.equals("WAIT")) {
            dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, "COLLECTING VALID DATA", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (strDrift.equals("NO PWR")) {
            dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, "POWER REQUIRED", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.drawText(width / 2, height * 0.72, fInner, sHL + valSollHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.88, fOuter, hL + valAktHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    (:low_mem)
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var fPace = Graphics.FONT_TINY;
        var fDrift = (height < 180) ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        var fHr = Graphics.FONT_TINY;

        dc.drawText(width / 2, height * 0.20, fPace, lblAktPace + valAktPace, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.50, fDrift, strDrift, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.80, fHr, lblAktHr + valAktHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
