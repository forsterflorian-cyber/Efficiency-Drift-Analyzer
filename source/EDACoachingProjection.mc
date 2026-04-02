import Toybox.Lang;

module EDACoachingProjection {

    const ACTION_OK as Number = 0;
    const ACTION_WATCH as Number = 1;
    const ACTION_EASIER as Number = 2;

    const TREND_UNKNOWN as Number = -1;
    const TREND_STABLE as Number = 0;
    const TREND_RISING as Number = 1;
    const TREND_FALLING as Number = 2;

    const CONFIDENCE_LOW as Number = 0;
    const CONFIDENCE_MEDIUM as Number = 1;
    const CONFIDENCE_HIGH as Number = 2;

    function getAction(driftPercent as Float) as Number {
        if (driftPercent < 3.0) {
            return ACTION_OK;
        }

        if (driftPercent < 6.0) {
            return ACTION_WATCH;
        }

        return ACTION_EASIER;
    }

    function classifyTrendDelta(delta as Float?, threshold as Float) as Number {
        if (delta == null) {
            return TREND_UNKNOWN;
        }

        var driftDelta = delta as Float;
        if (driftDelta > threshold) {
            return TREND_RISING;
        }

        if (driftDelta < -threshold) {
            return TREND_FALLING;
        }

        return TREND_STABLE;
    }

    function getConfidence(msSinceWarmupEnd as Number) as Number {
        if (msSinceWarmupEnd < 90000) {
            return CONFIDENCE_LOW;
        }

        if (msSinceWarmupEnd < 180000) {
            return CONFIDENCE_MEDIUM;
        }

        return CONFIDENCE_HIGH;
    }

    function shouldShowTrend(confidence as Number, trend as Number) as Boolean {
        return confidence != CONFIDENCE_LOW && trend != TREND_UNKNOWN;
    }
}
