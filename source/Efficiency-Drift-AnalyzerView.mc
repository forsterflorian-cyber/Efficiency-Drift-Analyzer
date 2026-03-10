import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.FitContributor;
import Toybox.Math;
import Toybox.System;

class EDAView extends WatchUi.DataField {

    private const STATUS_WAIT as String = "WAIT";
    private const STATUS_PAUSE as String = "PAUSE";
    private const STATUS_WARMUP as String = "WARMUP";
    private const STATUS_PROVISIONAL as String = "PROVISIONAL";
    private const STATUS_PROFILE_TIMEOUT as String = "PROFILE TIMEOUT";
    private const STATUS_CFG_ERR as String = "CFG ERR";
    private const STATUS_NO_HR as String = "NO HR";
    private const STATUS_LOW_HR as String = "LOW HR";
    private const STATUS_SPIKE as String = "SPIKE";
    private const STATUS_LOW_POWER as String = "LOW P";
    private const STATUS_LOW_PACE as String = "LOW PACE";
    private const STATUS_NO_POWER as String = "NO PWR";
    private const STATUS_NO_SPEED as String = "NO SPD";
    private const STATUS_INVALID_SPEED as String = "INV SPD";
    private const STATUS_GAP as String = "GAP";
    private const INVALID_RENDER_VALUE as String = "NaN";

    private const DEFAULT_RUNNING_MIN_HR as Float = 80.0;
    private const DEFAULT_GENERIC_MIN_HR as Float = 70.0;
    private const MIN_VALID_POWER as Float = 30.0;
    private const MAX_VALID_POWER as Float = 700.0;
    private const MAX_RUNNING_PACE_PER_KM as Float = 480.0;
    private const MAX_SPEED_MS as Float = 12.0;
    private const MAX_HR_JUMP_PER_SEC as Float = 20.0;
    private const MAX_SPEED_JUMP_PER_SEC as Float = 4.0;
    private const CALIBRATION_DISTANCE_FACTOR as Float = 1000.0;
    private const WARMUP_VALID_MS as Number = 180000;
    private const MAX_VALID_SAMPLE_GAP_MS as Number = 5000;
    private const MAX_DATA_DRIVEN_GAP_MS as Number = 20000;
    private const MAX_RESUME_GAP_RESET_MS as Number = 300000;
    private const FALLBACK_EXPORT_TIMEOUT_MS as Number = 120000;
    private const IMPLICIT_TIMER_RESET_TOLERANCE_MS as Number = 5000;

    (:high_mem)
    private const MODEL_DELTA_EPSILON as Float = 0.0001;

    // These time constants preserve the old 1 s alpha behaviour while
    // remaining stable if the data field is updated at irregular intervals.
    (:high_mem)
    private const EWMA_SPEED_TAU_MS as Float = 4481.0;

    (:high_mem)
    private const EWMA_HR_TAU_MS as Float = 9491.0;

    private const SOURCE_NONE as Number = 0;
    private const SOURCE_POWER as Number = 1;
    private const SOURCE_SPEED as Number = 2;
    private const SOURCE_SWITCH_CONFIRM_SAMPLES as Number = 3;

    private var mDistanceFactor as Float = 1000.0;
    private var minValidHrSetting as Float = 0.0;
    private var referenceHr as Float = 0.0;
    private var referenceWorkload as Float = 0.0;
    private var isEngineCalibrated as Boolean = false;

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
    private var lastActiveTimerTime as Number? = null;
    private var lastAcceptedDriftSampleTime as Number? = null;
    private var lastAcceptedHr as Float? = null;
    private var lastAcceptedSpeed as Float? = null;
    private var lastValidSpeedSignalTime as Number? = null;
    private var validActiveMs as Number = 0;
    private var driftActiveMs as Number = 0;
    private var currentWorkloadSource as Number = SOURCE_NONE;
    private var pendingWorkloadSource as Number = SOURCE_NONE;
    private var pendingWorkloadSourceSamples as Number = 0;
    private var lastPauseSystemTimer as Number? = null;

    private var statusDetail as String = "";

    private var lblAktPace as String = "";
    private var lblAktHr as String = "";
    private var lblAktPaceShort as String = "";
    private var lblAktHrShort as String = "";
    private var lblStatusWait as String = "";
    private var lblStatusPause as String = "";
    private var lblStatusWarmup as String = "";
    private var lblStatusProvisional as String = "";
    private var lblStatusProfileTimeout as String = "";
    private var lblStatusConfigError as String = "";
    private var lblStatusNoHr as String = "";
    private var lblStatusLowHr as String = "";
    private var lblStatusSpike as String = "";
    private var lblStatusLowPower as String = "";
    private var lblStatusLowPace as String = "";
    private var lblStatusNoPower as String = "";
    private var lblStatusNoSpeed as String = "";
    private var lblStatusInvalidSpeed as String = "";
    private var lblStatusGap as String = "";
    private var lblNotSaved as String = "";
    private var lblTypeUnknown as String = "";
    private var msgCollectingData as String = "";
    private var msgPowerRequired as String = "";
    private var msgNoSpeed as String = "";
    private var msgInvalidSpeed as String = "";
    private var msgProfileRetry as String = "";
    private var msgProfileErrorPrefix as String = "";
    private var msgProvisionalProfile as String = "";
    private var msgProfileTimeout as String = "";
    private var msgWarmupValidSuffix as String = "";

    (:high_mem)
    private var lblSollPace as String = "";

    (:high_mem)
    private var lblSollHr as String = "";

    (:high_mem)
    private var lblSollPaceShort as String = "";

    (:high_mem)
    private var lblSollHrShort as String = "";

    private var lblCalibrationError as String = "";

    private var valAktPace as String = "--:--";
    private var strDrift as String = "--";
    private var valAktHr as String = "--";

    (:high_mem)
    private var valSollPace as String = "--:--";

    (:high_mem)
    private var valSollHr as String = "--";

    (:high_mem)
    private var modelValid as Boolean = false;

    (:high_mem)
    private var modelErrorMessage as String = "";

    private var bgColor as Number = Graphics.COLOR_WHITE;
    private var fgColor as Number = Graphics.COLOR_BLACK;

    private var fitExportState as EDAFitExportState? = null;
    private var profileResolver as EDAProfileResolver? = null;
    private var driftEngine as EDADriftEngine? = null;
    private var renderer as EDARenderer? = null;
    private const DRIFT_GRAPH_ID = 0;
    private const DRIFT_AVG_ID = 1;
    private const PROFILE_STATE_ID = 2;

    function initialize() {
        DataField.initialize();
        loadStrings();
        loadSettings();
        setNeutralColors();

        var driftField = createField("metabolic_drift", DRIFT_GRAPH_ID, FitContributor.DATA_TYPE_FLOAT, {
            :displayLabel => "Drift",
            :mesgType => FitContributor.MESG_TYPE_RECORD,
            :units => "%"
        });
        var avgDriftField = createField("avg_metabolic_drift", DRIFT_AVG_ID, FitContributor.DATA_TYPE_FLOAT, {
            :displayLabel => "Avg Drift",
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "%"
        });
        var profileStateField = createField("profile_state", PROFILE_STATE_ID, FitContributor.DATA_TYPE_UINT8, {
            :displayLabel => "Profile State (0=Unresolved,1=Provisional,2=Fallback,3=Authoritative,4=Stale)",
            :mesgType => FitContributor.MESG_TYPE_RECORD
        });
        fitExportState = new EDAFitExportState(driftField, avgDriftField, profileStateField);
        profileResolver = new EDAProfileResolver();
        driftEngine = new EDADriftEngine();
        renderer = new EDARenderer();
        refreshEngineCalibrationState();

        resetSessionFitSummary();
        resetSessionState();
    }

    (:high_mem)
    private function loadStrings() as Void {
        lblAktPace = WatchUi.loadResource(Rez.Strings.lblAktPace) as String;
        lblAktPaceShort = WatchUi.loadResource(Rez.Strings.lblAktPaceShort) as String;
        lblSollPace = WatchUi.loadResource(Rez.Strings.lblSollPace) as String;
        lblSollHr = WatchUi.loadResource(Rez.Strings.lblSollHr) as String;
        lblSollPaceShort = WatchUi.loadResource(Rez.Strings.lblSollPaceShort) as String;
        lblSollHrShort = WatchUi.loadResource(Rez.Strings.lblSollHrShort) as String;
        lblCalibrationError = WatchUi.loadResource(Rez.Strings.lblCalibrationError) as String;
        lblAktHr = WatchUi.loadResource(Rez.Strings.lblAktHr) as String;
        lblAktHrShort = WatchUi.loadResource(Rez.Strings.lblAktHrShort) as String;
        lblStatusWait = WatchUi.loadResource(Rez.Strings.lblStatusWait) as String;
        lblStatusPause = WatchUi.loadResource(Rez.Strings.lblStatusPause) as String;
        lblStatusWarmup = WatchUi.loadResource(Rez.Strings.lblStatusWarmup) as String;
        lblStatusProvisional = WatchUi.loadResource(Rez.Strings.lblStatusProvisional) as String;
        lblStatusProfileTimeout = WatchUi.loadResource(Rez.Strings.lblStatusProfileTimeout) as String;
        lblStatusConfigError = WatchUi.loadResource(Rez.Strings.lblStatusConfigError) as String;
        lblStatusNoHr = WatchUi.loadResource(Rez.Strings.lblStatusNoHr) as String;
        lblStatusLowHr = WatchUi.loadResource(Rez.Strings.lblStatusLowHr) as String;
        lblStatusSpike = WatchUi.loadResource(Rez.Strings.lblStatusSpike) as String;
        lblStatusLowPower = WatchUi.loadResource(Rez.Strings.lblStatusLowPower) as String;
        lblStatusLowPace = WatchUi.loadResource(Rez.Strings.lblStatusLowPace) as String;
        lblStatusNoPower = WatchUi.loadResource(Rez.Strings.lblStatusNoPower) as String;
        lblStatusNoSpeed = WatchUi.loadResource(Rez.Strings.lblStatusNoSpeed) as String;
        lblStatusInvalidSpeed = WatchUi.loadResource(Rez.Strings.lblStatusInvalidSpeed) as String;
        lblStatusGap = WatchUi.loadResource(Rez.Strings.lblStatusGap) as String;
        lblNotSaved = WatchUi.loadResource(Rez.Strings.label_not_saved) as String;
        lblTypeUnknown = WatchUi.loadResource(Rez.Strings.label_type_unknown) as String;
        lblCalibrationError = WatchUi.loadResource(Rez.Strings.lblCalibrationError) as String;
        msgCollectingData = WatchUi.loadResource(Rez.Strings.msgCollectingData) as String;
        msgPowerRequired = WatchUi.loadResource(Rez.Strings.msgPowerRequired) as String;
        msgNoSpeed = WatchUi.loadResource(Rez.Strings.msgNoSpeed) as String;
        msgInvalidSpeed = WatchUi.loadResource(Rez.Strings.msgInvalidSpeed) as String;
        msgProfileRetry = WatchUi.loadResource(Rez.Strings.msgProfileRetry) as String;
        msgProfileErrorPrefix = WatchUi.loadResource(Rez.Strings.msgProfileErrorPrefix) as String;
        msgProvisionalProfile = WatchUi.loadResource(Rez.Strings.msgProvisionalProfile) as String;
        msgProfileTimeout = WatchUi.loadResource(Rez.Strings.msgProfileTimeout) as String;
        msgWarmupValidSuffix = WatchUi.loadResource(Rez.Strings.msgWarmupValidSuffix) as String;
    }

    (:low_mem)
    private function loadStrings() as Void {
        lblAktPace = WatchUi.loadResource(Rez.Strings.lblAktPaceShort) as String;
        lblAktHr = WatchUi.loadResource(Rez.Strings.lblAktHrShort) as String;
        lblAktPaceShort = lblAktPace;
        lblAktHrShort = lblAktHr;
        lblStatusWait = WatchUi.loadResource(Rez.Strings.lblStatusWait) as String;
        lblStatusPause = WatchUi.loadResource(Rez.Strings.lblStatusPause) as String;
        lblStatusWarmup = WatchUi.loadResource(Rez.Strings.lblStatusWarmup) as String;
        lblStatusProvisional = WatchUi.loadResource(Rez.Strings.lblStatusProvisional) as String;
        lblStatusProfileTimeout = WatchUi.loadResource(Rez.Strings.lblStatusProfileTimeout) as String;
        lblStatusConfigError = WatchUi.loadResource(Rez.Strings.lblStatusConfigError) as String;
        lblStatusNoHr = WatchUi.loadResource(Rez.Strings.lblStatusNoHr) as String;
        lblStatusLowHr = WatchUi.loadResource(Rez.Strings.lblStatusLowHr) as String;
        lblStatusSpike = WatchUi.loadResource(Rez.Strings.lblStatusSpike) as String;
        lblStatusLowPower = WatchUi.loadResource(Rez.Strings.lblStatusLowPower) as String;
        lblStatusLowPace = WatchUi.loadResource(Rez.Strings.lblStatusLowPace) as String;
        lblStatusNoPower = WatchUi.loadResource(Rez.Strings.lblStatusNoPower) as String;
        lblStatusNoSpeed = WatchUi.loadResource(Rez.Strings.lblStatusNoSpeed) as String;
        lblStatusInvalidSpeed = WatchUi.loadResource(Rez.Strings.lblStatusInvalidSpeed) as String;
        lblStatusGap = WatchUi.loadResource(Rez.Strings.lblStatusGap) as String;
        lblNotSaved = WatchUi.loadResource(Rez.Strings.label_not_saved) as String;
        lblTypeUnknown = WatchUi.loadResource(Rez.Strings.label_type_unknown) as String;
        lblCalibrationError = WatchUi.loadResource(Rez.Strings.lblCalibrationError) as String;
        msgCollectingData = WatchUi.loadResource(Rez.Strings.msgCollectingData) as String;
        msgPowerRequired = WatchUi.loadResource(Rez.Strings.msgPowerRequired) as String;
        msgNoSpeed = WatchUi.loadResource(Rez.Strings.msgNoSpeed) as String;
        msgInvalidSpeed = WatchUi.loadResource(Rez.Strings.msgInvalidSpeed) as String;
        msgProfileRetry = WatchUi.loadResource(Rez.Strings.msgProfileRetry) as String;
        msgProfileErrorPrefix = WatchUi.loadResource(Rez.Strings.msgProfileErrorPrefix) as String;
        msgProvisionalProfile = WatchUi.loadResource(Rez.Strings.msgProvisionalProfile) as String;
        msgProfileTimeout = WatchUi.loadResource(Rez.Strings.msgProfileTimeout) as String;
        msgWarmupValidSuffix = WatchUi.loadResource(Rez.Strings.msgWarmupValidSuffix) as String;
    }

    (:high_mem)
    function loadSettings() as Void {
        loadDistanceFactor();
        minValidHrSetting = getNumericProperty("minHr");
        referenceHr = getNumericProperty("hrA");
        referenceWorkload = getNumericProperty("paceA");

        hrA = referenceHr;
        paceA = referenceWorkload;
        hrB = getNumericProperty("hrB");
        paceB = getNumericProperty("paceB");
        calculateLinearModel();
        refreshEngineCalibrationState();
    }

    (:low_mem)
    function loadSettings() as Void {
        loadDistanceFactor();
        minValidHrSetting = getNumericProperty("minHr");
        referenceHr = getNumericProperty("hrA");
        referenceWorkload = getNumericProperty("paceA");
        // Calibration targets are intentionally ignored on low-memory builds
        // because the target-model UI is not part of this tier.
        refreshEngineCalibrationState();
    }

    private function loadDistanceFactor() as Void {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.paceUnits == System.UNIT_STATUTE) {
            mDistanceFactor = 1609.34;
            return;
        }

        mDistanceFactor = 1000.0;
    }

    function applySettingsChange() as Void {
        loadSettings();
        resetSessionFitSummary();
        resetSessionState();
    }

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

    private function toNumberOrNull(value as Numeric?) as Number? {
        if (value == null) {
            return null;
        }

        return value.toNumber();
    }

    (:high_mem)
    private function calculateLinearModel() as Void {
        m = 0.0;
        b = 0.0;
        modelValid = false;
        modelErrorMessage = "";

        if (paceA <= 0.0 || paceB <= 0.0 || hrA <= 0.0 || hrB <= 0.0) {
            return;
        }

        if (paceA <= paceB || hrA >= hrB) {
            modelErrorMessage = lblCalibrationError;
            return;
        }

        var v1 = mDistanceFactor / paceA;
        var v2 = mDistanceFactor / paceB;
        var deltaV = v2 - v1;

        if (deltaV.abs() > MODEL_DELTA_EPSILON) {
            m = (hrB - hrA) / deltaV;
            b = hrA - (m * v1);
            modelValid = true;
        } else {
            modelErrorMessage = lblCalibrationError;
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

    private function hasValidConfiguration() as Boolean {
        return referenceHr > 0.0 && referenceWorkload > 0.0;
    }

    private function refreshEngineCalibrationState() as Void {
        isEngineCalibrated = hasValidConfiguration();
        if (driftEngine != null) {
            getDriftEngine().setCalibrated(isEngineCalibrated);
        }
    }

    private function hasUsableActivityProfile() as Boolean {
        return getProfileResolver().hasUsableActivityProfile();
    }

    private function isProfileProvisional() as Boolean {
        return getProfileResolver().isProfileProvisional();
    }

    private function hasAuthoritativeProfile() as Boolean {
        return getProfileResolver().hasAuthoritativeProfile();
    }

    private function isFallbackProfileConfirmed() as Boolean {
        return getProfileResolver().isFallbackConfirmed();
    }

    private function isRunningProfile() as Boolean {
        return getProfileResolver().isRunningActivity();
    }

    private function canExportFitData() as Boolean {
        // Record developer fields are forward-only; unresolved fallback samples
        // cannot be backfilled into older FIT record messages.
        return hasAuthoritativeProfile() || (isFallbackProfileConfirmed() && mTimerTime >= FALLBACK_EXPORT_TIMEOUT_MS);
    }

    private function getStatusLabel(statusText as String) as String {
        if (statusText.equals(STATUS_WAIT)) {
            return lblStatusWait;
        } else if (statusText.equals(STATUS_PAUSE)) {
            return lblStatusPause;
        } else if (statusText.equals(STATUS_WARMUP)) {
            return lblStatusWarmup;
        } else if (statusText.equals(STATUS_PROVISIONAL)) {
            return lblStatusProvisional;
        } else if (statusText.equals(STATUS_PROFILE_TIMEOUT)) {
            return lblStatusProfileTimeout;
        } else if (statusText.equals(STATUS_CFG_ERR)) {
            return lblStatusConfigError;
        } else if (statusText.equals(STATUS_NO_HR)) {
            return lblStatusNoHr;
        } else if (statusText.equals(STATUS_LOW_HR)) {
            return lblStatusLowHr;
        } else if (statusText.equals(STATUS_SPIKE)) {
            return lblStatusSpike;
        } else if (statusText.equals(STATUS_LOW_POWER)) {
            return lblStatusLowPower;
        } else if (statusText.equals(STATUS_LOW_PACE)) {
            return lblStatusLowPace;
        } else if (statusText.equals(STATUS_NO_POWER)) {
            return lblStatusNoPower;
        } else if (statusText.equals(STATUS_NO_SPEED)) {
            return lblStatusNoSpeed;
        } else if (statusText.equals(STATUS_INVALID_SPEED)) {
            return lblStatusInvalidSpeed;
        } else if (statusText.equals(STATUS_GAP)) {
            return lblStatusGap;
        }

        return statusText;
    }

    private function getRenderedDriftLabel() as String {
        if (!isEngineCalibrated) {
            return lblStatusConfigError;
        }

        var driftLabel = getStatusLabel(strDrift);
        if (!canExportFitData()) {
            return lblNotSaved + " " + driftLabel;
        }

        if (isFallbackProfileConfirmed()) {
            return lblTypeUnknown + " " + driftLabel;
        }

        return driftLabel;
    }

    private function shouldShowProfileErrorDetail() as Boolean {
        if (hasAuthoritativeProfile()) {
            return false;
        }

        return strDrift.equals(STATUS_WAIT) || strDrift.equals(STATUS_PROVISIONAL) || strDrift.equals(STATUS_PROFILE_TIMEOUT);
    }

    private function getDefaultStatusDetail() as String? {
        if (strDrift.equals(STATUS_WAIT)) {
            return msgCollectingData;
        } else if (strDrift.equals(STATUS_NO_POWER)) {
            return msgPowerRequired;
        } else if (strDrift.equals(STATUS_NO_SPEED)) {
            return msgNoSpeed;
        } else if (strDrift.equals(STATUS_INVALID_SPEED)) {
            return msgInvalidSpeed;
        } else if (strDrift.equals(STATUS_PROVISIONAL)) {
            return msgProvisionalProfile;
        } else if (strDrift.equals(STATUS_PROFILE_TIMEOUT)) {
            return msgProfileTimeout;
        }

        var lastErrorCode = getProfileResolver().getLastErrorCode();
        if (lastErrorCode != "" && shouldShowProfileErrorDetail()) {
            return msgProfileErrorPrefix + ": " + lastErrorCode;
        }

        return null;
    }

    private function getFitExportState() as EDAFitExportState {
        return fitExportState as EDAFitExportState;
    }

    private function getProfileResolver() as EDAProfileResolver {
        return profileResolver as EDAProfileResolver;
    }

    private function getDriftEngine() as EDADriftEngine {
        return driftEngine as EDADriftEngine;
    }

    private function getRenderer() as EDARenderer {
        return renderer as EDARenderer;
    }

    private function writeInvalidRecord() as Void {
        getFitExportState().writeInvalidRecord(getProfileResolver().getState());
    }

    private function getProfileRetryDetail() as String {
        var lastErrorCode = getProfileResolver().getLastErrorCode();
        if (lastErrorCode == "") {
            return msgProfileRetry;
        }

        return msgProfileRetry + ": " + lastErrorCode;
    }

    private function setInvalidStatus(statusText as String) as Void {
        setStatus(statusText);
    }

    private function setInvalidStatusWithDetail(statusText as String, detailText as String) as Void {
        setStatusWithDetail(statusText, detailText);
    }

    private function setCollectingStatus() as Void {
        if (isProfileProvisional()) {
            setStatusWithDetail(STATUS_PROVISIONAL, msgProvisionalProfile);
        } else {
            setStatus(STATUS_WAIT);
        }
    }

    (:high_mem)
    private function isTargetModelSupported() as Boolean {
        return true;
    }

    (:low_mem)
    private function isTargetModelSupported() as Boolean {
        return false;
    }

    private function getMinValidHr() as Float {
        if (minValidHrSetting >= 40.0) {
            return minValidHrSetting;
        }

        if (isRunningProfile()) {
            return DEFAULT_RUNNING_MIN_HR;
        }

        return DEFAULT_GENERIC_MIN_HR;
    }

    private function syncDisplayWithCurrentSample(speed as Float?, hr as Float?) as Void {
        resetFilterState();
        updateLiveDisplay(speed, hr);
        resetTargetDisplay();
    }

    private function isInvalidDisplayState() as Boolean {
        return strDrift.equals(STATUS_WAIT)
            || strDrift.equals(STATUS_PAUSE)
            || strDrift.equals(STATUS_WARMUP)
            || strDrift.equals(STATUS_PROVISIONAL)
            || strDrift.equals(STATUS_PROFILE_TIMEOUT)
            || strDrift.equals(STATUS_NO_HR)
            || strDrift.equals(STATUS_LOW_HR)
            || strDrift.equals(STATUS_SPIKE)
            || strDrift.equals(STATUS_LOW_POWER)
            || strDrift.equals(STATUS_LOW_PACE)
            || strDrift.equals(STATUS_NO_POWER)
            || strDrift.equals(STATUS_NO_SPEED)
            || strDrift.equals(STATUS_INVALID_SPEED)
            || strDrift.equals(STATUS_GAP);
    }

    private function getRenderedCurrentPaceValue() as String {
        if (isInvalidDisplayState()) {
            return INVALID_RENDER_VALUE;
        }

        return valAktPace;
    }

    private function getRenderedCurrentHrValue() as String {
        if (isInvalidDisplayState()) {
            return INVALID_RENDER_VALUE;
        }

        return valAktHr;
    }

    private function clearPendingWorkloadSourceSwitch() as Void {
        pendingWorkloadSource = SOURCE_NONE;
        pendingWorkloadSourceSamples = 0;
    }

    private function rememberPauseTimestamp() as Void {
        if (lastPauseSystemTimer == null) {
            lastPauseSystemTimer = System.getTimer();
        }
    }

    private function shouldResetAfterResumePause() as Boolean {
        var pausedAt = lastPauseSystemTimer;
        lastPauseSystemTimer = null;
        if (pausedAt == null) {
            return false;
        }

        var currentSystemTimer = System.getTimer();
        if (currentSystemTimer < pausedAt) {
            return true;
        }

        return (currentSystemTimer - pausedAt) >= MAX_RESUME_GAP_RESET_MS;
    }

    private function hasAcceptedDataGap(timerTime as Number) as Boolean {
        var previousAcceptedTimerTime = lastAcceptedDriftSampleTime;
        if (previousAcceptedTimerTime == null || timerTime <= previousAcceptedTimerTime) {
            return false;
        }

        return (timerTime - previousAcceptedTimerTime) > MAX_DATA_DRIVEN_GAP_MS;
    }

    private function clearLifecyclePauseState() as Void {
        lastPauseSystemTimer = null;
    }

    private function resetResumeSensitiveState() as Void {
        lastActiveTimerTime = null;
        lastAcceptedDriftSampleTime = null;
        lastAcceptedHr = null;
        lastAcceptedSpeed = null;
        lastValidSpeedSignalTime = null;
        clearPendingWorkloadSourceSwitch();
        resetFilterState();
    }

    private function resetAnalysisState() as Void {
        resetResumeSensitiveState();
        validActiveMs = 0;
        driftActiveMs = 0;
        currentWorkloadSource = SOURCE_NONE;
        valAktPace = "--:--";
        valAktHr = "--";
        resetTargetDisplay();
        statusDetail = "";
        getDriftEngine().reset();
        setStatus(STATUS_WAIT);
    }

    private function handleImplicitSessionReset() as Void {
        clearLifecyclePauseState();
        getProfileResolver().handleImplicitSessionReset();
        resetSessionFitSummary();
        resetAnalysisState();
    }

    private function resolveActivityProfile() as Void {
        if (getProfileResolver().resolveActivityProfile(mTimerTime)) {
            resetSessionFitSummary();
            resetAnalysisState();
        }
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
        writeInvalidRecord();
        strDrift = statusText;
        statusDetail = "";
        setNeutralColors();
    }

    private function setStatusWithDetail(statusText as String, detailText as String) as Void {
        writeInvalidRecord();
        strDrift = statusText;
        statusDetail = detailText;
        setNeutralColors();
    }

    (:high_mem)
    private function updateLiveDisplay(speed as Float?, hr as Float?) as Void {
        if (filterInitialized) {
            if (speed != null) {
                valAktPace = formatPace(ewmaSpeed);
            } else {
                valAktPace = "--:--";
            }

            if (hr != null) {
                valAktHr = ewmaHr.toNumber().toString();
            } else {
                valAktHr = "--";
            }
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
    private function timedAlpha(tauMs as Float, deltaMs as Number) as Float {
        if (deltaMs <= 0) {
            return 0.0;
        }

        var scaledDelta = deltaMs.toFloat() / tauMs;
        if (scaledDelta >= 8.0) {
            return 1.0;
        }

        var decay = Math.pow(Math.E, -scaledDelta).toFloat();
        var alpha = 1.0 - decay;
        if (alpha < 0.0) {
            return 0.0;
        }

        if (alpha > 1.0) {
            return 1.0;
        }

        return alpha;
    }

    (:high_mem)
    private function updateDisplayFilters(speed as Float?, hr as Float?, deltaMs as Number) as Void {
        if (speed == null || hr == null) {
            return;
        }

        if (!filterInitialized) {
            ewmaSpeed = speed;
            ewmaHr = hr;
            filterInitialized = true;
        } else {
            var speedAlpha = timedAlpha(EWMA_SPEED_TAU_MS, deltaMs);
            var hrAlpha = timedAlpha(EWMA_HR_TAU_MS, deltaMs);
            ewmaSpeed = (speedAlpha * speed) + ((1.0 - speedAlpha) * ewmaSpeed);
            ewmaHr = (hrAlpha * hr) + ((1.0 - hrAlpha) * ewmaHr);
        }

        updateLiveDisplay(speed, hr);
    }

    (:low_mem)
    private function updateDisplayFilters(speed as Float?, hr as Float?, deltaMs as Number) as Void {
        updateLiveDisplay(speed, hr);
    }

    (:high_mem)
    private function getDisplaySpeed(speed as Float?) as Float? {
        if (speed == null) {
            return null;
        }

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
        if (hr == null) {
            return null;
        }

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

        if (!isRunningProfile() || displaySpeed == null || displayHr == null || !modelValid || m.abs() <= MODEL_DELTA_EPSILON) {
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
        if (previous == null) {
            lastActiveTimerTime = timerTime;
            return 0;
        }

        if (timerTime <= previous) {
            return 0;
        }

        lastActiveTimerTime = timerTime;
        return timerTime - previous;
    }

    private function isInvalidDriftValue(driftPercent as Float?) as Boolean {
        return driftPercent == null || driftPercent != driftPercent;
    }

    private function pacePerKmSeconds(speed as Float?) as Float? {
        if (speed == null || speed <= 0.0) {
            return null;
        }

        return CALIBRATION_DISTANCE_FACTOR / speed;
    }

    private function isHrOutlier(hr as Float, timerTime as Number) as Boolean {
        var previousHr = lastAcceptedHr;
        var previousTimer = lastAcceptedDriftSampleTime;
        if (previousHr == null || previousTimer == null) {
            return false;
        }

        var deltaMs = timerTime - previousTimer;
        if (deltaMs <= 0 || deltaMs > MAX_VALID_SAMPLE_GAP_MS) {
            return false;
        }

        var allowedJump = MAX_HR_JUMP_PER_SEC * (deltaMs.toFloat() / 1000.0);
        return (hr - previousHr).abs() > allowedJump;
    }

    private function isSpeedOutlier(speed as Float, timerTime as Number) as Boolean {
        var previousSpeed = lastAcceptedSpeed;
        var previousTimer = lastValidSpeedSignalTime;
        if (previousSpeed == null || previousTimer == null) {
            return false;
        }

        var deltaMs = timerTime - previousTimer;
        if (deltaMs <= 0 || deltaMs > MAX_VALID_SAMPLE_GAP_MS) {
            return false;
        }

        var allowedJump = MAX_SPEED_JUMP_PER_SEC * (deltaMs.toFloat() / 1000.0);
        return (speed - previousSpeed).abs() > allowedJump;
    }

    private function hasUsablePower(power as Float?) as Boolean {
        if (power == null) {
            return false;
        }

        return power >= MIN_VALID_POWER && power <= MAX_VALID_POWER;
    }

    private function getPowerValidationError(power as Float?) as String? {
        if (power == null) {
            return null;
        }

        if (power < MIN_VALID_POWER) {
            return STATUS_LOW_POWER;
        }

        if (power > MAX_VALID_POWER) {
            return STATUS_SPIKE;
        }

        return null;
    }

    private function canUseSpeedWorkload() as Boolean {
        return isRunningProfile();
    }

    private function hasUsableSpeedWorkload(speed as Float?) as Boolean {
        if (!canUseSpeedWorkload()) {
            return false;
        }

        if (speed == null || speed > MAX_SPEED_MS) {
            return false;
        }

        var runPace = pacePerKmSeconds(speed);
        return runPace != null && runPace <= MAX_RUNNING_PACE_PER_KM;
    }

    private function getSpeedValidationError(speed as Float?, timerTime as Number) as String? {
        if (!canUseSpeedWorkload()) {
            return null;
        }

        if (speed == null) {
            return STATUS_NO_SPEED;
        }

        if (speed <= 0.0) {
            return STATUS_LOW_PACE;
        }

        if (speed > MAX_SPEED_MS) {
            return STATUS_INVALID_SPEED;
        }

        var runPace = pacePerKmSeconds(speed);
        if (runPace == null) {
            return STATUS_INVALID_SPEED;
        }

        if (runPace > MAX_RUNNING_PACE_PER_KM) {
            return STATUS_LOW_PACE;
        }

        if (isSpeedOutlier(speed, timerTime)) {
            return STATUS_INVALID_SPEED;
        }

        return null;
    }

    private function updateValidSpeedSignal(speed as Float?, timerTime as Number, speedValidationError as String?) as Void {
        if (!canUseSpeedWorkload() || speed == null || speedValidationError != null) {
            return;
        }

        lastAcceptedSpeed = speed;
        lastValidSpeedSignalTime = timerTime;
    }

    private function getWorkloadValidationError(speedError as String?, power as Float?) as String? {
        if (hasUsablePower(power)) {
            return null;
        }

        var powerError = getPowerValidationError(power);
        if (!canUseSpeedWorkload()) {
            if (powerError != null) {
                return powerError;
            }

            return STATUS_NO_POWER;
        }

        if (speedError == null) {
            return null;
        }

        if (powerError != null) {
            return powerError;
        }

        if (canUseSpeedWorkload()) {
            return speedError;
        }

        return STATUS_NO_POWER;
    }

    private function getWorkloadMetric(speed as Float?, power as Float?) as Float? {
        if (hasUsablePower(power)) {
            return power;
        }

        if (hasUsableSpeedWorkload(speed) && speed != null) {
            return speed;
        }

        return null;
    }

    private function determineWorkloadSource(speed as Float?, power as Float?) as Number {
        if (hasUsablePower(power)) {
            return SOURCE_POWER;
        }

        if (hasUsableSpeedWorkload(speed)) {
            return SOURCE_SPEED;
        }

        return SOURCE_NONE;
    }

    private function validateSample(speed as Float?, hr as Float?, power as Float?, timerTime as Number) as String? {
        if (hr == null) {
            return STATUS_NO_HR;
        }

        if (hr < getMinValidHr()) {
            return STATUS_LOW_HR;
        }

        if (isHrOutlier(hr, timerTime)) {
            return STATUS_SPIKE;
        }

        var speedError = getSpeedValidationError(speed, timerTime);
        updateValidSpeedSignal(speed, timerTime, speedError);
        return getWorkloadValidationError(speedError, power);
    }

    private function markAcceptedSample(timerTime as Number, hr as Float) as Void {
        lastAcceptedDriftSampleTime = timerTime;
        lastAcceptedHr = hr;
    }

    private function primeAnalysisBaseline(timerTime as Number, speed as Float?, hr as Float, workloadSource as Number) as Void {
        lastActiveTimerTime = timerTime;
        markAcceptedSample(timerTime, hr);
        currentWorkloadSource = workloadSource;
        clearPendingWorkloadSourceSwitch();
        updateDisplayFilters(speed, hr, 0);
        if (isTargetModelSupported()) {
            updateTargetDisplay(getDisplaySpeed(speed), getDisplayHr(hr));
        }
    }

    private function restartAnalysisAfterSourceSwitch(timerTime as Number, speed as Float?, hr as Float, workloadSource as Number) as Void {
        resetSessionFitSummary();
        resetAnalysisState();
        primeAnalysisBaseline(timerTime, speed, hr, workloadSource);
        setCollectingStatus();
    }

    private function restartAnalysisAfterGap(timerTime as Number, speed as Float?, hr as Float?, workloadSource as Number) as Void {
        resetSessionFitSummary();
        resetAnalysisState();
        if (hr != null && workloadSource != SOURCE_NONE) {
            primeAnalysisBaseline(timerTime, speed, hr, workloadSource);
        }
        setInvalidStatus(STATUS_GAP);
    }

    private function resetEpochWithoutPrimingWithDetail(statusText as String, detailText as String) as Void {
        resetAnalysisState();
        setInvalidStatusWithDetail(statusText, detailText);
    }

    private function validateSourceConsistency(timerTime as Number, speed as Float?, hr as Float, workloadSource as Number, deltaMs as Number) as Boolean {
        if (deltaMs > MAX_VALID_SAMPLE_GAP_MS) {
            clearPendingWorkloadSourceSwitch();
            restartAnalysisAfterGap(timerTime, speed, hr, workloadSource);
            return false;
        }

        if (currentWorkloadSource == SOURCE_NONE || workloadSource == currentWorkloadSource) {
            clearPendingWorkloadSourceSwitch();
            return true;
        }

        if (pendingWorkloadSource != workloadSource) {
            pendingWorkloadSource = workloadSource;
            pendingWorkloadSourceSamples = 1;
        } else {
            pendingWorkloadSourceSamples += 1;
        }

        if (pendingWorkloadSourceSamples < SOURCE_SWITCH_CONFIRM_SAMPLES) {
            setCollectingStatus();
            return false;
        }

        clearPendingWorkloadSourceSwitch();
        restartAnalysisAfterSourceSwitch(timerTime, speed, hr, workloadSource);
        return false;
    }

    private function updateDriftDisplay(driftPercent as Float) as Void {
        var sign = driftPercent > 0.0 ? "+" : "";
        strDrift = sign + driftPercent.format("%.1f") + "%";
        statusDetail = "";

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

    private function updateFitFields(driftPercent as Float, intervalMs as Number) as Void {
        getFitExportState().updateFitFields(getProfileResolver().getState(), canExportFitData(), driftPercent, intervalMs, currentWorkloadSource);
    }

    private function resetSessionFitSummary() as Void {
        getFitExportState().resetSessionFitSummary();
    }

    (:high_mem)
    private function buildHighMemRenderModel() as Dictionary {
        return {
            :renderBgColor => bgColor,
            :renderFgColor => fgColor,
            :paceLabel => lblAktPace,
            :paceShortLabel => lblAktPaceShort,
            :expectedPaceLabel => lblSollPace,
            :expectedPaceShortLabel => lblSollPaceShort,
            :expectedHrLabel => lblSollHr,
            :expectedHrShortLabel => lblSollHrShort,
            :hrLabel => lblAktHr,
            :hrShortLabel => lblAktHrShort,
            :currentPaceValue => getRenderedCurrentPaceValue(),
            :expectedPaceValue => valSollPace,
            :driftLabel => getRenderedDriftLabel(),
            :renderStatusDetail => statusDetail,
            :showModelError => isRunningProfile() && modelErrorMessage != "",
            :renderModelErrorMessage => modelErrorMessage,
            :defaultDetail => getDefaultStatusDetail(),
            :expectedHrValue => valSollHr,
            :currentHrValue => getRenderedCurrentHrValue()
        };
    }

    (:low_mem)
    private function buildLowMemRenderModel() as Dictionary {
        return {
            :renderBgColor => bgColor,
            :renderFgColor => fgColor,
            :paceShortLabel => lblAktPaceShort,
            :currentPaceValue => getRenderedCurrentPaceValue(),
            :driftLabel => getRenderedDriftLabel(),
            :renderStatusDetail => statusDetail,
            :defaultDetail => getDefaultStatusDetail(),
            :hrShortLabel => lblAktHrShort,
            :currentHrValue => getRenderedCurrentHrValue()
        };
    }

    (:high_mem)
    private function resetFilterState() as Void {
        filterInitialized = false;
        ewmaSpeed = 0.0;
        ewmaHr = 0.0;
    }

    (:low_mem)
    private function resetFilterState() as Void {
    }

    private function resetSessionState() as Void {
        mTimerTime = 0;
        clearLifecyclePauseState();
        getProfileResolver().resetSession();
        resetAnalysisState();
    }

    function onTimerReset() as Void {
        resetSessionFitSummary();
        resetSessionState();
        WatchUi.requestUpdate();
    }

    function onTimerLap() as Void {
        WatchUi.requestUpdate();
    }

    function onTimerPause() as Void {
        rememberPauseTimestamp();
        setInvalidStatus(STATUS_PAUSE);
        WatchUi.requestUpdate();
    }

    function onTimerResume() as Void {
        if (shouldResetAfterResumePause()) {
            restartAnalysisAfterGap(mTimerTime, null, null, SOURCE_NONE);
        } else {
            setCollectingStatus();
        }
        WatchUi.requestUpdate();
    }

    function onNextMultisportLeg() as Void {
        resetSessionFitSummary();
        resetSessionState();
        WatchUi.requestUpdate();
    }

    function compute(info as Activity.Info) as Void {
        refreshEngineCalibrationState();

        var currentTimerTime = toNumberOrNull(info.timerTime as Numeric?);
        if (currentTimerTime == null) {
            return;
        }
        var curSpeed = toFloatOrNull(info.currentSpeed as Numeric?);
        var curHr = toFloatOrNull(info.currentHeartRate as Numeric?);
        var curPower = toFloatOrNull(info.currentPower as Numeric?);

        if (info.timerState != Activity.TIMER_STATE_ON) {
            rememberPauseTimestamp();
            setInvalidStatus(STATUS_PAUSE);
            return;
        }

        var previousTimerTime = lastActiveTimerTime;
        if (previousTimerTime != null && currentTimerTime < previousTimerTime) {
            var rollbackMs = previousTimerTime - currentTimerTime;
            if (rollbackMs > IMPLICIT_TIMER_RESET_TOLERANCE_MS) {
                handleImplicitSessionReset();
            } else {
                return;
            }
        }

        mTimerTime = currentTimerTime;

        if (lastPauseSystemTimer != null && shouldResetAfterResumePause()) {
            restartAnalysisAfterGap(mTimerTime, null, null, SOURCE_NONE);
            return;
        }

        resolveActivityProfile();

        updateLiveDisplay(curSpeed, curHr);
        if (isTargetModelSupported()) {
            updateTargetDisplay(getDisplaySpeed(curSpeed), getDisplayHr(curHr));
        }

        var deltaMs = getSampleDelta(mTimerTime);
        if (deltaMs <= 0) {
            setCollectingStatus();
            return;
        }

        if (!hasUsableActivityProfile()) {
            if (getProfileResolver().isRetryPending()) {
                setInvalidStatusWithDetail(STATUS_WAIT, getProfileRetryDetail());
            } else {
                setCollectingStatus();
            }
            return;
        }

        if (hasAcceptedDataGap(mTimerTime)) {
            restartAnalysisAfterGap(mTimerTime, curSpeed, curHr, determineWorkloadSource(curSpeed, curPower));
            return;
        }

        var validationError = validateSample(curSpeed, curHr, curPower, mTimerTime);
        if (validationError != null) {
            if (validationError.equals(STATUS_NO_HR) || validationError.equals(STATUS_NO_POWER) || validationError.equals(STATUS_INVALID_SPEED)) {
                syncDisplayWithCurrentSample(curSpeed, curHr);
            }
            if (getProfileResolver().hasTimeoutNoticePending()) {
                getProfileResolver().clearTimeoutNoticePending();
                resetEpochWithoutPrimingWithDetail(STATUS_PROFILE_TIMEOUT, msgProfileTimeout);
                return;
            }
            setInvalidStatus(validationError);
            return;
        }

        var workload = getWorkloadMetric(curSpeed, curPower);
        if (curHr == null || workload == null || curHr <= 0.0 || workload <= 0.0) {
            if (getProfileResolver().hasTimeoutNoticePending()) {
                getProfileResolver().clearTimeoutNoticePending();
                resetEpochWithoutPrimingWithDetail(STATUS_PROFILE_TIMEOUT, msgProfileTimeout);
                return;
            }
            setCollectingStatus();
            return;
        }

        var workloadSource = determineWorkloadSource(curSpeed, curPower);
        if (getProfileResolver().hasTimeoutNoticePending()) {
            getProfileResolver().clearTimeoutNoticePending();
            restartAnalysisAfterGap(mTimerTime, curSpeed, curHr, workloadSource);
            setInvalidStatusWithDetail(STATUS_PROFILE_TIMEOUT, msgProfileTimeout);
            return;
        }

        if (!validateSourceConsistency(mTimerTime, curSpeed, curHr, workloadSource, deltaMs)) {
            return;
        }

        var ef = workload / curHr;
        if (ef <= 0.0) {
            setCollectingStatus();
            return;
        }

        markAcceptedSample(mTimerTime, curHr);
        currentWorkloadSource = workloadSource;
        validActiveMs += deltaMs;
        var previousDriftActiveMs = driftActiveMs;
        if (validActiveMs > WARMUP_VALID_MS) {
            driftActiveMs = validActiveMs - WARMUP_VALID_MS;
        } else {
            driftActiveMs = 0;
        }

        updateDisplayFilters(curSpeed, curHr, deltaMs);
        if (isTargetModelSupported()) {
            updateTargetDisplay(getDisplaySpeed(curSpeed), getDisplayHr(curHr));
        }

        if (driftActiveMs <= 0) {
            var remainingMs = WARMUP_VALID_MS - validActiveMs;
            var remainingSeconds = ((remainingMs + 999) / 1000).toNumber();
            setInvalidStatusWithDetail(STATUS_WARMUP, remainingSeconds.toString() + msgWarmupValidSuffix);
            return;
        }

        var driftDeltaMs = driftActiveMs - previousDriftActiveMs;
        getDriftEngine().recordValidSample(driftActiveMs, driftDeltaMs, ef);

        var driftPercent = getDriftEngine().computeDrift(driftActiveMs);
        if (driftPercent == null) {
            setCollectingStatus();
            return;
        }

        if (isInvalidDriftValue(driftPercent)) {
            writeInvalidRecord();
            return;
        }

        updateDriftDisplay(driftPercent);
        if (isProfileProvisional()) {
            statusDetail = msgProvisionalProfile;
        }
        updateFitFields(driftPercent, driftDeltaMs);
    }

    (:high_mem)
    function onUpdate(dc as Graphics.Dc) as Void {
        getRenderer().drawHighMem(dc, buildHighMemRenderModel());
    }

    (:low_mem)
    function onUpdate(dc as Graphics.Dc) as Void {
        getRenderer().drawLowMem(dc, buildLowMemRenderModel());
    }
}
