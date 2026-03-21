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

// ============================================================================
// Edge-Case Tests: Status Manager
// ============================================================================

(:test)
function statusManagerReturnsCorrectLabels(logger as Test.Logger) as Boolean {
    var waitLabel = EDAStatusManager.getStatusLabel(1, "WAIT", "PAUSE", "WARMUP", "PROV", "P TIME", "CFG", "NO HR", "LOW HR", "SPIKE", "LOW P", "SLOW", "NO P", "NO SPD", "BAD SPD", "GAP", "--");
    Test.assertMessage(waitLabel.equals("WAIT"), "Status 1 should return WAIT label.");
    
    var pauseLabel = EDAStatusManager.getStatusLabel(2, "WAIT", "PAUSE", "WARMUP", "PROV", "P TIME", "CFG", "NO HR", "LOW HR", "SPIKE", "LOW P", "SLOW", "NO P", "NO SPD", "BAD SPD", "GAP", "--");
    Test.assertMessage(pauseLabel.equals("PAUSE"), "Status 2 should return PAUSE label.");
    
    var valueLabel = EDAStatusManager.getStatusLabel(0, "WAIT", "PAUSE", "WARMUP", "PROV", "P TIME", "CFG", "NO HR", "LOW HR", "SPIKE", "LOW P", "SLOW", "NO P", "NO SPD", "BAD SPD", "GAP", "--");
    Test.assertMessage(valueLabel.equals("--"), "Status 0 should return default label.");
    
    return true;
}

(:test)
function statusManagerReturnsCorrectShortLabels(logger as Test.Logger) as Boolean {
    var waitLabel = EDAStatusManager.getStatusShortLabel(1, "W", "P", "WARM", "PROV", "PTIME", "CFG", "NOHR", "LOWHR", "SPIKE", "LOWP", "SLOW", "NOP", "NOSP", "BADSP", "GAP", "--");
    Test.assertMessage(waitLabel.equals("W"), "Status 1 should return W short label.");
    
    var valueLabel = EDAStatusManager.getStatusShortLabel(0, "W", "P", "WARM", "PROV", "PTIME", "CFG", "NOHR", "LOWHR", "SPIKE", "LOWP", "SLOW", "NOP", "NOSP", "BADSP", "GAP", "--");
    Test.assertMessage(valueLabel.equals("--"), "Status 0 should return default short label.");
    
    return true;
}

// ============================================================================
// Edge-Case Tests: Feature Flags
// ============================================================================

(:test)
function featureFlagsReturnValidValues(logger as Test.Logger) as Boolean {
    Test.assertMessage(EDAFeatureFlags.getMinValidPower() == 30.0, "Min valid power should be 30W.");
    Test.assertMessage(EDAFeatureFlags.getMaxValidPower() == 700.0, "Max valid power should be 700W.");
    Test.assertMessage(EDAFeatureFlags.getMaxSpeedMs() == 12.0, "Max speed should be 12 m/s.");
    Test.assertMessage(EDAFeatureFlags.getMaxRunningPacePerKm() == 480.0, "Max running pace should be 480s/km.");
    Test.assertMessage(EDAFeatureFlags.getHrJumpPerSec() == 20.0, "HR jump per sec should be 20 bpm/s.");
    Test.assertMessage(EDAFeatureFlags.getSpeedJumpPerSec() == 4.0, "Speed jump per sec should be 4 m/s.");
    Test.assertMessage(EDAFeatureFlags.getWarmupValidMs() == 180000, "Warmup valid should be 180s.");
    Test.assertMessage(EDAFeatureFlags.getMaxValidSampleGapMs() == 5000, "Max valid sample gap should be 5s.");
    Test.assertMessage(EDAFeatureFlags.getDataDrivenGapMs() == 20000, "Data driven gap should be 20s.");
    Test.assertMessage(EDAFeatureFlags.getMaxResumeGapResetMs() == 300000, "Max resume gap reset should be 300s.");
    Test.assertMessage(EDAFeatureFlags.getFallbackExportTimeoutMs() == 120000, "Fallback export timeout should be 120s.");
    Test.assertMessage(EDAFeatureFlags.getImplicitTimerResetToleranceMs() == 5000, "Implicit timer reset tolerance should be 5s.");
    Test.assertMessage(EDAFeatureFlags.getSourceSwitchConfirmSamples() == 3, "Source switch confirm samples should be 3.");
    Test.assertMessage(EDAFeatureFlags.getDriftWindowMs() == 1200000, "Drift window should be 20min.");
    Test.assertMessage(EDAFeatureFlags.getDriftBucketCount() == 120, "Drift bucket count should be 120.");
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

// ============================================================================
// Edge-Case Tests: Source Selector
// ============================================================================

(:test)
function sourceSelectorRejectsNullPower(logger as Test.Logger) as Boolean {
    var selector = new EDAWorkloadSourceSelector();
    Test.assertMessage(!selector.hasUsablePower(null), "Null power should be rejected.");
    Test.assertMessage(!selector.hasUsablePower(0.0), "Zero power should be rejected.");
    Test.assertMessage(!selector.hasUsablePower(29.9), "Power below 30W should be rejected.");
    Test.assertMessage(!selector.hasUsablePower(700.1), "Power above 700W should be rejected.");
    Test.assertMessage(selector.hasUsablePower(200.0), "Power 200W should be accepted.");
    return true;
}

(:test)
function sourceSelectorValidatesSpeedForRunning(logger as Test.Logger) as Boolean {
    var selector = new EDAWorkloadSourceSelector();
    selector.updateProfile(true); // Running profile

    Test.assertMessage(!selector.hasUsableSpeedWorkload(null), "Null speed should be rejected.");
    Test.assertMessage(!selector.hasUsableSpeedWorkload(0.0), "Zero speed should be rejected.");
    Test.assertMessage(!selector.hasUsableSpeedWorkload(13.0), "Speed above 12 m/s should be rejected.");
    Test.assertMessage(selector.hasUsableSpeedWorkload(3.0), "Speed 3 m/s should be accepted for running.");

    selector.updateProfile(false); // Non-running profile
    Test.assertMessage(!selector.hasUsableSpeedWorkload(3.0), "Speed should be rejected for non-running profile.");
    return true;
}

(:test)
function sourceSelectorPrefersPowerOverSpeed(logger as Test.Logger) as Boolean {
    var selector = new EDAWorkloadSourceSelector();
    selector.updateProfile(true);

    var source = selector.determinePreferredWorkloadSource(3.0, 200.0);
    Test.assertEqualMessage(1, source, "Power should be preferred over speed when both available.");

    source = selector.determinePreferredWorkloadSource(3.0, null);
    Test.assertEqualMessage(2, source, "Speed should be used when power is unavailable.");

    source = selector.determinePreferredWorkloadSource(null, null);
    Test.assertEqualMessage(0, source, "SOURCE_NONE when neither available.");
    return true;
}

// ============================================================================
// Edge-Case Tests: Warmup-Logik (korrigiert)
// ============================================================================

(:test)
function warmupLogicCorrected(logger as Test.Logger) as Boolean {
    // Korrigierte Logik: UND statt ODER
    // WARMUP nur wenn: !completedWarmup && !postResetCollecting
    Test.assertMessage(
        EDASessionPolicy.shouldShowWarmupStatus(false, false),
        "WARMUP shown when never completed warmup AND no post-reset."
    );
    Test.assertMessage(
        !EDASessionPolicy.shouldShowWarmupStatus(true, false),
        "No WARMUP when already completed warmup."
    );
    Test.assertMessage(
        !EDASessionPolicy.shouldShowWarmupStatus(false, true),
        "No WARMUP when post-reset collecting exists."
    );
    Test.assertMessage(
        !EDASessionPolicy.shouldShowWarmupStatus(true, true),
        "No WARMUP when both completed AND post-reset."
    );
    return true;
}

// ============================================================================
// Edge-Case Tests: Drift Engine
// ============================================================================

(:test)
function driftEngineRejectsInvalidSamples(logger as Test.Logger) as Boolean {
    var engine = new EDADriftEngine();
    
    // Invalid: timer <= 0
    engine.recordValidSample(0, 1000, 2.0);
    // Invalid: delta <= 0
    engine.recordValidSample(10000, 0, 2.0);
    // Invalid: delta > 5000ms
    engine.recordValidSample(10000, 6000, 2.0);
    // Invalid: ef <= 0
    engine.recordValidSample(10000, 1000, 0.0);

    var drift = engine.computeDrift(180000);
    Test.assertMessage(drift == null, "Drift should be null after only invalid samples.");
    return true;
}

// ============================================================================
// Edge-Case Tests: Drift Clamping
// ============================================================================

(:test)
function driftClampedAt50Percent(logger as Test.Logger) as Boolean {
    var engine = new EDADriftEngine();
    engine.reset();

    // Extreme scenario: Split 1 much higher than Split 2
    // Split 1 (0-90s): High efficiency (ef=5.0)
    // Split 2 (90-180s): Low efficiency (ef=1.0)
    // Expected drift: (5.0/1.0 - 1) * 100 = 400%, clamped to 50%

    // Split 1 samples
    for (var i = 0; i < 9; i += 1) {
        engine.recordValidSample((i + 1) * 10000, 10000, 5.0);
    }

    // Split 2 samples
    for (var i = 9; i < 18; i += 1) {
        engine.recordValidSample((i + 1) * 10000, 10000, 1.0);
    }

    var drift = engine.computeDrift(180000);
    Test.assertMessage(drift != null, "Drift should be computed.");
    var actual = drift as Float;
    logger.debug("clampedDrift=" + actual.format("%.2f"));
    Test.assertMessage(
        actual <= 50.0 && actual >= -50.0,
        "Drift should be clamped between -50% and +50%."
    );
    return true;
}

// ============================================================================
// Edge-Case Tests: Lifecycle Manager
// ============================================================================

(:test)
function lifecycleManagerDetectsImplicitReset(logger as Test.Logger) as Boolean {
    var manager = new EDALifecycleManager();
    
    manager.setLastActiveTimerTime(100000);
    
    // Timer rollback > 5s should trigger implicit reset
    Test.assertMessage(
        manager.shouldTriggerImplicitReset(90000),
        "Timer rollback > 5s should trigger implicit reset."
    );
    
    // Timer rollback <= 5s should NOT trigger implicit reset
    manager.setLastActiveTimerTime(100000);
    Test.assertMessage(
        !manager.shouldTriggerImplicitReset(95001),
        "Timer rollback <= 5s should not trigger implicit reset."
    );
    
    return true;
}

(:test)
function lifecycleManagerDetectsPauseResume(logger as Test.Logger) as Boolean {
    var manager = new EDALifecycleManager();
    
    // Remember pause timestamp
    manager.rememberPauseTimestamp();
    Test.assertMessage(
        manager.getPauseTimestamp() != null,
        "Pause timestamp should be recorded."
    );
    
    // shouldResetAfterResumePause clears the pause state
    manager.clearLifecyclePauseState();
    Test.assertMessage(
        manager.getPauseTimestamp() == null,
        "Pause state should be cleared."
    );
    
    return true;
}

(:test)
function lifecycleManagerSampleDelta(logger as Test.Logger) as Boolean {
    var manager = new EDALifecycleManager();
    
    // First sample: delta should be 0
    var delta = manager.getSampleDelta(10000);
    Test.assertEqualMessage(0, delta, "First sample delta should be 0.");
    
    // Second sample: delta should be 10000
    delta = manager.getSampleDelta(20000);
    Test.assertEqualMessage(10000, delta, "Second sample delta should be 10000.");
    
    // Non-monotonic timer: delta should be 0
    delta = manager.getSampleDelta(15000);
    Test.assertEqualMessage(0, delta, "Non-monotonic timer delta should be 0.");
    
    return true;
}
