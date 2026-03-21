import Toybox.Lang;
import Toybox.System;

// ============================================================================
// EDALifecycleManager
// ============================================================================
// Verantwortlich für:
// - Pause/Resume Timestamp Management
// - Resume Gap Detection
// - Lifecycle State Management
//
// Extrahiert aus EDAView (~100 Zeilen reduziert)
// ============================================================================

class EDALifecycleManager {

    private const MAX_RESUME_GAP_RESET_MS as Number = 300000;
    private const IMPLICIT_TIMER_RESET_TOLERANCE_MS as Number = 5000;

    private var mLastPauseSystemTimer as Number? = null;
    private var mLastActiveTimerTime as Number? = null;

    function initialize() {
        mLastPauseSystemTimer = null;
        mLastActiveTimerTime = null;
    }

    function reset() as Void {
        mLastPauseSystemTimer = null;
        mLastActiveTimerTime = null;
    }

    // --------------------------------------------------------------------------
    // Pause Management
    // --------------------------------------------------------------------------

    function rememberPauseTimestamp() as Void {
        if (mLastPauseSystemTimer == null) {
            mLastPauseSystemTimer = System.getTimer();
        }
    }

    function clearLifecyclePauseState() as Void {
        mLastPauseSystemTimer = null;
    }

    function getPauseTimestamp() as Number? {
        return mLastPauseSystemTimer;
    }

    // --------------------------------------------------------------------------
    // Resume Management
    // --------------------------------------------------------------------------

    function shouldResetAfterResumePause() as Boolean {
        var pausedAt = mLastPauseSystemTimer;
        mLastPauseSystemTimer = null;
        if (pausedAt == null) {
            return false;
        }

        var currentSystemTimer = System.getTimer();
        if (currentSystemTimer < pausedAt) {
            return true;
        }

        return (currentSystemTimer - pausedAt) >= MAX_RESUME_GAP_RESET_MS;
    }

    // --------------------------------------------------------------------------
    // Timer Management
    // --------------------------------------------------------------------------

    function getLastActiveTimerTime() as Number? {
        return mLastActiveTimerTime;
    }

    function setLastActiveTimerTime(timerTime as Number) as Void {
        mLastActiveTimerTime = timerTime;
    }

    function clearLastActiveTimerTime() as Void {
        mLastActiveTimerTime = null;
    }

    function getSampleDelta(timerTime as Number) as Number {
        var previous = mLastActiveTimerTime;
        if (previous == null) {
            mLastActiveTimerTime = timerTime;
            return 0;
        }

        if (timerTime <= previous) {
            return 0;
        }

        mLastActiveTimerTime = timerTime;
        return timerTime - previous;
    }

    function shouldTriggerImplicitReset(currentTimerTime as Number) as Boolean {
        var previousTimerTime = mLastActiveTimerTime;
        if (previousTimerTime == null) {
            return false;
        }

        if (currentTimerTime >= previousTimerTime) {
            return false;
        }

        var rollbackMs = previousTimerTime - currentTimerTime;
        return rollbackMs > IMPLICIT_TIMER_RESET_TOLERANCE_MS;
    }
}