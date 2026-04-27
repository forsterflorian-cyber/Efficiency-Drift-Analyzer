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
    // Feature: FIT Export bei Fallback nach 60s
    // Status: Experimental
    // Owner: Core
    // Rollout: 0% (disabled)
    // Beschreibung: Exportiert FIT-Daten bereits nach 60s statt 120s
    // --------------------------------------------------------------------------
    const ENABLE_EARLY_FALLBACK_EXPORT as Boolean = false;

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

    function getMaxResumeGapResetMs() as Number {
        return 300000;
    }

    function getDataDrivenGapMs() as Number {
        return 20000;
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
