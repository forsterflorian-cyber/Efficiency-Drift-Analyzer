import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Math;

class EDAFitExportState {

    private const SOURCE_POWER as Number = 1;
    private const SOURCE_SPEED as Number = 2;

    private var mDriftField as Toybox.FitContributor.Field?;
    private var mAvgDriftField as Toybox.FitContributor.Field?;
    private var mProfileStateField as Toybox.FitContributor.Field?;

    private var mSessionPowerDriftWeightedSum as Float = 0.0;
    private var mSessionPowerDriftMs as Number = 0;
    private var mSessionSpeedDriftWeightedSum as Float = 0.0;
    private var mSessionSpeedDriftMs as Number = 0;

    function initialize(
        driftField as Toybox.FitContributor.Field?,
        avgDriftField as Toybox.FitContributor.Field?,
        profileStateField as Toybox.FitContributor.Field?
    ) {
        mDriftField = driftField;
        mAvgDriftField = avgDriftField;
        mProfileStateField = profileStateField;
    }

    private function getInvalidFitFloat() as Float {
        // FIT float developer fields use NaN as the protocol-level invalid sentinel.
        return Math.sqrt(-1.0);
    }

    private function clearRealtimeDriftField() as Void {
        if (mDriftField != null) {
            mDriftField.setData(getInvalidFitFloat());
        }
    }

    private function updateProfileStateField(profileState as Number) as Void {
        if (mProfileStateField != null) {
            mProfileStateField.setData(profileState);
        }
    }

    private function addSessionDriftSample(driftPercent as Float, intervalMs as Number, workloadSource as Number) as Void {
        if (intervalMs <= 0) {
            return;
        }

        if (workloadSource == SOURCE_POWER) {
            mSessionPowerDriftWeightedSum += driftPercent * intervalMs.toFloat();
            mSessionPowerDriftMs += intervalMs;
        } else if (workloadSource == SOURCE_SPEED) {
            mSessionSpeedDriftWeightedSum += driftPercent * intervalMs.toFloat();
            mSessionSpeedDriftMs += intervalMs;
        }
    }

    private function getSessionAverageDrift() as Float? {
        var totalDriftMs = mSessionPowerDriftMs + mSessionSpeedDriftMs;
        if (totalDriftMs <= 0) {
            return null;
        }

        var weightedDrift = mSessionPowerDriftWeightedSum + mSessionSpeedDriftWeightedSum;
        return weightedDrift / totalDriftMs.toFloat();
    }

    private function clearSessionSummaryField() as Void {
        if (mAvgDriftField != null) {
            mAvgDriftField.setData(getInvalidFitFloat());
        }
    }

    private function updateSessionSummaryField() as Void {
        var sessionAverageDrift = getSessionAverageDrift();
        if (mAvgDriftField != null && sessionAverageDrift != null) {
            mAvgDriftField.setData(sessionAverageDrift);
            return;
        }

        clearSessionSummaryField();
    }

    function writeInvalidRecord(profileState as Number) as Void {
        updateProfileStateField(profileState);
        clearRealtimeDriftField();
    }

    function updateFitFields(profileState as Number, canExport as Boolean, driftPercent as Float, intervalMs as Number, workloadSource as Number) as Void {
        updateProfileStateField(profileState);
        addSessionDriftSample(driftPercent, intervalMs, workloadSource);
        updateSessionSummaryField();

        if (!canExport) {
            clearRealtimeDriftField();
            return;
        }

        if (mDriftField != null) {
            mDriftField.setData(driftPercent);
        }
    }

    function resetSessionFitSummary() as Void {
        mSessionPowerDriftWeightedSum = 0.0;
        mSessionPowerDriftMs = 0;
        mSessionSpeedDriftWeightedSum = 0.0;
        mSessionSpeedDriftMs = 0;
        clearSessionSummaryField();
    }

    function getSessionAverageDriftForDiagnostics() as Float? {
        return getSessionAverageDrift();
    }
}
