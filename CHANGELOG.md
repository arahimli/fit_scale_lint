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
