import Toybox.Lang;
import Toybox.Math;

class EDADriftEngine {

    private const MIN_VALID_TIME_MS as Number = 180000;
    private const MAX_DRIFT_PERCENT as Float = 50.0;
    private const SPLIT_BUCKET_MS as Number = 10000;
    private const MAX_VALID_SAMPLE_GAP_MS as Number = 5000;
    private const DRIFT_WINDOW_MS as Number = 1200000;
    private const DRIFT_BUCKET_COUNT as Number = 120;

    private var mDriftWeightedBuckets as Array<Float> = [];
    private var mDriftValidBuckets as Array<Number> = [];
    private var mDriftBucketKeys as Array<Number> = [];
    private var mIsCalibrated as Boolean = true;

    private function initializeDriftBuffers() as Void {
        if (mDriftWeightedBuckets.size() > 0) {
            return;
        }

        for (var i = 0; i < DRIFT_BUCKET_COUNT; i += 1) {
            mDriftWeightedBuckets.add(0.0);
            mDriftValidBuckets.add(0);
            mDriftBucketKeys.add(-1);
        }
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

    function reset() as Void {
        initializeDriftBuffers();

        for (var i = 0; i < DRIFT_BUCKET_COUNT; i += 1) {
            mDriftWeightedBuckets[i] = 0.0;
            mDriftValidBuckets[i] = 0;
            mDriftBucketKeys[i] = -1;
        }
    }

    function setCalibrated(isCalibrated as Boolean) as Void {
        if (mIsCalibrated == isCalibrated) {
            return;
        }

        mIsCalibrated = isCalibrated;
        if (!mIsCalibrated) {
            reset();
        }
    }

    function recordValidSample(driftTimerTime as Number, deltaMs as Number, ef as Float) as Void {
        if (driftTimerTime <= 0 || deltaMs <= 0 || deltaMs > MAX_VALID_SAMPLE_GAP_MS || ef <= 0.0) {
            return;
        }

        initializeDriftBuffers();

        var bucketKey = (driftTimerTime / SPLIT_BUCKET_MS).toNumber();
        var slot = bucketKey % DRIFT_BUCKET_COUNT;
        if ((mDriftBucketKeys[slot] as Number) != bucketKey) {
            mDriftBucketKeys[slot] = bucketKey;
            mDriftWeightedBuckets[slot] = 0.0;
            mDriftValidBuckets[slot] = 0;
        }

        mDriftWeightedBuckets[slot] = (mDriftWeightedBuckets[slot] as Float) + (ef * deltaMs);
        mDriftValidBuckets[slot] = (mDriftValidBuckets[slot] as Number) + deltaMs;
    }

    function computeDrift(driftActiveMs as Number) as Float? {
        if (!mIsCalibrated) {
            return Math.sqrt(-1.0) as Float;
        }

        if (driftActiveMs < MIN_VALID_TIME_MS) {
            return null;
        }

        initializeDriftBuffers();

        var split1Weighted = 0.0;
        var split2Weighted = 0.0;
        var split1Ms = 0;
        var split2Ms = 0;
        var split1SlotCount = 0;
        var split2SlotCount = 0;
        var windowSizeMs = driftActiveMs;
        if (windowSizeMs > DRIFT_WINDOW_MS) {
            windowSizeMs = DRIFT_WINDOW_MS;
        }
        var windowStart = driftActiveMs - windowSizeMs;
        var windowMid = windowStart + ((windowSizeMs / 2).toNumber());

        for (var i = 0; i < DRIFT_BUCKET_COUNT; i += 1) {
            var bucketKey = mDriftBucketKeys[i] as Number;
            if (bucketKey < 0) {
                continue;
            }

            var bucketStart = bucketKey * SPLIT_BUCKET_MS;
            if (bucketStart < windowStart || bucketStart >= driftActiveMs) {
                continue;
            }

            var bucketWeighted = mDriftWeightedBuckets[i] as Float;
            var bucketMs = mDriftValidBuckets[i] as Number;
            if (bucketMs <= 0) {
                continue;
            }

            if (bucketStart < windowMid) {
                split1Weighted += bucketWeighted;
                split1Ms += bucketMs;
                split1SlotCount += 1;
            } else {
                split2Weighted += bucketWeighted;
                split2Ms += bucketMs;
                split2SlotCount += 1;
            }
        }

        if (split1SlotCount <= 0 || split2SlotCount <= 0 || split1Ms <= 0 || split2Ms <= 0) {
            return null;
        }

        var split1Ef = split1Weighted / split1Ms.toFloat();
        var split2Ef = split2Weighted / split2Ms.toFloat();
        if (split1Ef <= 0.0 || split2Ef <= 0.0) {
            return null;
        }

        return clampDrift(((split1Ef / split2Ef) - 1.0) * 100.0);
    }
}
