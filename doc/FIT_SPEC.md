# FIT Developer Field Specification (EDA)

| Field ID | Name                 | Type   | Unit | Description |
| :---     | :---                 | :---   | :--- | :---        |
| 1        | avg_metabolic_drift  | float  | %    | Epochen-Durchschnitt |
| 2        | profile_state        | uint8  | -    | Vertrauensstatus (0-4)|

## Profile States (profile_state)
- 0: UNRESOLVED (Initialsuche)
- 1: PROVISIONAL (Vorlaeufiges Profil)
- 2: FALLBACK_CONFIRMED (Timeout, Export nach 120s freigegeben)
- 3: AUTHORITATIVE (API-bestaetigt, Export aktiv)
- 4: STALE (Revalidierung fehlgeschlagen, Export pausiert)