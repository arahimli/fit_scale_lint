# fit_scale_lint

An analyzer plugin with warnings and quick fixes for the layout habits
that break on small screens and with large system text: fixed heights
around text, squares scaled on two axes, touch targets sized with `.h`,
and `flutter_screenutil` imports. The warnings show in the IDE as you type
and in `dart analyze` / `flutter analyze`, and each comes with a quick fix
that moves the code to [fit_scale](https://pub.dev/packages/fit_scale).

Needs Dart 3.10 / Flutter 3.38 or newer. On older Flutter versions use
[0.1.x](#flutter-324-to-337-01x), built on custom_lint.

| Rule | Catches | Quick fix | Severity |
| --- | --- | --- | --- |
| [`fixed_height_around_text`](#fixed_height_around_text) | `SizedBox`/`Container` with a fixed `height` and text inside | `FitBox(height: …)` | warning |
| [`separately_scaled_square`](#separately_scaled_square) | `width: n.w, height: n.h` with the same `n` | `FitSquare(size: n)` (or `.r` for both sides) | warning |
| [`tap_height_with_h`](#tap_height_with_h) | a button, tile or tappable area whose height uses `.h` | `n.tap` | warning |
| [`screenutil_import`](#screenutil_import) | `package:flutter_screenutil/…` imports | `package:fit_scale/extensions.dart` | info |

## Setup

Enable the plugin in `analysis_options.yaml` (a top-level `plugins:`
section, not the one under `analyzer:`):

```yaml
plugins:
  fit_scale_lint: ^0.2.0
```

That is all: there is no `dev_dependencies` entry, because the analysis
server resolves plugins on its own, apart from your app's dependencies.
Your `analyzer`, `build_runner` or `melos` versions do not matter.

The quick fixes write `FitBox`, `FitSquare` and `.tap`, which come from
`fit_scale`:

```sh
flutter pub add fit_scale
```

Restart the analysis server (VS Code: *Dart: Restart Analysis Server*;
Android Studio: *Restart Dart Analysis Server*) and the warnings appear in
the editor, with quick fixes in the usual light-bulb menu
(`Ctrl+.` / `Cmd+.`, `Alt+Enter`). `dart analyze` and `flutter analyze`
report them too, so CI needs nothing extra. Plugin quick fixes are applied
one at a time from the IDE; `dart fix` does not apply them.

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
`height: 0` or `double.infinity`, heights read from the layout
(`size.height`, `constraints.maxHeight`, `MediaQuery…`), named
constructors such as
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

Quick fixes: *Replace with FitSquare* (for a `SizedBox` with only
`width`, `height`, `child` and `key`) and *Scale both sides with .r* (any
widget).

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

The rules are warnings, so they are on by default. Turn one off for the
whole project:

```yaml
plugins:
  fit_scale_lint:
    version: ^0.2.0
    diagnostics:
      screenutil_import: false
```

Or for one line or file, with the plugin name in front of the rule:

```dart
// ignore: fit_scale_lint/fixed_height_around_text
SizedBox(height: 48, child: Text('Always one short word')),

// ignore_for_file: fit_scale_lint/separately_scaled_square
```

Warnings make `flutter analyze` exit with a non-zero code, like any other
warning. To adopt the rules gradually, turn the noisy ones off and enable
them again as you fix them.

## Compatibility

### Flutter 3.38 and newer: 0.2.x

0.2.x is built on `analysis_server_plugin`, the analyzer plugin system
that Dart 3.10 introduced. Which analyzer it runs on depends on your SDK:
Dart 3.10 resolves analyzer 12, Dart 3.11 and 3.12 analyzer 14.5, Dart
3.13 and newer the latest 14.x; the rules only use APIs that are the same
in all of them. Tested on Flutter 3.38.9, 3.44.8 and 3.50.1, and on a
real app with melos 8 and analyzer 14 code generators, which custom_lint
cannot resolve next to.

### Flutter 3.24 to 3.37: 0.1.x

Before Dart 3.10 there is no first-party plugin system, so 0.1.x is built
on [custom_lint](https://pub.dev/packages/custom_lint). It has the same
four rules; set it up as a dev dependency:

```sh
flutter pub add dev:custom_lint dev:fit_scale_lint:^0.1.0
```

```yaml
analyzer:
  plugins:
    - custom_lint
```

and run `dart run custom_lint` on the command line. custom_lint needs
analyzer 8 or older, so it does not resolve in projects whose other dev
dependencies need a newer analyzer, or with melos 8; and Dart deprecates
this kind of plugin. Move to 0.2.x when you are on Flutter 3.38 or newer.
The 0.1.x source is on the
[`custom-lint-0.1`](https://github.com/arahimli/fit_scale_lint/tree/custom-lint-0.1)
branch.

## Example

[`example/`](https://github.com/arahimli/fit_scale_lint/tree/main/example)
has every rule firing next to code that passes, with the plugin enabled
from the repository by path. Each expected warning is marked with an
`expect_lint` comment, and `dart run tool/check_example.dart` (run in CI)
fails unless every rule reports exactly on the marked lines and nowhere
else.

## License

MIT
