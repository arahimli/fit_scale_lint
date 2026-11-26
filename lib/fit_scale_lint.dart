/// Analyzer plugin with warnings and quick fixes for layouts that break on
/// small screens or with large system text. The plugin itself is in
/// `lib/main.dart`; this library exposes the rules and fixes for tests.
library;

export 'src/rules/fixed_height_around_text.dart'
    show FixedHeightAroundText, UseFitBox;
export 'src/rules/screenutil_import.dart'
    show ScreenutilImport, UseFitExtensions;
export 'src/rules/separately_scaled_square.dart'
    show ScaleBothSidesWithR, SeparatelyScaledSquare, UseFitSquare;
export 'src/rules/tap_height_with_h.dart' show TapHeightWithH, UseTap;
