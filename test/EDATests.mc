import Toybox.Test;
import Toybox.Lang;

(:test)
function sessionSummaryResetsOnProfileUpgrade(logger as Test.Logger) as Boolean {
    var fitExportState = new EDAFitExportState(null, null, null);

    for (var i = 0; i < 30; i += 1) {
        fitExportState.updateFitFields(1, true, 4.0, 10000, 1);
    }

    var averageBefore = fitExportState.getSessionAverageDriftForDiagnostics();
    Test.assertMessage(averageBefore != null, "Expected 5-minute session summary before reset.");
    Test.assertMessage(
        EDASessionPolicy.shouldResetSessionFitSummaryForProfileChange(80.0, false, false, 85.0, true, true),
        "Profile upgrade should force a session summary reset."
    );

    fitExportState.resetSessionFitSummary();
    logger.debug("avgBefore=" + (averageBefore as Float).format("%.2f"));
    Test.assertMessage(
        fitExportState.getSessionAverageDriftForDiagnostics() == null,
        "Session summary should be cleared after the profile-upgrade reset."
    );
    return true;
}

(:test)
function staleProfileRecoversAfter121Seconds(logger as Test.Logger) as Boolean {
    var resolver = new EDAProfileResolver();
    resolver.forceStaleStateForDiagnostics(true, 1, 999999);

    var profileChanged = resolver.resolveActivityProfile(121001);
    logger.debug("changed=" + profileChanged.toString() + " state=" + resolver.getState().toString());
    Test.assertEqualMessage(2, resolver.getState(), "STALE should recover to FALLBACK_CONFIRMED after 120s.");
    Test.assertMessage(
        resolver.hasTimeoutNoticePending(),
        "Timeout notice should be raised when stale recovery unlocks export."
    );
    return true;
}

(:test)
function driftWeightingPrefersLongerIntervals(logger as Test.Logger) as Boolean {
    var engine = new EDADriftEngine();
    engine.reset();

    engine.recordValidSample(10000, 1000, 2.0);
    engine.recordValidSample(20000, 5000, 1.0);
    engine.recordValidSample(25000, 5000, 1.0);
    engine.recordValidSample(100000, 5000, 1.0);
    engine.recordValidSample(105000, 5000, 1.0);

    var drift = engine.computeDrift(180000);
    Test.assertMessage(drift != null, "Expected weighted drift result after warmup.");

    var actual = drift as Float;
    var expected = 9.0909;
    logger.debug("weightedDrift=" + actual.format("%.4f"));
    Test.assertMessage(
        (actual - expected).abs() < 0.05,
        "Weighted drift should reflect the 1s vs 10s contribution balance."
    );
    return true;
}

(:test)
function mixedSourceSessionSummaryRemainsContinuous(logger as Test.Logger) as Boolean {
    var fitExportState = new EDAFitExportState(null, null, null);

    fitExportState.updateFitFields(3, true, 4.0, 10000, 1);
    fitExportState.updateFitFields(3, true, 6.0, 20000, 2);

    var averageDrift = fitExportState.getSessionAverageDriftForDiagnostics();
    Test.assertMessage(averageDrift != null, "Expected a mixed-source session summary.");

    var actual = averageDrift as Float;
    var expected = 5.3333;
    logger.debug("mixedSourceAvg=" + actual.format("%.4f"));
    Test.assertMessage(
        (actual - expected).abs() < 0.05,
        "Session summary should keep both power and speed contributions without a reset."
    );
    return true;
}

(:test)
function midSessionResetKeepsCollectingStatusOutOfWarmup(logger as Test.Logger) as Boolean {
    Test.assertMessage(
        EDASessionPolicy.shouldShowWarmupStatus(false, false),
        "Initial collection should still use WARMUP."
    );
    logger.debug("midSessionWarmupGate=" + EDASessionPolicy.shouldShowWarmupStatus(true, true).toString());
    Test.assertMessage(
        !EDASessionPolicy.shouldShowWarmupStatus(true, true),
        "A post-reset recollection after completed warmup should not reuse WARMUP."
    );
    return true;
}
