import Toybox.Lang;

module EDASessionPolicy {

    // WARMUP nur anzeigen wenn:
    // 1. Noch nie Warmup abgeschlossen wurde (Session-Start)
    // 2. UND kein Post-Reset Collecting Status existiert
    // Semantik: UND statt Oder - beide Bedingungen müssen erfüllt sein
    function shouldShowWarmupStatus(hasCompletedWarmupThisSession as Boolean, hasPostResetCollectingStatus as Boolean) as Boolean {
        return !hasCompletedWarmupThisSession && !hasPostResetCollectingStatus;
    }

    function shouldResetSessionFitSummaryForProfileChange(
        previousMinValidHr as Float,
        previousCanUseSpeedWorkload as Boolean,
        previouslyAuthoritative as Boolean,
        currentMinValidHr as Float,
        currentCanUseSpeedWorkload as Boolean,
        currentlyAuthoritative as Boolean
    ) as Boolean {
        if (!previouslyAuthoritative && currentlyAuthoritative) {
            return true;
        }

        return (previousMinValidHr - currentMinValidHr).abs() > 0.0001
            || previousCanUseSpeedWorkload != currentCanUseSpeedWorkload;
    }
}
