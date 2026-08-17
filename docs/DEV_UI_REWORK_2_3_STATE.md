# GPS Pointer - DEV UI Rework 2.3 / STEP4

## Frozen sensor policy
- Azimut uses release-2.2 engine unchanged.
- Vertical long-edge pose is the operational pose under test.
- No artificial heading offset is applied.
- AR/Tilt/calibration engine controls are not altered by STEP4.

## STEP4
- Radar Pro Home: visual composition closer to supplied lighthouse mockup.
- Radar Pro splash: lighthouse/installer scene, logo, slogan and loading strip.
- Classic Home: real 2-column buttons/cards instead of list rows.
- Postazioni Radio: legacy Home action strip removed from catalogue list.
- Aggiungi Postazione Radio: dedicated full page with current GPS and TXT export.
- Debug: persistent TXT file archive, open/share/delete.
- Azimut: flag + debug toggle + TXT export are top actions; inline button row removed.
- Every Azimut flag persists a TXT session snapshot automatically.
- PTP: hybrid roof/detail view added for Point B too.
- Maps configuration is preserved through android/local.properties and is not touched.
