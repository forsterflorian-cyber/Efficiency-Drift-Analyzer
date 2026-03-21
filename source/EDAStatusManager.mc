import Toybox.Lang;

// ============================================================================
// EDAStatusManager
// ============================================================================
// Verantwortlich für:
// - Status-Code → Label Mapping (O(1) Lookup)
// - Status-Label für Long/Short Formate
// - Status-Detail Text
//
// Extrahiert aus EDAView (~100 Zeilen reduziert)
// Eliminiert Code-Duplikation: getStatusLabel/getStatusShortLabel
// ============================================================================

module EDAStatusManager {

    // --------------------------------------------------------------------------
    // O(1) Status Label Lookup (verwendet EDATypes Konstanten)
    // --------------------------------------------------------------------------

    function getStatusLabel(statusCode as Number, lblWait as String, lblPause as String, lblWarmup as String, lblProvisional as String, lblProfileTimeout as String, lblCfgErr as String, lblNoHr as String, lblLowHr as String, lblSpike as String, lblLowPower as String, lblLowPace as String, lblNoPower as String, lblNoSpeed as String, lblInvalidSpeed as String, lblGap as String, defaultDrift as String) as String {
        if (statusCode == EDATypes.STATUS_WAIT) { return lblWait; }
        if (statusCode == EDATypes.STATUS_PAUSE) { return lblPause; }
        if (statusCode == EDATypes.STATUS_WARMUP) { return lblWarmup; }
        if (statusCode == EDATypes.STATUS_PROVISIONAL) { return lblProvisional; }
        if (statusCode == EDATypes.STATUS_PROFILE_TIMEOUT) { return lblProfileTimeout; }
        if (statusCode == EDATypes.STATUS_CFG_ERR) { return lblCfgErr; }
        if (statusCode == EDATypes.STATUS_NO_HR) { return lblNoHr; }
        if (statusCode == EDATypes.STATUS_LOW_HR) { return lblLowHr; }
        if (statusCode == EDATypes.STATUS_SPIKE) { return lblSpike; }
        if (statusCode == EDATypes.STATUS_LOW_POWER) { return lblLowPower; }
        if (statusCode == EDATypes.STATUS_LOW_PACE) { return lblLowPace; }
        if (statusCode == EDATypes.STATUS_NO_POWER) { return lblNoPower; }
        if (statusCode == EDATypes.STATUS_NO_SPEED) { return lblNoSpeed; }
        if (statusCode == EDATypes.STATUS_INVALID_SPEED) { return lblInvalidSpeed; }
        if (statusCode == EDATypes.STATUS_GAP) { return lblGap; }
        return defaultDrift;
    }

    function getStatusShortLabel(statusCode as Number, lblWaitShort as String, lblPauseShort as String, lblWarmupShort as String, lblProvisionalShort as String, lblProfileTimeoutShort as String, lblCfgErrShort as String, lblNoHrShort as String, lblLowHrShort as String, lblSpikeShort as String, lblLowPowerShort as String, lblLowPaceShort as String, lblNoPowerShort as String, lblNoSpeedShort as String, lblInvalidSpeedShort as String, lblGapShort as String, defaultDrift as String) as String {
        if (statusCode == EDATypes.STATUS_WAIT) { return lblWaitShort; }
        if (statusCode == EDATypes.STATUS_PAUSE) { return lblPauseShort; }
        if (statusCode == EDATypes.STATUS_WARMUP) { return lblWarmupShort; }
        if (statusCode == EDATypes.STATUS_PROVISIONAL) { return lblProvisionalShort; }
        if (statusCode == EDATypes.STATUS_PROFILE_TIMEOUT) { return lblProfileTimeoutShort; }
        if (statusCode == EDATypes.STATUS_CFG_ERR) { return lblCfgErrShort; }
        if (statusCode == EDATypes.STATUS_NO_HR) { return lblNoHrShort; }
        if (statusCode == EDATypes.STATUS_LOW_HR) { return lblLowHrShort; }
        if (statusCode == EDATypes.STATUS_SPIKE) { return lblSpikeShort; }
        if (statusCode == EDATypes.STATUS_LOW_POWER) { return lblLowPowerShort; }
        if (statusCode == EDATypes.STATUS_LOW_PACE) { return lblLowPaceShort; }
        if (statusCode == EDATypes.STATUS_NO_POWER) { return lblNoPowerShort; }
        if (statusCode == EDATypes.STATUS_NO_SPEED) { return lblNoSpeedShort; }
        if (statusCode == EDATypes.STATUS_INVALID_SPEED) { return lblInvalidSpeedShort; }
        if (statusCode == EDATypes.STATUS_GAP) { return lblGapShort; }
        return defaultDrift;
    }

    // --------------------------------------------------------------------------
    // Status Detail Text
    // --------------------------------------------------------------------------

    function getDefaultStatusDetail(statusCode as Number, msgCollectingData as String, msgConfigRequired as String, msgPowerRequired as String, msgNoSpeed as String, msgInvalidSpeed as String, msgProvisionalProfile as String, msgProfileTimeout as String, lastErrorCode as String, msgProfileErrorPrefix as String) as String? {
        if (statusCode == EDATypes.STATUS_WAIT) {
            return msgCollectingData;
        } else if (statusCode == EDATypes.STATUS_CFG_ERR) {
            return msgConfigRequired;
        } else if (statusCode == EDATypes.STATUS_NO_POWER) {
            return msgPowerRequired;
        } else if (statusCode == EDATypes.STATUS_NO_SPEED) {
            return msgNoSpeed;
        } else if (statusCode == EDATypes.STATUS_INVALID_SPEED) {
            return msgInvalidSpeed;
        } else if (statusCode == EDATypes.STATUS_PROVISIONAL) {
            return msgProvisionalProfile;
        } else if (statusCode == EDATypes.STATUS_PROFILE_TIMEOUT) {
            return msgProfileTimeout;
        }

        if (lastErrorCode != "") {
            return msgProfileErrorPrefix + ": " + lastErrorCode;
        }

        return null;
    }

    function getDefaultStatusDetailShort(statusCode as Number, msgCollectingDataShort as String, msgConfigRequiredShort as String, msgPowerRequiredShort as String, msgNoSpeedShort as String, msgInvalidSpeedShort as String, msgProvisionalProfileShort as String, msgProfileTimeoutShort as String, lastErrorCode as String, msgProfileErrorPrefixShort as String) as String? {
        if (statusCode == EDATypes.STATUS_WAIT) {
            return msgCollectingDataShort;
        } else if (statusCode == EDATypes.STATUS_CFG_ERR) {
            return msgConfigRequiredShort;
        } else if (statusCode == EDATypes.STATUS_NO_POWER) {
            return msgPowerRequiredShort;
        } else if (statusCode == EDATypes.STATUS_NO_SPEED) {
            return msgNoSpeedShort;
        } else if (statusCode == EDATypes.STATUS_INVALID_SPEED) {
            return msgInvalidSpeedShort;
        } else if (statusCode == EDATypes.STATUS_PROVISIONAL) {
            return msgProvisionalProfileShort;
        } else if (statusCode == EDATypes.STATUS_PROFILE_TIMEOUT) {
            return msgProfileTimeoutShort;
        }

        if (lastErrorCode != "") {
            return msgProfileErrorPrefixShort + ": " + lastErrorCode;
        }

        return null;
    }
}