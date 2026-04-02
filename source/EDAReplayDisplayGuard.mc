import Toybox.Lang;

module EDAReplayDisplayGuard {

    const KMH_TO_MS as Float = 3.6;
    const MIN_SUSPICIOUS_PACE_PER_KM_SECONDS as Float = 150.0;
    const MIN_VALID_DISPLAY_SPEED_MS as Float = 0.2;
    const MAX_ABSURD_EXPECTED_HR as Float = 260.0;

    function normalizeDisplaySpeed(
        rawSpeed as Float?,
        isRunningProfile as Boolean,
        workloadSource as Number,
        modelAvailable as Boolean,
        slope as Float,
        intercept as Float
    ) as Float? {
        if (!shouldNormalizeDisplaySpeed(rawSpeed, isRunningProfile, workloadSource, modelAvailable, slope, intercept)) {
            return rawSpeed;
        }

        return (rawSpeed as Float) / KMH_TO_MS;
    }

    function shouldNormalizeDisplaySpeed(
        rawSpeed as Float?,
        isRunningProfile as Boolean,
        workloadSource as Number,
        modelAvailable as Boolean,
        slope as Float,
        intercept as Float
    ) as Boolean {
        if (rawSpeed == null || rawSpeed <= MIN_VALID_DISPLAY_SPEED_MS) {
            return false;
        }

        if (!isRunningProfile || workloadSource != EDATypes.SOURCE_POWER || !modelAvailable) {
            return false;
        }

        if (slope.abs() <= 0.0001) {
            return false;
        }

        var rawPacePerKmSeconds = EDAFeatureFlags.getCalibrationDistanceFactor() / (rawSpeed as Float);
        if (rawPacePerKmSeconds >= MIN_SUSPICIOUS_PACE_PER_KM_SECONDS) {
            return false;
        }

        var normalizedSpeed = (rawSpeed as Float) / KMH_TO_MS;
        if (normalizedSpeed <= MIN_VALID_DISPLAY_SPEED_MS) {
            return false;
        }

        var normalizedPacePerKmSeconds = EDAFeatureFlags.getCalibrationDistanceFactor() / normalizedSpeed;
        if (normalizedPacePerKmSeconds < MIN_SUSPICIOUS_PACE_PER_KM_SECONDS) {
            return false;
        }

        if (normalizedPacePerKmSeconds > EDAFeatureFlags.getMaxRunningPacePerKm()) {
            return false;
        }

        var rawExpectedHr = (slope * (rawSpeed as Float)) + intercept;
        return rawExpectedHr > MAX_ABSURD_EXPECTED_HR;
    }
}
