import Toybox.Lang;

module EDASessionPolicy {

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
