# GPS Pointer 2.3 STEP5B

Baseline: REAL phone-tested 1.0.0+39 snapshot supplied by user.

Scope:
- saved Coverage/PTP re-open with result data, altimetry profile and maps;
- PDF complete from detail screen with captured profile and Google Map snapshots;
- .gpspsim manual import accepts octet-stream/generic Android providers;
- Android VIEW association expanded for .gpspsim delivered as BIN/octet-stream;
- Settings card opens Android application settings for file/default management;
- AR diagnostic flags + persistent TXT + share; PointingEngineV2 untouched;
- Debug center marks AR diagnostics ACTIVE.

MAPS SAFETY:
- android/local.properties is NOT in payload;
- installer verifies MAPS_API_KEY exists before precheck;
- installer hashes local.properties before and after and aborts if changed.

Protected:
- PointingEngineV2
- PointingController
- compass_screen.dart exact current baseline
- antenna_tilt_screen.dart
- Android orientation service
