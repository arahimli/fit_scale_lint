# fit_scale_lint

Lint rules and quick fixes for the layout habits that break on small
screens and with large system text: fixed heights around text, squares
scaled on two axes, touch targets sized with `.h`, and
`flutter_screenutil` imports. Each warning shows in the IDE as you type,
and most come with a one-click fix that moves the code to
[fit_scale](https://pub.dev/packages/fit_scale).

| Rule | Catches | Quick fix | Severity |
| --- | --- | --- | --- |
| [`fixed_height_around_text`](#fixed_height_around_text) | `SizedBox`/`Container` with a fixed `height` and text inside | `FitBox(height: …)` | warning |
| [`separately_scaled_square`](#separately_scaled_square) | `width: n.w, height: n.h` with the same `n` | `FitSquare(size: n)` (or `.r` for both sides) | warning |
| [`tap_height_with_h`](#tap_height_with_h) | a button, tile or tappable area whose height uses `.h` | `n.tap` | warning |
| [`screenutil_import`](#screenutil_import) | `package:flutter_screenutil/…` imports | `package:fit_scale/extensions.dart` | info |

## Setup

Add `custom_lint` and this package to `dev_dependencies`:

```sh
flutter pub add dev:custom_lint dev:fit_scale_lint
```

The quick fixes write `FitBox`, `FitSquare` and `.tap`, which come from
`fit_scale`:

```sh
flutter pub add fit_scale
```

Enable the plugin in `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

Restart the analysis server (VS Code: *Dart: Restart Analysis Server*;
Android Studio: *Restart Dart Analysis Server*) and the warnings appear in
the editor. The quick fixes are in the usual light-bulb menu
(`Ctrl+.` / `Cmd+.`, `Alt+Enter`).

`dart analyze` and `flutter analyze` do not run analyzer plugins. To check
from the command line or CI, run:

```sh
dart run custom_lint
```

It exits with a non-zero code when it finds anything, and
`dart run custom_lint --fix` applies every quick fix.

## Rules

### fixed_height_around_text

`SizedBox` or `Container` with a fixed `height` and a `Text`, `RichText`,
`SelectableText` or text field anywhere in its `child`. Text grows with
the system font size and the box does not, so on a small screen or with
a large system font the text is cut off or overflows.

```dart
// Bad
SizedBox(height: 48.h, child: Text('Total: 12.50 AZN'))
Container(height: 56.h, color: Colors.amber, child: Text('Limited offer'))

// Good: a minimum height that grows with its content
FitBox(height: 48, child: Text('Total: 12.50 AZN'))
FitBox(height: 56, child: Container(color: Colors.amber, child: Text('Limited offer')))
```

The quick fix strips `.h` (FitBox takes the design value and scales it)
and keeps other arguments of the box. When the box holds a button, or sits
inside one, the fix adds `interactive: true` so the minimum height also
never drops below the touch-target size.

Not reported: boxes without text, spacing (`SizedBox(height: 16.h)`),
`height: 0` or `double.infinity`, named constructors such as
`SizedBox.square`, a `Container` with `constraints`, and text inside a
scrollable (`ListView`, `SingleChildScrollView`, …), `FittedBox`,
`FitText` or `FitBox`. When fixed boxes are nested, only the one closest
to the text is reported.

### separately_scaled_square

Any constructor call with `width: n.w` and `height: n.h` for the same `n`.
`.w` follows the screen width and `.h` the height, so the square is only
square on screens with the design's proportions; on others a circle
becomes an oval.

```dart
// Bad
SizedBox(width: 56.w, height: 56.h, child: CircleAvatar())
Image.asset('assets/logo.png', width: 32.w, height: 32.h)

// Good
FitSquare(size: 56, child: CircleAvatar())
Image.asset('assets/logo.png', width: 32.r, height: 32.r)
```

Quick fix: *Replace with FitSquare* for a `SizedBox` with only `width`,
`height`, `child` and `key`; *Scale both sides with .r* for anything
else.

Not reported: different sizes (`width: 120.w, height: 48.h`), `.r` or
`.w` on both sides, plain numbers.

### tap_height_with_h

A height scaled with `.h` on something the user taps. On a short screen
(a phone in landscape, a small Android) `.h` shrinks the target below the
48 px Android / 44 pt iOS minimum. fit_scale's `.tap` scales uniformly and
never goes below the platform minimum.

Reported for:

- `SizedBox`/`Container` `height:` when its child is a button, tile,
  `InkWell` or `GestureDetector`, or it is the child of one (through
  `Padding`, `Center`, `Align`, `Expanded`, `Flexible`, `Semantics`);
- `minimumSize`/`fixedSize` in `XButton.styleFrom(...)`:
  `Size(w, n.h)`, `Size.fromHeight(n.h)`, `Size.square(n.h)`;
- height arguments of the tap widget itself: `MaterialButton(height:)`,
  `ListTile(minTileHeight:)`, `CupertinoButton(minSize:)`, ….

```dart
// Bad
SizedBox(height: 40.h, child: IconButton(onPressed: onAdd, icon: Icon(Icons.add)))
ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 44.h))

// Good
SizedBox(height: 40.tap, child: IconButton(onPressed: onAdd, icon: Icon(Icons.add)))
ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 44.tap))
```

The quick fix replaces `.h` with `.tap` and imports
`package:fit_scale/extensions.dart`; a `flutter_screenutil` import in the
same file is replaced rather than kept, because both packages define `.h`
and keeping both makes every use ambiguous.

Not reported: boxes that are not touch targets, widths, `.r`/`.tap`, and
boxes with text inside (those get `fixed_height_around_text`, whose fix
keeps the touch target too).

### screenutil_import

An import of `package:flutter_screenutil/…`. fit_scale's extensions have
the same names (`.w .h .r .sp .sw .sh .verticalSpace .horizontalSpace`) but
clamp the scale factors, so swapping the import is the first step of a
migration.

```dart
// Bad
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Good
import 'package:fit_scale/extensions.dart';
```

The quick fix swaps the import (or removes it when fit_scale's extensions
are already imported). Then replace `ScreenUtilInit` with `FitScaleScope`;
see the [fit_scale migration guide](https://pub.dev/packages/fit_scale).

## Configuration

Turn a rule off for the whole project:

```yaml
custom_lint:
  rules:
    - screenutil_import: false
```

Or for one line or file, like any lint:

```dart
// ignore: fixed_height_around_text
SizedBox(height: 48, child: Text('Always one short word')),

// ignore_for_file: separately_scaled_square
```

## Why custom_lint and not analysis_server_plugin

Dart 3.10 introduced first-party analyzer plugins
(`analysis_server_plugin`), which run inside `dart analyze` without an
extra command. Every release of it requires Dart 3.9 or newer (the latest
3.13), and it pins one exact analyzer version per release.
`fit_scale` supports Flutter 3.24 (Dart 3.5) and newer, so a plugin built
on it would not even resolve for a large part of its users.

`custom_lint` works on all of them: this package allows
`custom_lint_builder` 0.7.0 to 0.8.x, so pub picks analyzer 6 on Flutter
3.24 and analyzer 8 on the current stable, and the rules only use AST APIs
that are the same in analyzer 6, 7 and 8. A version built on
`analysis_server_plugin` can follow once Dart 3.10 is the oldest version
worth supporting.

## Compatibility

Tested on Flutter 3.24.3 (Dart 3.5, custom_lint 0.7.0, analyzer 6.7) and
Flutter 3.38.9 (Dart 3.10, custom_lint 0.8.1, analyzer 8.4), and with
analyzer 7.6 (custom_lint 0.8.0). CI runs the oldest supported Flutter
(3.24.5) and the latest stable (3.50.1 at the time of release).

Recent SDKs show a warning on the `plugins:` line of
`analysis_options.yaml`: legacy analyzer plugins such as custom_lint are
deprecated in favour of `analysis_server_plugin` and will be removed in a
future Dart release. The rules still run; the warning is about the plugin
system, not about this package.

When you run custom_lint with a Flutter version that is not the one on
your `PATH` (fvm, for example), put that version first on `PATH`:
custom_lint resolves its plugin host by running `flutter pub get`.

## Example

[`example/`](https://github.com/arahimli/fit_scale_lint/tree/main/example)
has every rule firing next to code that passes; each expected warning is
marked with an `expect_lint` comment, so `dart run custom_lint` there
exits cleanly only when every rule reports exactly where it should.

## License

MIT
