import Toybox.Lang;

// ============================================================================
// EDAFeatureFlags
// ============================================================================
// Verantwortlich für:
// - Feature-Flags für experimentelle Features
// - Rollout-Steuerung
// - Konfiguration-as-Code
//
// Ermöglicht:
// - Sicheres Testen neuer Features
// - Graduelle Rollouts
// - A/B Testing ohne Code-Änderungen
// ============================================================================

module EDAFeatureFlags {

    // --------------------------------------------------------------------------
    // Feature: Cycling Speed Fallback
    // Status: Experimental
    // Owner: TBD
    // Rollout: 0% (disabled)
    // Beschreibung: Ermöglicht Speed-basierte Drift-Analyse für Cycling
    // --------------------------------------------------------------------------
    const ENABLE_CYCLING_SPEED_FALLBACK as Boolean = false;

    // --------------------------------------------------------------------------
    // Feature: Drift Clamping at 50%
    // Status: Stable
    // Owner: Core
    // Rollout: 100%
    // Beschreibung: Beschränkt Drift auf ±50% für extreme Szenarien
    // --------------------------------------------------------------------------
    const ENABLE_DRIFT_CLAMPING as Boolean = true;

    // --------------------------------------------------------------------------
    // Feature: Status History
    // Status: Beta
    // Owner: UX
    // Rollout: 50%
    // Beschreibung: Speichert letzte 5 Status-Transitions für Debugging
    // --------------------------------------------------------------------------
    const ENABLE_STATUS_HISTORY as Boolean = false;

    // --------------------------------------------------------------------------
    // Feature: Warmup Progress Indicator
    // Status: Beta
    // Owner: UX
    // Rollout: 50%
    // Beschreibung: Zeigt Fortschrittsbalken während 3min Warmup
    // --------------------------------------------------------------------------
    const ENABLE_WARMUP_PROGRESS as Boolean = false;

    // --------------------------------------------------------------------------
    // Feature: FIT Export bei Fallback nach 60s
    // Status: Experimental
    // Owner: Core
    // Rollout: 0% (disabled)
    // Beschreibung: Exportiert FIT-Daten bereits nach 60s statt 120s
    // --------------------------------------------------------------------------
    const ENABLE_EARLY_FALLBACK_EXPORT as Boolean = false;

    // --------------------------------------------------------------------------
    // Feature: Logging
    // Status: Stable
    // Owner: Core
    // Rollout: 100%
    // Beschreibung: Aktiviert detailliertes Logging für Debugging
    // --------------------------------------------------------------------------
    const ENABLE_DEBUG_LOGGING as Boolean = false;

    // --------------------------------------------------------------------------
    // Feature: EWMA Filter Tuning
    // Status: Experimental
    // Owner: Core
    // Rollout: 0% (disabled)
    // Beschreibung: Ermöglicht dynamische Anpassung der EWMA-Tau-Werte
    // --------------------------------------------------------------------------
    const ENABLE_DYNAMIC_EWMA_TUNING as Boolean = false;

    // --------------------------------------------------------------------------
    // Helper Functions
    // --------------------------------------------------------------------------

    function isCyclingSpeedFallbackEnabled() as Boolean {
        return ENABLE_CYCLING_SPEED_FALLBACK;
    }

    function isDriftClampingEnabled() as Boolean {
        return ENABLE_DRIFT_CLAMPING;
    }

    function isStatusHistoryEnabled() as Boolean {
        return ENABLE_STATUS_HISTORY;
    }

    function isWarmupProgressEnabled() as Boolean {
        return ENABLE_WARMUP_PROGRESS;
    }

    function isEarlyFallbackExportEnabled() as Boolean {
        return ENABLE_EARLY_FALLBACK_EXPORT;
    }

    function isDebugLoggingEnabled() as Boolean {
        return ENABLE_DEBUG_LOGGING;
    }

    function isDynamicEwmaTuningEnabled() as Boolean {
        return ENABLE_DYNAMIC_EWMA_TUNING;
    }

    // --------------------------------------------------------------------------
    // Configuration-as-Code
    // --------------------------------------------------------------------------

    // Alle tunierbaren Parameter zentral definiert
    // Änderungen hier erfordern keinen Code-Änderungen in anderen Modulen

    function getMinValidPower() as Float {
        return 30.0;
    }

    function getMaxValidPower() as Float {
        return 700.0;
    }

    function getMaxSpeedMs() as Float {
        return 12.0;
    }

    function getMaxRunningPacePerKm() as Float {
        return 480.0;
    }

    function getHrJumpPerSec() as Float {
        return 20.0;
    }

    function getSpeedJumpPerSec() as Float {
        return 4.0;
    }

    function getWarmupValidMs() as Number {
        return 180000;
    }

    function getMaxValidSampleGapMs() as Number {
        return 5000;
    }

    function getMaxDataDrivenGapMs() as Number {
        return 20000;
    }

    function getMaxResumeGapResetMs() as Number {
        return 300000;
    }

    function getDataDrivenGapMs() as Number {
        return getMaxDataDrivenGapMs();
    }

    function getFallbackExportTimeoutMs() as Number {
        return ENABLE_EARLY_FALLBACK_EXPORT ? 60000 : 120000;
    }

    function getImplicitTimerResetToleranceMs() as Number {
        return 5000;
    }

    function getSourceSwitchConfirmSamples() as Number {
        return 3;
    }

    function getDriftWindowMs() as Number {
        return 1200000;
    }

    function getDriftBucketCount() as Number {
        return 120;
    }

    // ---------------------------------------------------------------------------
    // Workload Validation Constants (Single Source of Truth)
    // ---------------------------------------------------------------------------

    function getCalibrationDistanceFactor() as Float {
        return 1000.0;
    }
}
