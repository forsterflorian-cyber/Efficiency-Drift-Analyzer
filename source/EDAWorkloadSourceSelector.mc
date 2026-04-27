import Toybox.Lang;

// ============================================================================
// EDAWorkloadSourceSelector
// ============================================================================
// Verantwortlich für:
// - Source Selection (Power vs Speed/Pace)
// - Workload Validation (Power, Speed)
// - Workload Metric Extraction
//
// Extracted from EDAView to keep validation and source-choice rules isolated.
// ============================================================================

class EDAWorkloadSourceSelector {

    // Konstanten werden aus EDAFeatureFlags bezogen (Single Source of Truth)
    // MIN_VALID_POWER → EDAFeatureFlags.getMinValidPower()
    // MAX_VALID_POWER → EDAFeatureFlags.getMaxValidPower()
    // MAX_SPEED_MS → EDAFeatureFlags.getMaxSpeedMs()
    // MAX_RUNNING_PACE_PER_KM → EDAFeatureFlags.getMaxRunningPacePerKm()
    private var mIsRunningProfile as Boolean = false;

    function initialize() {
        mIsRunningProfile = false;
    }

    function updateProfile(isRunningProfile as Boolean) as Void {
        mIsRunningProfile = isRunningProfile;
    }

    // --------------------------------------------------------------------------
    // Power Validation
    // --------------------------------------------------------------------------

    function hasUsablePower(power as Float?) as Boolean {
        if (power == null) {
            return false;
        }

        return power >= EDAFeatureFlags.getMinValidPower() && power <= EDAFeatureFlags.getMaxValidPower();
    }

    function getPowerValidationError(power as Float?) as Number? {
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

    // --------------------------------------------------------------------------
    // Speed Validation
    // --------------------------------------------------------------------------

    function canUseSpeedWorkload() as Boolean {
        return mIsRunningProfile;
    }

    function pacePerKmSeconds(speed as Float?) as Float? {
        if (speed == null || speed <= 0.0) {
            return null;
        }

        return EDAFeatureFlags.getCalibrationDistanceFactor() / speed;
    }

    function hasUsableSpeedWorkload(speed as Float?) as Boolean {
        if (!canUseSpeedWorkload()) {
            return false;
        }

        if (speed == null || speed > EDAFeatureFlags.getMaxSpeedMs()) {
            return false;
        }

        var runPace = pacePerKmSeconds(speed);
        return runPace != null && runPace <= EDAFeatureFlags.getMaxRunningPacePerKm();
    }

    function getSpeedValidationError(speed as Float?, isSpeedOutlier as Boolean) as Number? {
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

        if (isSpeedOutlier) {
            return EDATypes.STATUS_INVALID_SPEED;
        }

        return null;
    }

    // --------------------------------------------------------------------------
    // Workload Validation
    // --------------------------------------------------------------------------

    function getWorkloadValidationError(speedError as Number?, power as Float?) as Number? {
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

        return speedError;
    }

    // --------------------------------------------------------------------------
    // Source Selection
    // --------------------------------------------------------------------------

    function determinePreferredWorkloadSource(speed as Float?, power as Float?) as Number {
        if (hasUsablePower(power)) {
            return EDATypes.SOURCE_POWER;
        }

        if (hasUsableSpeedWorkload(speed)) {
            return EDATypes.SOURCE_SPEED;
        }

        return EDATypes.SOURCE_NONE;
    }

    function determineWorkloadSource(speed as Float?, power as Float?) as Number {
        return determinePreferredWorkloadSource(speed, power);
    }

    function getWorkloadMetricForSource(workloadSource as Number, speed as Float?, power as Float?) as Float? {
        if (workloadSource == EDATypes.SOURCE_POWER && power != null && hasUsablePower(power)) {
            return power;
        }

        if (workloadSource == EDATypes.SOURCE_SPEED && speed != null && hasUsableSpeedWorkload(speed)) {
            return speed;
        }

        return null;
    }
}
