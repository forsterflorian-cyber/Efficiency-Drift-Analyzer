import Toybox.Activity;
import Toybox.Lang;

class EDAProfileResolver {

    private const PROFILE_STATE_UNRESOLVED as Number = 0;
    private const PROFILE_STATE_PROVISIONAL as Number = 1;
    private const PROFILE_STATE_FALLBACK_CONFIRMED as Number = 2;
    private const PROFILE_STATE_AUTHORITATIVE as Number = 3;
    private const PROFILE_STATE_STALE as Number = 4;

    private const ACTIVITY_UNKNOWN as Number = 0;
    private const ACTIVITY_RUNNING as Number = 1;
    private const ACTIVITY_OTHER as Number = 2;

    private const PROFILE_RESOLVE_TIMEOUT_MS as Number = 30000;
    private const PROFILE_CONFIRM_TIMEOUT_MS as Number = 60000;
    private const PROFILE_EXCEPTION_RETRY_BASE_MS as Number = 5000;
    private const PROFILE_EXCEPTION_RETRY_MAX_MS as Number = 30000;
    private const PROFILE_AUTHORITATIVE_REVALIDATE_MS as Number = 15000;
    private const PROFILE_REVALIDATION_LOSS_THRESHOLD as Number = 3;
    private const PROFILE_STALE_RECOVERY_MS as Number = 120000;

    private var mState as Number = PROFILE_STATE_UNRESOLVED;
    private var mRetryPending as Boolean = false;
    private var mNextRetryTime as Number = 0;
    private var mExceptionBackoffMs as Number = PROFILE_EXCEPTION_RETRY_BASE_MS;
    private var mLastErrorCode as String = "";
    private var mActivityKind as Number = ACTIVITY_UNKNOWN;
    private var mTimeoutNoticePending as Boolean = false;
    private var mNextAuthoritativeRefreshTime as Number = 0;
    private var mRevalidationLossCount as Number = 0;
    private var mStaleSinceTime as Number = 0;

    function hasUsableActivityProfile() as Boolean {
        return mState == PROFILE_STATE_PROVISIONAL
            || mState == PROFILE_STATE_FALLBACK_CONFIRMED
            || mState == PROFILE_STATE_AUTHORITATIVE
            || (mState == PROFILE_STATE_STALE && mActivityKind != ACTIVITY_UNKNOWN);
    }

    function isProfileProvisional() as Boolean {
        return mState == PROFILE_STATE_PROVISIONAL;
    }

    function hasAuthoritativeProfile() as Boolean {
        return mState == PROFILE_STATE_AUTHORITATIVE;
    }

    function isFallbackConfirmed() as Boolean {
        return mState == PROFILE_STATE_FALLBACK_CONFIRMED;
    }

    function isRunningActivity() as Boolean {
        return hasUsableActivityProfile() && mActivityKind == ACTIVITY_RUNNING;
    }

    function isRetryPending() as Boolean {
        return mRetryPending;
    }

    function getLastErrorCode() as String {
        return mLastErrorCode;
    }

    function getState() as Number {
        return mState;
    }

    function hasTimeoutNoticePending() as Boolean {
        return mTimeoutNoticePending;
    }

    function clearTimeoutNoticePending() as Void {
        mTimeoutNoticePending = false;
    }

    function forceStaleStateForDiagnostics(isRunning as Boolean, staleSinceTime as Number, nextRetryTime as Number) as Void {
        mState = PROFILE_STATE_STALE;
        mActivityKind = isRunning ? ACTIVITY_RUNNING : ACTIVITY_OTHER;
        mRetryPending = true;
        mNextRetryTime = nextRetryTime;
        mTimeoutNoticePending = false;
        mNextAuthoritativeRefreshTime = 0;
        mStaleSinceTime = staleSinceTime;
    }

    function resetSession() as Void {
        mState = PROFILE_STATE_UNRESOLVED;
        mActivityKind = ACTIVITY_UNKNOWN;
        mTimeoutNoticePending = false;
        mNextAuthoritativeRefreshTime = 0;
        mStaleSinceTime = 0;
        clearRetryState();
    }

    function handleImplicitSessionReset() as Void {
        resetSession();
    }

    private function clearRetryState() as Void {
        mRetryPending = false;
        mNextRetryTime = 0;
        mExceptionBackoffMs = PROFILE_EXCEPTION_RETRY_BASE_MS;
        mLastErrorCode = "";
        mRevalidationLossCount = 0;
    }

    private function getProfileErrorCode(error as Lang.Object) as String {
        var errorCode = error.toString();
        if (errorCode == "") {
            return "exception";
        }

        return errorCode;
    }

    private function scheduleExceptionRetry(timerTime as Number, errorCode as String, keepAuthoritative as Boolean) as Void {
        if (errorCode != "" && errorCode == mLastErrorCode) {
            mExceptionBackoffMs *= 2;
            if (mExceptionBackoffMs > PROFILE_EXCEPTION_RETRY_MAX_MS) {
                mExceptionBackoffMs = PROFILE_EXCEPTION_RETRY_MAX_MS;
            }
        } else {
            mExceptionBackoffMs = PROFILE_EXCEPTION_RETRY_BASE_MS;
        }

        if (keepAuthoritative) {
            mNextAuthoritativeRefreshTime = timerTime + mExceptionBackoffMs;
        } else {
            mRetryPending = true;
            mNextRetryTime = timerTime + mExceptionBackoffMs;
        }

        mLastErrorCode = errorCode;
    }

    private function getResolvedActivityKind(resolvedRunning as Boolean) as Number {
        if (resolvedRunning) {
            return ACTIVITY_RUNNING;
        }

        return ACTIVITY_OTHER;
    }

    private function applyAuthoritativeActivityProfile(resolvedRunning as Boolean, timerTime as Number) as Boolean {
        var resolvedActivityKind = getResolvedActivityKind(resolvedRunning);
        var profileChanged = ((mState != PROFILE_STATE_UNRESOLVED) && (mState != PROFILE_STATE_AUTHORITATIVE))
            || (hasUsableActivityProfile() && (mActivityKind != resolvedActivityKind));
        mActivityKind = resolvedActivityKind;
        mState = PROFILE_STATE_AUTHORITATIVE;
        mTimeoutNoticePending = false;
        mStaleSinceTime = 0;
        clearRetryState();
        mNextAuthoritativeRefreshTime = timerTime + PROFILE_AUTHORITATIVE_REVALIDATE_MS;
        return profileChanged;
    }

    private function promoteStaleProfileToFallback(timerTime as Number) as Boolean {
        if (mState != PROFILE_STATE_STALE || mActivityKind == ACTIVITY_UNKNOWN || mStaleSinceTime <= 0) {
            return false;
        }

        if ((timerTime - mStaleSinceTime) < PROFILE_STALE_RECOVERY_MS) {
            return false;
        }

        mState = PROFILE_STATE_FALLBACK_CONFIRMED;
        mTimeoutNoticePending = true;
        mStaleSinceTime = 0;
        return true;
    }

    private function updateFallbackProfileState(timerTime as Number) as Void {
        if (mState != PROFILE_STATE_FALLBACK_CONFIRMED
            && mState != PROFILE_STATE_AUTHORITATIVE
            && mState != PROFILE_STATE_STALE
            && timerTime >= PROFILE_CONFIRM_TIMEOUT_MS) {
            mState = PROFILE_STATE_FALLBACK_CONFIRMED;
            mTimeoutNoticePending = true;
        } else if (mState == PROFILE_STATE_UNRESOLVED && timerTime >= PROFILE_RESOLVE_TIMEOUT_MS) {
            mState = PROFILE_STATE_PROVISIONAL;
        }
    }

    private function handleAuthoritativeRevalidationFailure(timerTime as Number, errorCode as String) as Boolean {
        mRevalidationLossCount += 1;
        if (mRevalidationLossCount < PROFILE_REVALIDATION_LOSS_THRESHOLD) {
            scheduleExceptionRetry(timerTime, errorCode, true);
            return false;
        }

        scheduleExceptionRetry(timerTime, errorCode, false);
        mState = PROFILE_STATE_STALE;
        mTimeoutNoticePending = false;
        mNextAuthoritativeRefreshTime = 0;
        mStaleSinceTime = timerTime;
        return true;
    }

    private function revalidateAuthoritativeProfile(timerTime as Number) as Boolean {
        try {
            var profileInfo = Activity.getProfileInfo();
            return applyAuthoritativeActivityProfile(profileInfo.sport == Activity.SPORT_RUNNING, timerTime);
        } catch (e) {
            return handleAuthoritativeRevalidationFailure(timerTime, getProfileErrorCode(e));
        }
    }

    function resolveActivityProfile(timerTime as Number) as Boolean {
        if (promoteStaleProfileToFallback(timerTime)) {
            return false;
        }

        if (hasAuthoritativeProfile()) {
            if (timerTime < mNextAuthoritativeRefreshTime) {
                return false;
            }

            return revalidateAuthoritativeProfile(timerTime);
        }

        if (mRetryPending && timerTime < mNextRetryTime) {
            if (!promoteStaleProfileToFallback(timerTime)) {
                updateFallbackProfileState(timerTime);
            }
            return false;
        }

        try {
            var profileInfo = Activity.getProfileInfo();
            return applyAuthoritativeActivityProfile(profileInfo.sport == Activity.SPORT_RUNNING, timerTime);
        } catch (e) {
            scheduleExceptionRetry(timerTime, getProfileErrorCode(e), false);
        }

        if (!promoteStaleProfileToFallback(timerTime)) {
            updateFallbackProfileState(timerTime);
        }
        return false;
    }
}
