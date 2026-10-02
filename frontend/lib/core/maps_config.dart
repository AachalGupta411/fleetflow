/// Compile-time switch for the Google Map widget.
///
/// The map SDK key is not stored in Dart. Put it in
/// `frontend/android/local.properties` as `MAPS_API_KEY`, then build with
/// `--dart-define=MAPS_CONFIGURED=true`.
const bool mapsConfigured = bool.fromEnvironment('MAPS_CONFIGURED');
