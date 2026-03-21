import Toybox.Lang;

// ============================================================================
// EDATypes
// ============================================================================
// Gemeinsame Typen und Konstanten für EDA-Module
// Eliminiert Duplikation von Status-Codes zwischen EDAView und EDAStatusManager
// ============================================================================

module EDATypes {

    // Status Codes für Drift-Anzeige
    // 0 = VALUE (gültiger Drift-Wert)
    // 1 = WAIT (Daten sammeln)
    // 2 = PAUSE (Timer pausiert)
    // 3 = WARMUP (3min Aufwärmphase)
    // 4 = PROVISIONAL (Provisorisches Profil)
    // 5 = PROFILE_TIMEOUT (Profil-Auflösung fehlgeschlagen)
    // 6 = CFG_ERR (Konfigurationsfehler)
    // 7 = NO_HR (kein HR-Sensor)
    // 8 = LOW_HR (HR zu niedrig)
    // 9 = SPIKE (Sensor-Spike)
    // 10 = LOW_POWER (Power zu niedrig)
    // 11 = LOW_PACE (Pace zu langsam)
    // 12 = NO_POWER (kein Power-Sensor)
    // 13 = NO_SPEED (kein Speed-Sensor)
    // 14 = INVALID_SPEED (ungültiger Speed)
    // 15 = GAP (Datenlücke)

    const STATUS_VALUE as Number = 0;
    const STATUS_WAIT as Number = 1;
    const STATUS_PAUSE as Number = 2;
    const STATUS_WARMUP as Number = 3;
    const STATUS_PROVISIONAL as Number = 4;
    const STATUS_PROFILE_TIMEOUT as Number = 5;
    const STATUS_CFG_ERR as Number = 6;
    const STATUS_NO_HR as Number = 7;
    const STATUS_LOW_HR as Number = 8;
    const STATUS_SPIKE as Number = 9;
    const STATUS_LOW_POWER as Number = 10;
    const STATUS_LOW_PACE as Number = 11;
    const STATUS_NO_POWER as Number = 12;
    const STATUS_NO_SPEED as Number = 13;
    const STATUS_INVALID_SPEED as Number = 14;
    const STATUS_GAP as Number = 15;

    // Workload Source Types
    const SOURCE_NONE as Number = 0;
    const SOURCE_POWER as Number = 1;
    const SOURCE_SPEED as Number = 2;

    // Profile States
    const PROFILE_STATE_UNRESOLVED as Number = 0;
    const PROFILE_STATE_PROVISIONAL as Number = 1;
    const PROFILE_STATE_FALLBACK_CONFIRMED as Number = 2;
    const PROFILE_STATE_AUTHORITATIVE as Number = 3;
    const PROFILE_STATE_STALE as Number = 4;

    // Activity Types
    const ACTIVITY_UNKNOWN as Number = 0;
    const ACTIVITY_RUNNING as Number = 1;
    const ACTIVITY_OTHER as Number = 2;
}