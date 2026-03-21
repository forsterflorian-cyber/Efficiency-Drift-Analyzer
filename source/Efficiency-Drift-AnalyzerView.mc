import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.FitContributor;
import Toybox.Math;
import Toybox.System;

class EDAView extends WatchUi.DataField {

    // Status-Konstanten werden jetzt aus EDATypes importiert
    // Status-Konstanten werden jetzt aus EDATypes importiert
    private const INVALID_RENDER_VALUE as String = "NaN";

    // Default Minimum HR für Running: 80 bpm
    // Begründung: Unter 80 bpm ist HR-Sensor wahrscheinlich ungenau oder nicht verbunden
    private const DEFAULT_RUNNING_MIN_HR as Float = 80.0;

    // Default Minimum HR für andere Aktivitäten: 70 bpm
    // Begründung: Niedrigere Schwelle für Radfahren, Schwimmen etc.
    private const DEFAULT_GENERIC_MIN_HR as Float = 70.0;

    // Kalibrierungs-Distanz-Faktor: 1000m
    // Begründung: Pace wird in Sekunden pro km/mi berechnet
    private const CALIBRATION_DISTANCE_FACTOR as Float = 1000.0;

    // Konstanten werden aus EDAFeatureFlags bezogen:
    // - MIN_VALID_POWER → EDAFeatureFlags.getMinValidPower()
    // - MAX_VALID_POWER → EDAFeatureFlags.getMaxValidPower()
    // - MAX_RUNNING_PACE_PER_KM → EDAFeatureFlags.getMaxRunningPacePerKm()
    // - MAX_SPEED_MS → EDAFeatureFlags.getMaxSpeedMs()
    // - MAX_HR_JUMP_PER_SEC → EDAFeatureFlags.getHrJumpPerSec()
    // - MAX_SPEED_JUMP_PER_SEC → EDAFeatureFlags.getSpeedJumpPerSec()
    // - WARMUP_VALID_MS → EDAFeatureFlags.getWarmupValidMs()
    // - MAX_VALID_SAMPLE_GAP_MS → EDAFeatureFlags.getMaxValidSampleGapMs()
    // - FALLBACK_EXPORT_TIMEOUT_MS → EDAFeatureFlags.getFallbackExportTimeoutMs()
    // - IMPLICIT_TIMER_RESET_TOLERANCE_MS → EDAFeatureFlags.getImplicitTimerResetToleranceMs()

    (:high_mem)
    private const MODEL_DELTA_EPSILON as Float = 0.0001;

    // EWMA-Zeitkonstanten (Exponentially Weighted Moving Average)
    // ---------------------------------------------------------------------------
    // Herleitung: τ = -Δt / ln(1 - α)
    //
    // Speed (α=0.2 für 1s-Updates):
    //   τ = -1.0 / ln(0.8) = 4.481s
    //   → Speed-Filter hat ~4.5s "Gedächtnis"
    //   → Verhindert Sprünge bei GPS-Jitter (~2-3m Genauigkeit)
    //   → Kalibrierung: α=0.1 wäre zu langsam (9.5s), α=0.3 zu schnell (2.8s)
    //
    // HR (α=0.1 für 1s-Updates):
    //   τ = -1.0 / ln(0.9) = 9.491s
    //   → HR-Filter hat ~9.5s "Gedächtnis"
    //   → Verhindert Sprünge bei HR-Sensor-Noise (~5-10bpm)
    //   → Kalibrierung: α=0.05 wäre zu langsam (19.5s), α=0.2 zu schnell (4.5s)
    //
    // Formel: alpha = 1 - e^(-Δt/τ)
    // Bei Δt=1s: alpha = 1 - e^(-1/4.481) ≈ 0.20 (Speed)
    // Bei Δt=1s: alpha = 1 - e^(-1/9.491) ≈ 0.10 (HR)
    (:high_mem)
    private const EWMA_SPEED_TAU_MS as Float = 4481.0;

    (:high_mem)
    private const EWMA_HR_TAU_MS as Float = 9491.0;

    // SOURCE-Konstanten werden jetzt aus EDATypes importiert
    // SOURCE-Konstanten werden jetzt aus EDATypes importiert
    // SOURCE-Konstanten werden jetzt aus EDATypes importiert
    // SOURCE-Konstanten werden jetzt aus EDATypes importiert

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
    private var lastLiveSpeed as Float? = null;
    private var lastLiveHr as Float? = null;
    private var lastDisplaySpeed as Float? = null;
    private var lastDisplayHr as Float? = null;
    private var validActiveMs as Number = 0;
    private var driftActiveMs as Number = 0;
    private var currentWorkloadSource as Number = EDATypes.SOURCE_NONE;
    private var pendingWorkloadSource as Number = EDATypes.SOURCE_NONE;
    private var pendingWorkloadSourceSamples as Number = 0;
    // lastPauseSystemTimer wird jetzt von EDALifecycleManager verwaltet
    private var isRenderCacheRefreshDeferred as Boolean = false;
    private var isRenderCacheDirty as Boolean = false;
    private var hasCompletedWarmupThisSession as Boolean = false;
    private var hasPostResetCollectingStatus as Boolean = false;
    private var postResetCollectingStatus as Number = EDATypes.STATUS_WAIT;
    private var postResetCollectingDetail as String = "";
    private var postResetCollectingDetailShort as String = "";

    private var statusDetail as String = "";
    private var statusDetailShort as String = "";

    private var lblAktPace as String = "";
    private var lblAktHr as String = "";
    private var lblAktPaceShort as String = "";
    private var lblAktHrShort as String = "";
    private var lblStatusWait as String = "";
    private var lblStatusWaitShort as String = "";
    private var lblStatusPause as String = "";
    private var lblStatusPauseShort as String = "";
    private var lblStatusWarmup as String = "";
    private var lblStatusWarmupShort as String = "";
    private var lblStatusProvisional as String = "";
    private var lblStatusProvisionalShort as String = "";
    private var lblStatusProfileTimeout as String = "";
    private var lblStatusProfileTimeoutShort as String = "";
    private var lblStatusConfigError as String = "";
    private var lblStatusConfigErrorShort as String = "";
    private var lblStatusNoHr as String = "";
    private var lblStatusNoHrShort as String = "";
    private var lblStatusLowHr as String = "";
    private var lblStatusLowHrShort as String = "";
    private var lblStatusSpike as String = "";
    private var lblStatusSpikeShort as String = "";
    private var lblStatusLowPower as String = "";
    private var lblStatusLowPowerShort as String = "";
    private var lblStatusLowPace as String = "";
    private var lblStatusLowPaceShort as String = "";
    private var lblStatusNoPower as String = "";
    private var lblStatusNoPowerShort as String = "";
    private var lblStatusNoSpeed as String = "";
    private var lblStatusNoSpeedShort as String = "";
    private var lblStatusInvalidSpeed as String = "";
    private var lblStatusInvalidSpeedShort as String = "";
    private var lblStatusGap as String = "";
    private var lblStatusGapShort as String = "";
    private var lblNotSaved as String = "";
    private var lblNotSavedShort as String = "";
    private var lblTypeUnknown as String = "";
    private var lblTypeUnknownShort as String = "";
    private var msgCollectingData as String = "";
    private var msgCollectingDataShort as String = "";
    private var msgPowerRequired as String = "";
    private var msgPowerRequiredShort as String = "";
    private var msgNoSpeed as String = "";
    private var msgNoSpeedShort as String = "";
    private var msgInvalidSpeed as String = "";
    private var msgInvalidSpeedShort as String = "";
    private var msgProfileRetry as String = "";
    private var msgProfileRetryShort as String = "";
    private var msgProfileErrorPrefix as String = "";
    private var msgProfileErrorPrefixShort as String = "";
    private var msgProvisionalProfile as String = "";
    private var msgProvisionalProfileShort as String = "";
    private var msgProfileTimeout as String = "";
    private var msgProfileTimeoutShort as String = "";
    private var msgConfigRequired as String = "";
    private var msgConfigRequiredShort as String = "";
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
    private var driftStatus as Number = EDATypes.STATUS_WAIT;
    private var valAktHr as String = "--";

    (:high_mem)
    private var valSollPace as String = "--:--";

    (:high_mem)
    private var valSollHr as String = "--";

    (:high_mem)
    private var modelValid as Boolean = false;

    (:high_mem)
    private var modelErrorMessage as String = "";

    private var renderPaceLine as String = "";
    private var renderPaceShortLine as String = "";
    private var renderDriftLine as String = "";
    private var renderDriftShortLine as String = "";
    private var renderStatusDetailLine as String = "";
    private var renderStatusDetailShortLine as String = "";
    private var renderDefaultDetailLine as String = "";
    private var renderDefaultDetailShortLine as String = "";
    private var renderHrLine as String = "";
    private var renderHrShortLine as String = "";
    private var renderModelErrorLine as String = "";
    private var renderShowModelError as Boolean = false;

    (:high_mem)
    private var renderExpectedPaceLine as String = "";

    (:high_mem)
    private var renderExpectedPaceShortLine as String = "";

    (:high_mem)
    private var renderExpectedHrLine as String = "";

    (:high_mem)
    private var renderExpectedHrShortLine as String = "";

    private var bgColor as Number = Graphics.COLOR_WHITE;
    private var fgColor as Number = Graphics.COLOR_BLACK;

    private var fitExportState as EDAFitExportState? = null;
    private var profileResolver as EDAProfileResolver? = null;
    private var driftEngine as EDADriftEngine? = null;
    private var renderer as EDARenderer? = null;
    private var workloadSourceSelector as EDAWorkloadSourceSelector? = null;
    private var lifecycleManager as EDALifecycleManager? = null;
    private var highMemRenderModel as Dictionary? = null;
    private var lowMemRenderModel as Dictionary? = null;
    private var areStringsLoaded as Boolean = false;
    private const DRIFT_GRAPH_ID = 0;
    private const DRIFT_AVG_ID = 1;
    private const PROFILE_STATE_ID = 2;

    function initialize() {
        DataField.initialize();
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
        workloadSourceSelector = new EDAWorkloadSourceSelector();
        lifecycleManager = new EDALifecycleManager();
        initializeRenderModels();
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
        lblStatusWaitShort = WatchUi.loadResource(Rez.Strings.lblStatusWaitShort) as String;
        lblStatusPause = WatchUi.loadResource(Rez.Strings.lblStatusPause) as String;
        lblStatusPauseShort = WatchUi.loadResource(Rez.Strings.lblStatusPauseShort) as String;
        lblStatusWarmup = WatchUi.loadResource(Rez.Strings.lblStatusWarmup) as String;
        lblStatusWarmupShort = WatchUi.loadResource(Rez.Strings.lblStatusWarmupShort) as String;
        lblStatusProvisional = WatchUi.loadResource(Rez.Strings.lblStatusProvisional) as String;
        lblStatusProvisionalShort = WatchUi.loadResource(Rez.Strings.lblStatusProvisionalShort) as String;
        lblStatusProfileTimeout = WatchUi.loadResource(Rez.Strings.lblStatusProfileTimeout) as String;
        lblStatusProfileTimeoutShort = WatchUi.loadResource(Rez.Strings.lblStatusProfileTimeoutShort) as String;
        lblStatusConfigError = WatchUi.loadResource(Rez.Strings.lblStatusConfigError) as String;
        lblStatusConfigErrorShort = WatchUi.loadResource(Rez.Strings.lblStatusConfigErrorShort) as String;
        lblStatusNoHr = WatchUi.loadResource(Rez.Strings.lblStatusNoHr) as String;
        lblStatusNoHrShort = WatchUi.loadResource(Rez.Strings.lblStatusNoHrShort) as String;
        lblStatusLowHr = WatchUi.loadResource(Rez.Strings.lblStatusLowHr) as String;
        lblStatusLowHrShort = WatchUi.loadResource(Rez.Strings.lblStatusLowHrShort) as String;
        lblStatusSpike = WatchUi.loadResource(Rez.Strings.lblStatusSpike) as String;
        lblStatusSpikeShort = WatchUi.loadResource(Rez.Strings.lblStatusSpikeShort) as String;
        lblStatusLowPower = WatchUi.loadResource(Rez.Strings.lblStatusLowPower) as String;
        lblStatusLowPowerShort = WatchUi.loadResource(Rez.Strings.lblStatusLowPowerShort) as String;
        lblStatusLowPace = WatchUi.loadResource(Rez.Strings.lblStatusLowPace) as String;
        lblStatusLowPaceShort = WatchUi.loadResource(Rez.Strings.lblStatusLowPaceShort) as String;
        lblStatusNoPower = WatchUi.loadResource(Rez.Strings.lblStatusNoPower) as String;
        lblStatusNoPowerShort = WatchUi.loadResource(Rez.Strings.lblStatusNoPowerShort) as String;
        lblStatusNoSpeed = WatchUi.loadResource(Rez.Strings.lblStatusNoSpeed) as String;
        lblStatusNoSpeedShort = WatchUi.loadResource(Rez.Strings.lblStatusNoSpeedShort) as String;
        lblStatusInvalidSpeed = WatchUi.loadResource(Rez.Strings.lblStatusInvalidSpeed) as String;
        lblStatusInvalidSpeedShort = WatchUi.loadResource(Rez.Strings.lblStatusInvalidSpeedShort) as String;
        lblStatusGap = WatchUi.loadResource(Rez.Strings.lblStatusGap) as String;
        lblStatusGapShort = WatchUi.loadResource(Rez.Strings.lblStatusGapShort) as String;
        lblNotSaved = WatchUi.loadResource(Rez.Strings.label_not_saved) as String;
        lblNotSavedShort = WatchUi.loadResource(Rez.Strings.label_not_saved_short) as String;
        lblTypeUnknown = WatchUi.loadResource(Rez.Strings.label_type_unknown) as String;
        lblTypeUnknownShort = WatchUi.loadResource(Rez.Strings.label_type_unknown_short) as String;
        msgCollectingData = WatchUi.loadResource(Rez.Strings.msgCollectingData) as String;
        msgCollectingDataShort = WatchUi.loadResource(Rez.Strings.msgCollectingDataShort) as String;
        msgPowerRequired = WatchUi.loadResource(Rez.Strings.msgPowerRequired) as String;
        msgPowerRequiredShort = WatchUi.loadResource(Rez.Strings.msgPowerRequiredShort) as String;
        msgNoSpeed = WatchUi.loadResource(Rez.Strings.msgNoSpeed) as String;
        msgNoSpeedShort = WatchUi.loadResource(Rez.Strings.msgNoSpeedShort) as String;
        msgInvalidSpeed = WatchUi.loadResource(Rez.Strings.msgInvalidSpeed) as String;
        msgInvalidSpeedShort = WatchUi.loadResource(Rez.Strings.msgInvalidSpeedShort) as String;
        msgProfileRetry = WatchUi.loadResource(Rez.Strings.msgProfileRetry) as String;
        msgProfileRetryShort = WatchUi.loadResource(Rez.Strings.msgProfileRetryShort) as String;
        msgProfileErrorPrefix = WatchUi.loadResource(Rez.Strings.msgProfileErrorPrefix) as String;
        msgProfileErrorPrefixShort = WatchUi.loadResource(Rez.Strings.msgProfileErrorPrefixShort) as String;
        msgProvisionalProfile = WatchUi.loadResource(Rez.Strings.msgProvisionalProfile) as String;
        msgProvisionalProfileShort = WatchUi.loadResource(Rez.Strings.msgProvisionalProfileShort) as String;
        msgProfileTimeout = WatchUi.loadResource(Rez.Strings.msgProfileTimeout) as String;
        msgProfileTimeoutShort = WatchUi.loadResource(Rez.Strings.msgProfileTimeoutShort) as String;
        msgConfigRequired = WatchUi.loadResource(Rez.Strings.msgConfigRequired) as String;
        msgConfigRequiredShort = WatchUi.loadResource(Rez.Strings.msgConfigRequiredShort) as String;
        msgWarmupValidSuffix = WatchUi.loadResource(Rez.Strings.msgWarmupValidSuffix) as String;
        areStringsLoaded = true;
    }

    (:low_mem)
    private function loadStrings() as Void {
        lblAktPace = WatchUi.loadResource(Rez.Strings.lblAktPaceShort) as String;
        lblAktHr = WatchUi.loadResource(Rez.Strings.lblAktHrShort) as String;
        lblAktPaceShort = lblAktPace;
        lblAktHrShort = lblAktHr;
        lblStatusWaitShort = WatchUi.loadResource(Rez.Strings.lblStatusWaitShort) as String;
        lblStatusWait = lblStatusWaitShort;
        lblStatusPauseShort = WatchUi.loadResource(Rez.Strings.lblStatusPauseShort) as String;
        lblStatusPause = lblStatusPauseShort;
        lblStatusWarmupShort = WatchUi.loadResource(Rez.Strings.lblStatusWarmupShort) as String;
        lblStatusWarmup = lblStatusWarmupShort;
        lblStatusProvisionalShort = WatchUi.loadResource(Rez.Strings.lblStatusProvisionalShort) as String;
        lblStatusProvisional = lblStatusProvisionalShort;
        lblStatusProfileTimeoutShort = WatchUi.loadResource(Rez.Strings.lblStatusProfileTimeoutShort) as String;
        lblStatusProfileTimeout = lblStatusProfileTimeoutShort;
        lblStatusConfigErrorShort = WatchUi.loadResource(Rez.Strings.lblStatusConfigErrorShort) as String;
        lblStatusConfigError = lblStatusConfigErrorShort;
        lblStatusNoHrShort = WatchUi.loadResource(Rez.Strings.lblStatusNoHrShort) as String;
        lblStatusNoHr = lblStatusNoHrShort;
        lblStatusLowHrShort = WatchUi.loadResource(Rez.Strings.lblStatusLowHrShort) as String;
        lblStatusLowHr = lblStatusLowHrShort;
        lblStatusSpikeShort = WatchUi.loadResource(Rez.Strings.lblStatusSpikeShort) as String;
        lblStatusSpike = lblStatusSpikeShort;
        lblStatusLowPowerShort = WatchUi.loadResource(Rez.Strings.lblStatusLowPowerShort) as String;
        lblStatusLowPower = lblStatusLowPowerShort;
        lblStatusLowPaceShort = WatchUi.loadResource(Rez.Strings.lblStatusLowPaceShort) as String;
        lblStatusLowPace = lblStatusLowPaceShort;
        lblStatusNoPowerShort = WatchUi.loadResource(Rez.Strings.lblStatusNoPowerShort) as String;
        lblStatusNoPower = lblStatusNoPowerShort;
        lblStatusNoSpeedShort = WatchUi.loadResource(Rez.Strings.lblStatusNoSpeedShort) as String;
        lblStatusNoSpeed = lblStatusNoSpeedShort;
        lblStatusInvalidSpeedShort = WatchUi.loadResource(Rez.Strings.lblStatusInvalidSpeedShort) as String;
        lblStatusInvalidSpeed = lblStatusInvalidSpeedShort;
        lblStatusGapShort = WatchUi.loadResource(Rez.Strings.lblStatusGapShort) as String;
        lblStatusGap = lblStatusGapShort;
        lblNotSavedShort = WatchUi.loadResource(Rez.Strings.label_not_saved_short) as String;
        lblNotSaved = lblNotSavedShort;
        lblTypeUnknownShort = WatchUi.loadResource(Rez.Strings.label_type_unknown_short) as String;
        lblTypeUnknown = lblTypeUnknownShort;
        lblCalibrationError = WatchUi.loadResource(Rez.Strings.lblCalibrationError) as String;
        msgCollectingDataShort = WatchUi.loadResource(Rez.Strings.msgCollectingDataShort) as String;
        msgCollectingData = msgCollectingDataShort;
        msgPowerRequiredShort = WatchUi.loadResource(Rez.Strings.msgPowerRequiredShort) as String;
        msgPowerRequired = msgPowerRequiredShort;
        msgNoSpeedShort = WatchUi.loadResource(Rez.Strings.msgNoSpeedShort) as String;
        msgNoSpeed = msgNoSpeedShort;
        msgInvalidSpeedShort = WatchUi.loadResource(Rez.Strings.msgInvalidSpeedShort) as String;
        msgInvalidSpeed = msgInvalidSpeedShort;
        msgProfileRetryShort = WatchUi.loadResource(Rez.Strings.msgProfileRetryShort) as String;
        msgProfileRetry = msgProfileRetryShort;
        msgProfileErrorPrefixShort = WatchUi.loadResource(Rez.Strings.msgProfileErrorPrefixShort) as String;
        msgProfileErrorPrefix = msgProfileErrorPrefixShort;
        msgProvisionalProfileShort = WatchUi.loadResource(Rez.Strings.msgProvisionalProfileShort) as String;
        msgProvisionalProfile = msgProvisionalProfileShort;
        msgProfileTimeoutShort = WatchUi.loadResource(Rez.Strings.msgProfileTimeoutShort) as String;
        msgProfileTimeout = msgProfileTimeoutShort;
        msgConfigRequiredShort = WatchUi.loadResource(Rez.Strings.msgConfigRequiredShort) as String;
        msgConfigRequired = msgConfigRequiredShort;
        msgWarmupValidSuffix = WatchUi.loadResource(Rez.Strings.msgWarmupValidSuffix) as String;
        areStringsLoaded = true;
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

    private function loadDistanceFactor() as Boolean {
        var previousDistanceFactor = mDistanceFactor;
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.paceUnits == System.UNIT_STATUTE) {
            mDistanceFactor = 1609.34;
            return previousDistanceFactor != mDistanceFactor;
        }

        mDistanceFactor = 1000.0;
        return previousDistanceFactor != mDistanceFactor;
    }

    (:high_mem)
    private function handleDistanceFactorChange() as Void {
        calculateLinearModel();
        requestRenderCacheRefresh();
    }

    (:low_mem)
    private function handleDistanceFactorChange() as Void {
        requestRenderCacheRefresh();
    }

    (:high_mem)
    private function getCurrentBaselineHr() as Float {
        return hrA;
    }

    (:low_mem)
    private function getCurrentBaselineHr() as Float {
        return referenceHr;
    }

    (:high_mem)
    private function getCurrentBaselineWorkload() as Float {
        return paceA;
    }

    (:low_mem)
    private function getCurrentBaselineWorkload() as Float {
        return referenceWorkload;
    }

    private function hasBaselineChanged(previousHr as Float, previousWorkload as Float) as Boolean {
        return (previousHr - getCurrentBaselineHr()).abs() > 0.0001
            || (previousWorkload - getCurrentBaselineWorkload()).abs() > 0.0001;
    }

    function applySettingsChange() as Void {
        var previousMinHr = minValidHrSetting;
        var previousHr = getCurrentBaselineHr();
        var previousWorkload = getCurrentBaselineWorkload();
        loadStrings();
        loadSettings();
        if ((previousMinHr - minValidHrSetting).abs() > 0.0001 || hasBaselineChanged(previousHr, previousWorkload)) {
            resetSessionFitSummary();
            resetSessionState();
            return;
        }

        if (isTargetModelSupported() && !isInvalidDisplayState()) {
            updateTargetDisplay(getDisplaySpeed(lastDisplaySpeed), getDisplayHr(lastDisplayHr));
        }
        requestRenderCacheRefresh();
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
        var previousCalibrationState = isEngineCalibrated;
        isEngineCalibrated = hasValidConfiguration();
        if (driftEngine != null) {
            getDriftEngine().setCalibrated(isEngineCalibrated);
        }
        if (previousCalibrationState != isEngineCalibrated && renderer != null) {
            requestRenderCacheRefresh();
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

    private function hasFallbackExportWindowElapsed() as Boolean {
        return mTimerTime >= EDAFeatureFlags.getFallbackExportTimeoutMs();
    }

    private function canExportFitData() as Boolean {
        // Record developer fields are forward-only; unresolved fallback samples
        // cannot be backfilled into older FIT record messages.
        if (hasAuthoritativeProfile()) {
            return true;
        }

        if (!isFallbackProfileConfirmed()) {
            return false;
        }

        return mTimerTime >= EDAFeatureFlags.getFallbackExportTimeoutMs();
    }

    private function getRenderedDriftValuePrefix(isShort as Boolean) as String? {
        if (driftStatus != EDATypes.STATUS_VALUE) {
            return null;
        }

        if (isProfileProvisional()) {
            return isShort ? lblStatusProvisionalShort : lblStatusProvisional;
        }

        if (isFallbackProfileConfirmed()) {
            return isShort ? lblTypeUnknownShort : lblTypeUnknown;
        }

        if (!canExportFitData()) {
            return isShort ? lblNotSavedShort : lblNotSaved;
        }

        return null;
    }

    private function getStatusLabel(statusCode as Number) as String {
        return EDAStatusManager.getStatusLabel(
            statusCode,
            lblStatusWait, lblStatusPause, lblStatusWarmup, lblStatusProvisional,
            lblStatusProfileTimeout, lblStatusConfigError, lblStatusNoHr, lblStatusLowHr,
            lblStatusSpike, lblStatusLowPower, lblStatusLowPace, lblStatusNoPower,
            lblStatusNoSpeed, lblStatusInvalidSpeed, lblStatusGap,
            strDrift
        );
    }

    private function getStatusShortLabel(statusCode as Number) as String {
        return EDAStatusManager.getStatusShortLabel(
            statusCode,
            lblStatusWaitShort, lblStatusPauseShort, lblStatusWarmupShort, lblStatusProvisionalShort,
            lblStatusProfileTimeoutShort, lblStatusConfigErrorShort, lblStatusNoHrShort, lblStatusLowHrShort,
            lblStatusSpikeShort, lblStatusLowPowerShort, lblStatusLowPaceShort, lblStatusNoPowerShort,
            lblStatusNoSpeedShort, lblStatusInvalidSpeedShort, lblStatusGapShort,
            strDrift
        );
    }

    private function getRenderedDriftLabel() as String {
        if (!isEngineCalibrated) {
            return lblStatusConfigError;
        }

        if (driftStatus != EDATypes.STATUS_VALUE) {
            return getStatusLabel(driftStatus);
        }

        var driftPrefix = getRenderedDriftValuePrefix(false);
        if (driftPrefix != null && (driftPrefix as String) != "") {
            return (driftPrefix as String) + " " + strDrift;
        }

        return strDrift;
    }

    private function getRenderedDriftShortLabel() as String {
        if (!isEngineCalibrated) {
            return lblStatusConfigErrorShort;
        }

        if (driftStatus != EDATypes.STATUS_VALUE) {
            return getStatusShortLabel(driftStatus);
        }

        var driftPrefix = getRenderedDriftValuePrefix(true);
        if (driftPrefix != null && (driftPrefix as String) != "") {
            return (driftPrefix as String) + " " + strDrift;
        }

        return strDrift;
    }

    private function shouldShowProfileErrorDetail() as Boolean {
        if (hasAuthoritativeProfile()) {
            return false;
        }

        return driftStatus == EDATypes.STATUS_WAIT || driftStatus == EDATypes.STATUS_PROVISIONAL || driftStatus == EDATypes.STATUS_PROFILE_TIMEOUT;
    }

    private function getDefaultStatusDetail() as String? {
        if (driftStatus == EDATypes.STATUS_WAIT) {
            return msgCollectingData;
        } else if (driftStatus == EDATypes.STATUS_CFG_ERR) {
            return msgConfigRequired;
        } else if (driftStatus == EDATypes.STATUS_NO_POWER) {
            return msgPowerRequired;
        } else if (driftStatus == EDATypes.STATUS_NO_SPEED) {
            return msgNoSpeed;
        } else if (driftStatus == EDATypes.STATUS_INVALID_SPEED) {
            return msgInvalidSpeed;
        } else if (driftStatus == EDATypes.STATUS_PROVISIONAL) {
            return msgProvisionalProfile;
        } else if (driftStatus == EDATypes.STATUS_PROFILE_TIMEOUT) {
            return msgProfileTimeout;
        }

        var lastErrorCode = getProfileResolver().getLastErrorCode();
        if (lastErrorCode != "" && shouldShowProfileErrorDetail()) {
            return msgProfileErrorPrefix + ": " + lastErrorCode;
        }

        return null;
    }

    private function getDefaultStatusDetailShort() as String? {
        if (driftStatus == EDATypes.STATUS_WAIT) {
            return msgCollectingDataShort;
        } else if (driftStatus == EDATypes.STATUS_CFG_ERR) {
            return msgConfigRequiredShort;
        } else if (driftStatus == EDATypes.STATUS_NO_POWER) {
            return msgPowerRequiredShort;
        } else if (driftStatus == EDATypes.STATUS_NO_SPEED) {
            return msgNoSpeedShort;
        } else if (driftStatus == EDATypes.STATUS_INVALID_SPEED) {
            return msgInvalidSpeedShort;
        } else if (driftStatus == EDATypes.STATUS_PROVISIONAL) {
            return msgProvisionalProfileShort;
        } else if (driftStatus == EDATypes.STATUS_PROFILE_TIMEOUT) {
            return msgProfileTimeoutShort;
        }

        var lastErrorCode = getProfileResolver().getLastErrorCode();
        if (lastErrorCode != "" && shouldShowProfileErrorDetail()) {
            return msgProfileErrorPrefixShort + ": " + lastErrorCode;
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

    private function getWorkloadSourceSelector() as EDAWorkloadSourceSelector {
        return workloadSourceSelector as EDAWorkloadSourceSelector;
    }

    private function getLifecycleManager() as EDALifecycleManager {
        return lifecycleManager as EDALifecycleManager;
    }

    (:high_mem)
    private function initializeRenderModels() as Void {
        highMemRenderModel = {};
        lowMemRenderModel = null;
        requestRenderCacheRefresh();
    }

    (:low_mem)
    private function initializeRenderModels() as Void {
        highMemRenderModel = null;
        lowMemRenderModel = {};
        requestRenderCacheRefresh();
    }

    private function requestRenderCacheRefresh() as Void {
        isRenderCacheDirty = true;
        if (!isRenderCacheRefreshDeferred) {
            flushRenderCacheRefresh();
        }
    }

    private function flushRenderCacheRefresh() as Void {
        if (!isRenderCacheDirty) {
            return;
        }

        refreshRenderCache();
        isRenderCacheDirty = false;
    }

    private function beginDeferredRenderCacheRefresh() as Void {
        isRenderCacheRefreshDeferred = true;
    }

    private function endDeferredRenderCacheRefresh() as Void {
        isRenderCacheRefreshDeferred = false;
        flushRenderCacheRefresh();
    }

    private function clearRawLiveSampleState() as Void {
        lastLiveSpeed = null;
        lastLiveHr = null;
    }

    private function clearDisplaySampleState() as Void {
        lastDisplaySpeed = null;
        lastDisplayHr = null;
    }

    private function updateDisplaySampleState(speed as Float?, hr as Float?) as Void {
        lastDisplaySpeed = (lastLiveSpeed != null) ? lastLiveSpeed : speed;
        lastDisplayHr = (lastLiveHr != null) ? lastLiveHr : hr;
    }

    private function shouldRetainDisplaySampleState(statusCode as Number) as Boolean {
        return statusCode == EDATypes.STATUS_WAIT || statusCode == EDATypes.STATUS_WARMUP;
    }

    private function clearPostResetCollectingStatus() as Void {
        hasPostResetCollectingStatus = false;
        postResetCollectingStatus = EDATypes.STATUS_WAIT;
        postResetCollectingDetail = "";
        postResetCollectingDetailShort = "";
    }

    private function clearWarmupSessionState() as Void {
        hasCompletedWarmupThisSession = false;
        clearPostResetCollectingStatus();
    }

    // Preserve why a mid-session reset happened so recollection does not look
    // like the very first warmup of the activity.
    private function rememberPostResetCollectingStatus(statusCode as Number, detailText as String, shortDetailText as String) as Void {
        if (!hasCompletedWarmupThisSession) {
            clearPostResetCollectingStatus();
            return;
        }

        hasPostResetCollectingStatus = true;
        postResetCollectingStatus = statusCode;
        postResetCollectingDetail = detailText;
        postResetCollectingDetailShort = shortDetailText;
    }

    private function applyPostResetCollectingStatus() as Boolean {
        if (!hasPostResetCollectingStatus) {
            return false;
        }

        if (postResetCollectingStatus == EDATypes.STATUS_WAIT) {
            setCollectingStatus();
            return true;
        }

        if (postResetCollectingDetail != "" || postResetCollectingDetailShort != "") {
            setStatusWithDetail(postResetCollectingStatus, postResetCollectingDetail, postResetCollectingDetailShort);
        } else {
            setStatus(postResetCollectingStatus);
        }
        return true;
    }

    private function shouldShowWarmupStatus() as Boolean {
        return EDASessionPolicy.shouldShowWarmupStatus(hasCompletedWarmupThisSession, hasPostResetCollectingStatus);
    }

    private function markWarmupCompleted() as Void {
        hasCompletedWarmupThisSession = true;
        clearPostResetCollectingStatus();
    }

    private function getRenderSafePaceValue() as String {
        var currentPaceValue = getRenderedCurrentPaceValue();
        if (currentPaceValue.equals(INVALID_RENDER_VALUE)) {
            return "--:--";
        }

        return currentPaceValue;
    }

    private function getRenderSafeHrValue() as String {
        var currentHrValue = getRenderedCurrentHrValue();
        if (currentHrValue.equals(INVALID_RENDER_VALUE)) {
            return "--";
        }

        return currentHrValue;
    }

    (:high_mem)
    private function refreshRenderCache() as Void {
        var currentPaceValue = getRenderSafePaceValue();
        var currentHrValue = getRenderSafeHrValue();
        renderPaceLine = lblAktPace + currentPaceValue;
        renderPaceShortLine = lblAktPaceShort + currentPaceValue;
        renderExpectedPaceLine = lblSollPace + valSollPace;
        renderExpectedPaceShortLine = lblSollPaceShort + valSollPace;
        renderExpectedHrLine = lblSollHr + valSollHr;
        renderExpectedHrShortLine = lblSollHrShort + valSollHr;
        renderDriftLine = getRenderedDriftLabel();
        renderDriftShortLine = getRenderedDriftShortLabel();
        renderStatusDetailLine = statusDetail;
        renderStatusDetailShortLine = statusDetailShort != "" ? statusDetailShort : statusDetail;

        var defaultDetail = getDefaultStatusDetail();
        renderDefaultDetailLine = (defaultDetail == null) ? "" : defaultDetail;
        var defaultDetailShort = getDefaultStatusDetailShort();
        renderDefaultDetailShortLine = (defaultDetailShort == null) ? renderDefaultDetailLine : defaultDetailShort;

        renderHrLine = lblAktHr + currentHrValue;
        renderHrShortLine = lblAktHrShort + currentHrValue;
        renderShowModelError = isRunningProfile() && modelErrorMessage != "";
        renderModelErrorLine = modelErrorMessage;

        var model = highMemRenderModel as Dictionary;
        model[:renderBgColor] = bgColor;
        model[:renderFgColor] = fgColor;
        model[:paceLine] = renderPaceLine;
        model[:paceShortLine] = renderPaceShortLine;
        model[:expectedPaceLine] = renderExpectedPaceLine;
        model[:expectedPaceShortLine] = renderExpectedPaceShortLine;
        model[:driftLine] = renderDriftLine;
        model[:driftShortLine] = renderDriftShortLine;
        model[:renderStatusDetailLine] = renderStatusDetailLine;
        model[:renderStatusDetailShortLine] = renderStatusDetailShortLine;
        model[:showModelError] = renderShowModelError;
        model[:renderModelErrorLine] = renderModelErrorLine;
        model[:defaultDetailLine] = renderDefaultDetailLine;
        model[:defaultDetailShortLine] = renderDefaultDetailShortLine;
        model[:expectedHrLine] = renderExpectedHrLine;
        model[:expectedHrShortLine] = renderExpectedHrShortLine;
        model[:hrLine] = renderHrLine;
        model[:hrShortLine] = renderHrShortLine;
    }

    (:low_mem)
    private function refreshRenderCache() as Void {
        var currentPaceValue = getRenderSafePaceValue();
        var currentHrValue = getRenderSafeHrValue();
        renderPaceLine = lblAktPace + currentPaceValue;
        renderPaceShortLine = lblAktPaceShort + currentPaceValue;
        renderDriftLine = getRenderedDriftLabel();
        renderDriftShortLine = getRenderedDriftShortLabel();
        renderStatusDetailLine = statusDetail;
        renderStatusDetailShortLine = statusDetailShort != "" ? statusDetailShort : statusDetail;

        var defaultDetail = getDefaultStatusDetail();
        renderDefaultDetailLine = (defaultDetail == null) ? "" : defaultDetail;
        var defaultDetailShort = getDefaultStatusDetailShort();
        renderDefaultDetailShortLine = (defaultDetailShort == null) ? renderDefaultDetailLine : defaultDetailShort;

        renderHrLine = lblAktHr + currentHrValue;
        renderHrShortLine = lblAktHrShort + currentHrValue;
        renderShowModelError = false;
        renderModelErrorLine = "";

        var model = lowMemRenderModel as Dictionary;
        model[:renderBgColor] = bgColor;
        model[:renderFgColor] = fgColor;
        model[:paceLine] = renderPaceLine;
        model[:paceShortLine] = renderPaceShortLine;
        model[:driftLine] = renderDriftLine;
        model[:driftShortLine] = renderDriftShortLine;
        model[:renderStatusDetailLine] = renderStatusDetailLine;
        model[:renderStatusDetailShortLine] = renderStatusDetailShortLine;
        model[:defaultDetailLine] = renderDefaultDetailLine;
        model[:defaultDetailShortLine] = renderDefaultDetailShortLine;
        model[:hrLine] = renderHrLine;
        model[:hrShortLine] = renderHrShortLine;
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

    private function getProfileRetryDetailShort() as String {
        var lastErrorCode = getProfileResolver().getLastErrorCode();
        if (lastErrorCode == "") {
            return msgProfileRetryShort;
        }

        return msgProfileErrorPrefixShort + ": " + lastErrorCode;
    }

    private function setInvalidStatus(statusCode as Number) as Void {
        setStatus(statusCode);
    }

    private function setInvalidStatusWithDetail(statusCode as Number, detailText as String) as Void {
        setStatusWithDetail(statusCode, detailText, detailText);
    }

    private function setInvalidStatusWithShortDetail(statusCode as Number, detailText as String, shortDetailText as String) as Void {
        setStatusWithDetail(statusCode, detailText, shortDetailText);
    }

    private function setCollectingStatus() as Void {
        if (!isEngineCalibrated) {
            setStatusWithDetail(EDATypes.STATUS_CFG_ERR, msgConfigRequired, msgConfigRequiredShort);
            return;
        }

        if (isProfileProvisional()) {
            setStatusWithDetail(EDATypes.STATUS_PROVISIONAL, msgProvisionalProfile, msgProvisionalProfileShort);
        } else {
            setStatus(EDATypes.STATUS_WAIT);
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
        requestRenderCacheRefresh();
    }

    private function isInvalidDisplayState() as Boolean {
        return driftStatus != EDATypes.STATUS_VALUE;
    }

    private function shouldUseLiveRenderFallback() as Boolean {
        return driftStatus == EDATypes.STATUS_WAIT || driftStatus == EDATypes.STATUS_WARMUP;
    }

    (:high_mem)
    private function getRenderModelSpeed() as Float? {
        if (!filterInitialized || validActiveMs < EDAFeatureFlags.getWarmupValidMs()) {
            return Math.sqrt(-1.0);
        }

        return ewmaSpeed;
    }

    (:low_mem)
    private function getRenderModelSpeed() as Float? {
        return null;
    }

    (:high_mem)
    private function getRenderModelHr() as Float? {
        if (!filterInitialized || validActiveMs < EDAFeatureFlags.getWarmupValidMs()) {
            return Math.sqrt(-1.0);
        }

        return ewmaHr;
    }

    (:low_mem)
    private function getRenderModelHr() as Float? {
        return null;
    }

    private function getRenderedCurrentPaceValue() as String {
        if (shouldUseLiveRenderFallback()) {
            var displaySpeed = getRenderModelSpeed();
            if (displaySpeed != null && displaySpeed == displaySpeed && displaySpeed > 0.0) {
                return formatPace(displaySpeed);
            }

            if (lastDisplaySpeed != null && (lastDisplaySpeed as Float) > 0.0) {
                return formatPace(lastDisplaySpeed as Float);
            }

            return INVALID_RENDER_VALUE;
        }

        if (isInvalidDisplayState()) {
            return INVALID_RENDER_VALUE;
        }

        return valAktPace;
    }

    private function getRenderedCurrentHrValue() as String {
        if (shouldUseLiveRenderFallback()) {
            var displayHr = getRenderModelHr();
            if (displayHr != null && displayHr == displayHr && displayHr > 0.0) {
                return displayHr.toNumber().toString();
            }

            if (lastDisplayHr != null && (lastDisplayHr as Float) > 0.0) {
                return (lastDisplayHr as Float).toNumber().toString();
            }

            return INVALID_RENDER_VALUE;
        }

        if (isInvalidDisplayState()) {
            return INVALID_RENDER_VALUE;
        }

        return valAktHr;
    }

    private function clearPendingWorkloadSourceSwitch() as Void {
        pendingWorkloadSource = EDATypes.SOURCE_NONE;
        pendingWorkloadSourceSamples = 0;
    }

    private function rememberPauseTimestamp() as Void {
        getLifecycleManager().rememberPauseTimestamp();
        clearRawLiveSampleState();
        clearDisplaySampleState();
    }

    private function shouldResetAfterResumePause() as Boolean {
        return getLifecycleManager().shouldResetAfterResumePause();
    }

    private function hasAcceptedDataGap(timerTime as Number) as Boolean {
        var previousAcceptedTimerTime = lastAcceptedDriftSampleTime;
        if (previousAcceptedTimerTime == null || timerTime <= previousAcceptedTimerTime) {
            return false;
        }

        return (timerTime - previousAcceptedTimerTime) > EDAFeatureFlags.getDataDrivenGapMs();
    }

    private function clearLifecyclePauseState() as Void {
        getLifecycleManager().clearLifecyclePauseState();
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
        clearRawLiveSampleState();
        clearDisplaySampleState();
        currentWorkloadSource = EDATypes.SOURCE_NONE;
        valAktPace = "--:--";
        valAktHr = "--";
        resetTargetDisplay();
        statusDetail = "";
        statusDetailShort = "";
        getDriftEngine().reset();
        if (!isEngineCalibrated) {
            setStatusWithDetail(EDATypes.STATUS_CFG_ERR, msgConfigRequired, msgConfigRequiredShort);
            return;
        }

        setStatus(EDATypes.STATUS_WAIT);
    }

    private function handleImplicitSessionReset() as Void {
        clearLifecyclePauseState();
        getProfileResolver().handleImplicitSessionReset();
        resetSessionFitSummary();
        clearWarmupSessionState();
        resetAnalysisState();
    }

    private function resolveActivityProfile() as Void {
        var previousMinValidHr = getMinValidHr();
        var previousCanUseSpeedWorkload = canUseSpeedWorkload();
        var previouslyAuthoritative = hasAuthoritativeProfile();
        if (getProfileResolver().resolveActivityProfile(mTimerTime)) {
            if (EDASessionPolicy.shouldResetSessionFitSummaryForProfileChange(
                previousMinValidHr,
                previousCanUseSpeedWorkload,
                previouslyAuthoritative,
                getMinValidHr(),
                canUseSpeedWorkload(),
                hasAuthoritativeProfile()
            )) {
                resetSessionFitSummary();
            }
            resetAnalysisState();
            rememberPostResetCollectingStatus(EDATypes.STATUS_WAIT, "", "");
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

    private function setStatus(statusCode as Number) as Void {
        writeInvalidRecord();
        resetTargetDisplay();
        driftStatus = statusCode;
        strDrift = "--";
        statusDetail = "";
        statusDetailShort = "";
        if (!shouldRetainDisplaySampleState(statusCode)) {
            clearDisplaySampleState();
        }
        setNeutralColors();
        requestRenderCacheRefresh();
    }

    private function setStatusWithDetail(statusCode as Number, detailText as String, shortDetailText as String) as Void {
        writeInvalidRecord();
        resetTargetDisplay();
        driftStatus = statusCode;
        strDrift = "--";
        statusDetail = detailText;
        statusDetailShort = shortDetailText;
        if (!shouldRetainDisplaySampleState(statusCode)) {
            clearDisplaySampleState();
        }
        setNeutralColors();
        requestRenderCacheRefresh();
    }

    (:high_mem)
    private function updateLiveDisplay(speed as Float?, hr as Float?) as Void {
        updateDisplaySampleState(speed, hr);
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
            requestRenderCacheRefresh();
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
        requestRenderCacheRefresh();
    }

    (:low_mem)
    private function updateLiveDisplay(speed as Float?, hr as Float?) as Void {
        updateDisplaySampleState(speed, hr);
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
        requestRenderCacheRefresh();
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
            requestRenderCacheRefresh();
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
        requestRenderCacheRefresh();
    }

    (:low_mem)
    private function updateTargetDisplay(displaySpeed as Float?, displayHr as Float?) as Void {
        resetTargetDisplay();
        requestRenderCacheRefresh();
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
        if (deltaMs <= 0 || deltaMs > EDAFeatureFlags.getMaxValidSampleGapMs()) {
            return false;
        }

        var allowedJump = EDAFeatureFlags.getHrJumpPerSec() * (deltaMs.toFloat() / 1000.0);
        return (hr - previousHr).abs() > allowedJump;
    }

    private function isSpeedOutlier(speed as Float, timerTime as Number) as Boolean {
        var previousSpeed = lastAcceptedSpeed;
        var previousTimer = lastValidSpeedSignalTime;
        if (previousSpeed == null || previousTimer == null) {
            return false;
        }

        var deltaMs = timerTime - previousTimer;
        if (deltaMs <= 0 || deltaMs > EDAFeatureFlags.getMaxValidSampleGapMs()) {
            return false;
        }

        var allowedJump = EDAFeatureFlags.getSpeedJumpPerSec() * (deltaMs.toFloat() / 1000.0);
        return (speed - previousSpeed).abs() > allowedJump;
    }

    private function hasUsablePower(power as Float?) as Boolean {
        if (power == null) {
            return false;
        }

        return power >= EDAFeatureFlags.getMinValidPower() && power <= EDAFeatureFlags.getMaxValidPower();
    }

    private function getPowerValidationError(power as Float?) as Number? {
        if (power == null) {
            return null;
        }

        if (power < EDAFeatureFlags.getMinValidPower()) {
            return EDATypes.STATUS_LOW_POWER;
        }

        if (power > EDAFeatureFlags.getMaxValidPower()) {
            return EDATypes.STATUS_SPIKE;
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

        if (speed == null || speed > EDAFeatureFlags.getMaxSpeedMs()) {
            return false;
        }

        var runPace = pacePerKmSeconds(speed);
        return runPace != null && runPace <= EDAFeatureFlags.getMaxRunningPacePerKm();
    }

    private function getSpeedValidationError(speed as Float?, timerTime as Number) as Number? {
        if (!canUseSpeedWorkload()) {
            return null;
        }

        if (speed == null) {
            return EDATypes.STATUS_NO_SPEED;
        }

        if (speed <= 0.0) {
            return EDATypes.STATUS_LOW_PACE;
        }

        if (speed > EDAFeatureFlags.getMaxSpeedMs()) {
            return EDATypes.STATUS_INVALID_SPEED;
        }

        var runPace = pacePerKmSeconds(speed);
        if (runPace == null) {
            return EDATypes.STATUS_INVALID_SPEED;
        }

        if (runPace > EDAFeatureFlags.getMaxRunningPacePerKm()) {
            return EDATypes.STATUS_LOW_PACE;
        }

        if (isSpeedOutlier(speed, timerTime)) {
            return EDATypes.STATUS_INVALID_SPEED;
        }

        return null;
    }

    private function updateValidSpeedSignal(speed as Float?, timerTime as Number, speedValidationError as Number?) as Void {
        if (!canUseSpeedWorkload() || speed == null || speedValidationError != null) {
            return;
        }

        lastAcceptedSpeed = speed;
        lastValidSpeedSignalTime = timerTime;
    }

    private function getWorkloadValidationError(speedError as Number?, power as Float?) as Number? {
        if (hasUsablePower(power)) {
            return null;
        }

        var powerError = getPowerValidationError(power);
        if (!canUseSpeedWorkload()) {
            if (powerError != null) {
                return powerError;
            }

            return EDATypes.STATUS_NO_POWER;
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

        return EDATypes.STATUS_NO_POWER;
    }

    private function determinePreferredWorkloadSource(speed as Float?, power as Float?) as Number {
        return getWorkloadSourceSelector().determinePreferredWorkloadSource(speed, power);
    }

    private function isWorkloadSourceUsable(workloadSource as Number, speed as Float?, power as Float?) as Boolean {
        return getWorkloadSourceSelector().isWorkloadSourceUsable(workloadSource, speed, power);
    }

    private function determineWorkloadSource(speed as Float?, power as Float?) as Number {
        return getWorkloadSourceSelector().determineWorkloadSource(speed, power);
    }

    private function getWorkloadMetricForSource(workloadSource as Number, speed as Float?, power as Float?) as Float? {
        return getWorkloadSourceSelector().getWorkloadMetricForSource(workloadSource, speed, power);
    }

    private function validateSample(speed as Float?, hr as Float?, power as Float?, timerTime as Number) as Number? {
        if (hr == null) {
            return EDATypes.STATUS_NO_HR;
        }

        if (hr < getMinValidHr()) {
            return EDATypes.STATUS_LOW_HR;
        }

        if (isHrOutlier(hr, timerTime)) {
            return EDATypes.STATUS_SPIKE;
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
        resetAnalysisState();
        primeAnalysisBaseline(timerTime, speed, hr, workloadSource);
        rememberPostResetCollectingStatus(EDATypes.STATUS_WAIT, "", "");
        setCollectingStatus();
    }

    private function restartAnalysisAfterGap(timerTime as Number, speed as Float?, hr as Float?, workloadSource as Number) as Void {
        resetAnalysisState();
        if (hr != null && workloadSource != EDATypes.SOURCE_NONE) {
            primeAnalysisBaseline(timerTime, speed, hr, workloadSource);
        }
        rememberPostResetCollectingStatus(EDATypes.STATUS_GAP, "", "");
        setInvalidStatus(EDATypes.STATUS_GAP);
    }

    private function resetEpochWithoutPrimingWithDetail(statusCode as Number, detailText as String) as Void {
        resetAnalysisState();
        rememberPostResetCollectingStatus(statusCode, detailText, detailText);
        setInvalidStatusWithDetail(statusCode, detailText);
    }

    private function resetEpochWithoutPrimingWithShortDetail(statusCode as Number, detailText as String, shortDetailText as String) as Void {
        resetAnalysisState();
        rememberPostResetCollectingStatus(statusCode, detailText, shortDetailText);
        setInvalidStatusWithShortDetail(statusCode, detailText, shortDetailText);
    }

    private function validateSourceConsistency(timerTime as Number, speed as Float?, hr as Float, workloadSource as Number, deltaMs as Number) as Boolean {
        if (deltaMs > EDAFeatureFlags.getMaxValidSampleGapMs()) {
            clearPendingWorkloadSourceSwitch();
            restartAnalysisAfterGap(timerTime, speed, hr, workloadSource);
            return false;
        }

        if (currentWorkloadSource == EDATypes.SOURCE_NONE || workloadSource == currentWorkloadSource) {
            clearPendingWorkloadSourceSwitch();
            return true;
        }

        if (pendingWorkloadSource != workloadSource) {
            pendingWorkloadSource = workloadSource;
            pendingWorkloadSourceSamples = 1;
        } else {
            pendingWorkloadSourceSamples += 1;
        }

        if (pendingWorkloadSourceSamples < EDAFeatureFlags.getSourceSwitchConfirmSamples()) {
            setCollectingStatus();
            return false;
        }

        clearPendingWorkloadSourceSwitch();
        restartAnalysisAfterSourceSwitch(timerTime, speed, hr, workloadSource);
        return false;
    }

    private function updateDriftDisplay(driftPercent as Float) as Void {
        var sign = driftPercent > 0.0 ? "+" : "";
        driftStatus = EDATypes.STATUS_VALUE;
        strDrift = sign + driftPercent.format("%.1f") + "%";
        statusDetail = "";
        statusDetailShort = "";

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
        requestRenderCacheRefresh();
    }

    private function updateFitFields(driftPercent as Float, intervalMs as Number) as Void {
        getFitExportState().updateFitFields(getProfileResolver().getState(), canExportFitData(), driftPercent, intervalMs, currentWorkloadSource);
    }

    private function resetSessionFitSummary() as Void {
        getFitExportState().resetSessionFitSummary();
    }

    (:high_mem)
    private function buildHighMemRenderModel() as Dictionary {
        return highMemRenderModel as Dictionary;
    }

    (:low_mem)
    private function buildLowMemRenderModel() as Dictionary {
        return lowMemRenderModel as Dictionary;
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
        clearWarmupSessionState();
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
        setInvalidStatus(EDATypes.STATUS_PAUSE);
        WatchUi.requestUpdate();
    }

    function onTimerResume() as Void {
        if (getLifecycleManager().getPauseTimestamp() == null) {
            return;
        }

        clearRawLiveSampleState();
        clearDisplaySampleState();
        setCollectingStatus();
        WatchUi.requestUpdate();
    }

    function onNextMultisportLeg() as Void {
        resetSessionFitSummary();
        resetSessionState();
        WatchUi.requestUpdate();
    }

    function compute(info as Activity.Info) as Void {
        beginDeferredRenderCacheRefresh();
        if (loadDistanceFactor()) {
            handleDistanceFactorChange();
        }
        refreshEngineCalibrationState();

        var currentTimerTime = toNumberOrNull(info.timerTime as Numeric?);
        if (currentTimerTime == null) {
            endDeferredRenderCacheRefresh();
            return;
        }
        var curSpeed = toFloatOrNull(info.currentSpeed as Numeric?);
        var curHr = toFloatOrNull(info.currentHeartRate as Numeric?);
        var curPower = toFloatOrNull(info.currentPower as Numeric?);
        lastLiveSpeed = curSpeed;
        lastLiveHr = curHr;

        if (!isEngineCalibrated) {
            setStatusWithDetail(EDATypes.STATUS_CFG_ERR, msgConfigRequired, msgConfigRequiredShort);
            endDeferredRenderCacheRefresh();
            return;
        }

        if (info.timerState != Activity.TIMER_STATE_ON) {
            rememberPauseTimestamp();
            setInvalidStatus(EDATypes.STATUS_PAUSE);
            endDeferredRenderCacheRefresh();
            return;
        }

        var previousTimerTime = lastActiveTimerTime;
        if (previousTimerTime != null && currentTimerTime < previousTimerTime) {
            var rollbackMs = previousTimerTime - currentTimerTime;
            if (rollbackMs > EDAFeatureFlags.getImplicitTimerResetToleranceMs()) {
                handleImplicitSessionReset();
            } else {
                endDeferredRenderCacheRefresh();
                return;
            }
        }

        mTimerTime = currentTimerTime;

        if (getLifecycleManager().getPauseTimestamp() != null && shouldResetAfterResumePause()) {
            restartAnalysisAfterGap(mTimerTime, null, null, EDATypes.SOURCE_NONE);
            endDeferredRenderCacheRefresh();
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
            endDeferredRenderCacheRefresh();
            return;
        }

        if (!hasUsableActivityProfile()) {
            if (getProfileResolver().isRetryPending()) {
                setInvalidStatusWithShortDetail(EDATypes.STATUS_WAIT, getProfileRetryDetail(), getProfileRetryDetailShort());
            } else {
                setCollectingStatus();
            }
            endDeferredRenderCacheRefresh();
            return;
        }

        if (hasAcceptedDataGap(mTimerTime)) {
            restartAnalysisAfterGap(mTimerTime, curSpeed, curHr, determineWorkloadSource(curSpeed, curPower));
            endDeferredRenderCacheRefresh();
            return;
        }

        var validationError = validateSample(curSpeed, curHr, curPower, mTimerTime);
        if (validationError != null) {
            if (validationError == EDATypes.STATUS_NO_HR || validationError == EDATypes.STATUS_NO_POWER || validationError == EDATypes.STATUS_INVALID_SPEED) {
                syncDisplayWithCurrentSample(curSpeed, curHr);
            }
            if (getProfileResolver().hasTimeoutNoticePending()) {
                getProfileResolver().clearTimeoutNoticePending();
                resetEpochWithoutPrimingWithShortDetail(EDATypes.STATUS_PROFILE_TIMEOUT, msgProfileTimeout, msgProfileTimeoutShort);
                endDeferredRenderCacheRefresh();
                return;
            }
            setInvalidStatus(validationError);
            endDeferredRenderCacheRefresh();
            return;
        }

        var workloadSource = determineWorkloadSource(curSpeed, curPower);
        var workload = getWorkloadMetricForSource(workloadSource, curSpeed, curPower);
        if (curHr == null || workload == null || curHr <= 0.0 || workload <= 0.0) {
        if (getProfileResolver().hasTimeoutNoticePending()) {
            getProfileResolver().clearTimeoutNoticePending();
            resetEpochWithoutPrimingWithShortDetail(EDATypes.STATUS_PROFILE_TIMEOUT, msgProfileTimeout, msgProfileTimeoutShort);
                endDeferredRenderCacheRefresh();
                return;
            }
            setCollectingStatus();
            endDeferredRenderCacheRefresh();
            return;
        }

        if (getProfileResolver().hasTimeoutNoticePending()) {
            getProfileResolver().clearTimeoutNoticePending();
            restartAnalysisAfterGap(mTimerTime, curSpeed, curHr, workloadSource);
            rememberPostResetCollectingStatus(EDATypes.STATUS_PROFILE_TIMEOUT, msgProfileTimeout, msgProfileTimeoutShort);
            setInvalidStatusWithShortDetail(EDATypes.STATUS_PROFILE_TIMEOUT, msgProfileTimeout, msgProfileTimeoutShort);
            endDeferredRenderCacheRefresh();
            return;
        }

        if (!validateSourceConsistency(mTimerTime, curSpeed, curHr, workloadSource, deltaMs)) {
            endDeferredRenderCacheRefresh();
            return;
        }

        var ef = workload / curHr;
        if (ef <= 0.0) {
            setCollectingStatus();
            endDeferredRenderCacheRefresh();
            return;
        }

        markAcceptedSample(mTimerTime, curHr);
        currentWorkloadSource = workloadSource;
        validActiveMs += deltaMs;
        var previousDriftActiveMs = driftActiveMs;
        driftActiveMs = validActiveMs;

        updateDisplayFilters(curSpeed, curHr, deltaMs);
        if (isTargetModelSupported()) {
            updateTargetDisplay(getDisplaySpeed(curSpeed), getDisplayHr(curHr));
        }

        var driftDeltaMs = driftActiveMs - previousDriftActiveMs;
        getDriftEngine().recordValidSample(driftActiveMs, driftDeltaMs, ef);

        if (driftActiveMs < EDAFeatureFlags.getWarmupValidMs()) {
            if (!shouldShowWarmupStatus() && applyPostResetCollectingStatus()) {
                endDeferredRenderCacheRefresh();
                return;
            }
            var remainingMs = EDAFeatureFlags.getWarmupValidMs() - driftActiveMs;
            var remainingSeconds = ((remainingMs + 999) / 1000).toNumber();
            setInvalidStatusWithDetail(EDATypes.STATUS_WARMUP, remainingSeconds.toString() + msgWarmupValidSuffix);
            endDeferredRenderCacheRefresh();
            return;
        }

        markWarmupCompleted();

        var driftPercent = getDriftEngine().computeDrift(driftActiveMs);
        if (driftPercent == null) {
            setCollectingStatus();
            endDeferredRenderCacheRefresh();
            return;
        }

        if (isInvalidDriftValue(driftPercent)) {
            writeInvalidRecord();
            endDeferredRenderCacheRefresh();
            return;
        }

        updateDriftDisplay(driftPercent);
        if (isProfileProvisional()) {
            statusDetail = msgProvisionalProfile;
            statusDetailShort = msgProvisionalProfileShort;
            requestRenderCacheRefresh();
        }
        updateFitFields(driftPercent, driftDeltaMs);
        endDeferredRenderCacheRefresh();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (!areStringsLoaded) {
            loadStrings();
            loadSettings();
        }

        requestRenderCacheRefresh();
    }

    (:high_mem)
    function onUpdate(dc as Graphics.Dc) as Void {
        flushRenderCacheRefresh();
        getRenderer().drawHighMem(dc, buildHighMemRenderModel());
    }

    (:low_mem)
    function onUpdate(dc as Graphics.Dc) as Void {
        flushRenderCacheRefresh();
        getRenderer().drawLowMem(dc, buildLowMemRenderModel());
    }
}
