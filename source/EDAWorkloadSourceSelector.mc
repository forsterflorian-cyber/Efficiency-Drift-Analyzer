import Toybox.Lang;

// ============================================================================
// EDAWorkloadSourceSelector
// ============================================================================
// Verantwortlich für:
// - Source Selection (Power vs Speed/Pace)
// - Source Switch Confirmation (3-Sample-Hysteresis)
// - Workload Validation (Power, Speed)
// - Workload Metric Extraction
//
// Extrahiert aus EDAView (~300 Zeilen reduziert)
// ============================================================================

class EDAWorkloadSourceSelector {

    // Konstanten werden aus EDAFeatureFlags bezogen (Single Source of Truth)
    // MIN_VALID_POWER → EDAFeatureFlags.getMinValidPower()
    // MAX_VALID_POWER → EDAFeatureFlags.getMaxValidPower()
    // MAX_SPEED_MS → EDAFeatureFlags.getMaxSpeedMs()
    // MAX_RUNNING_PACE_PER_KM → EDAFeatureFlags.getMaxRunningPacePerKm()
    // CALIBRATION_DISTANCE_FACTOR → EDAFeatureFlags.getCalibrationDistanceFactor()

    private var mCurrentWorkloadSource as Number = EDATypes.SOURCE_NONE;
    private var mPendingWorkloadSource as Number = EDATypes.SOURCE_NONE;
    private var mPendingWorkloadSourceSamples as Number = 0;
    private var mDistanceFactor as Float = 1000.0;
    private var mIsRunningProfile as Boolean = false;

    function initialize() {
        mCurrentWorkloadSource = EDATypes.SOURCE_NONE;
        mPendingWorkloadSource = EDATypes.SOURCE_NONE;
        mPendingWorkloadSourceSamples = 0;
        mDistanceFactor = 1000.0;
        mIsRunningProfile = false;
    }

    function reset() as Void {
        mCurrentWorkloadSource = EDATypes.SOURCE_NONE;
        mPendingWorkloadSource = EDATypes.SOURCE_NONE;
        mPendingWorkloadSourceSamples = 0;
    }

    function updateDistanceFactor(distanceFactor as Float) as Void {
        mDistanceFactor = distanceFactor;
    }

    function updateProfile(isRunningProfile as Boolean) as Void {
        mIsRunningProfile = isRunningProfile;
    }

    function isRunningProfile() as Boolean {
        return mIsRunningProfile;
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
            return 10; // STATUS_LOW_POWER
        }

        if (power > EDAFeatureFlags.getMaxValidPower()) {
            return 9; // STATUS_SPIKE
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

    function getSpeedValidationError(speed as Float?, timerTime as Number, isSpeedOutlier as Boolean) as Number? {
        if (!canUseSpeedWorkload()) {
            return null;
        }

        if (speed == null) {
            return 13; // STATUS_NO_SPEED
        }

        if (speed <= 0.0) {
            return 11; // STATUS_LOW_PACE
        }

        if (speed > EDAFeatureFlags.getMaxSpeedMs()) {
            return 14; // STATUS_INVALID_SPEED
        }

        var runPace = pacePerKmSeconds(speed);
        if (runPace == null) {
            return 14; // STATUS_INVALID_SPEED
        }

        if (runPace > EDAFeatureFlags.getMaxRunningPacePerKm()) {
            return 11; // STATUS_LOW_PACE
        }

        if (isSpeedOutlier) {
            return 14; // STATUS_INVALID_SPEED
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

            return 12; // STATUS_NO_POWER
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

        return 12; // STATUS_NO_POWER
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

    function isWorkloadSourceUsable(workloadSource as Number, speed as Float?, power as Float?) as Boolean {
        if (workloadSource == EDATypes.SOURCE_POWER) {
            return hasUsablePower(power);
        }

        if (workloadSource == EDATypes.SOURCE_SPEED) {
            return hasUsableSpeedWorkload(speed);
        }

        return false;
    }

    function determineWorkloadSource(speed as Float?, power as Float?) as Number {
        // Keep using the current source while it remains valid to avoid
        // oscillating between equally usable sensors.
        if (mCurrentWorkloadSource != EDATypes.SOURCE_NONE && isWorkloadSourceUsable(mCurrentWorkloadSource, speed, power)) {
            return mCurrentWorkloadSource;
        }

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

    // --------------------------------------------------------------------------
    // Source Switch Confirmation (3-Sample-Hysteresis)
    // --------------------------------------------------------------------------

    function validateSourceConsistency(timerTime as Number, speed as Float?, hr as Float, workloadSource as Number, deltaMs as Number, maxValidSampleGapMs as Number) as Boolean {
        if (deltaMs > maxValidSampleGapMs) {
            clearPendingWorkloadSourceSwitch();
            return false;
        }

        if (mCurrentWorkloadSource == EDATypes.SOURCE_NONE || workloadSource == mCurrentWorkloadSource) {
            clearPendingWorkloadSourceSwitch();
            return true;
        }

        if (mPendingWorkloadSource != workloadSource) {
            mPendingWorkloadSource = workloadSource;
            mPendingWorkloadSourceSamples = 1;
        } else {
            mPendingWorkloadSourceSamples += 1;
        }

        if (mPendingWorkloadSourceSamples < EDAFeatureFlags.getSourceSwitchConfirmSamples()) {
            return false;
        }

        clearPendingWorkloadSourceSwitch();
        return false;
    }

    function confirmSourceSwitch() as Void {
        mCurrentWorkloadSource = mPendingWorkloadSource;
        clearPendingWorkloadSourceSwitch();
    }

    function getCurrentWorkloadSource() as Number {
        return mCurrentWorkloadSource;
    }

    function setCurrentWorkloadSource(source as Number) as Void {
        mCurrentWorkloadSource = source;
    }

    function getPendingWorkloadSource() as Number {
        return mPendingWorkloadSource;
    }

    function getPendingWorkloadSourceSamples() as Number {
        return mPendingWorkloadSourceSamples;
    }

    private function clearPendingWorkloadSourceSwitch() as Void {
        mPendingWorkloadSource = EDATypes.SOURCE_NONE;
        mPendingWorkloadSourceSamples = 0;
    }
}