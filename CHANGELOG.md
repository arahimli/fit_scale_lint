## 0.2.0

**Breaking:** now an analyzer plugin built on `analysis_server_plugin`
(Dart 3.10 / Flutter 3.38 and newer) instead of custom_lint. Enable it
under a top-level `plugins:` section in `analysis_options.yaml` and remove
the `custom_lint` and `fit_scale_lint` dev dependencies. On Flutter 3.24
to 3.37 keep using 0.1.x.

- The warnings show in `dart analyze` and `flutter analyze`, and the
  plugin resolves apart from the app's dependencies, so it works next to
  melos 8 and code generators that need analyzer 14 (custom_lint does not
  resolve there).
- `fixed_height_around_text` no longer reports heights read from the
  layout (`size.height`, `constraints.maxHeight`, `MediaQuery…`).
- `separately_scaled_square` offers both quick fixes again (FitSquare and
  `.r`): plugin fixes are only applied one at a time from the IDE.

## 0.1.0

First release, built on custom_lint (Flutter 3.24 / Dart 3.5 and newer).

- `fixed_height_around_text`: a fixed-height `SizedBox`/`Container` with
  text inside. Quick fix: `FitBox(height: …)`, with `interactive: true`
  around buttons.
- `separately_scaled_square`: `width: n.w, height: n.h`. Quick fixes:
  `FitSquare(size: n)` or `.r` for both sides.
- `tap_height_with_h`: a touch target whose height uses `.h`. Quick fix:
  `.tap`.
- `screenutil_import`: `package:flutter_screenutil` imports. Quick fix:
  `package:fit_scale/extensions.dart`.
