import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const rule = ScreenutilImport();
  const body = 'Widget build() => SizedBox(height: 16.h);\n';

  test('reports the flutter_screenutil import', () async {
    expect(
      await lints(rule, material + screenUtil + body),
      ["'package:flutter_screenutil/flutter_screenutil.dart'"],
    );
  });

  test('does not report fit_scale', () async {
    expect(await lints(rule, material + fitExtensions + body), isEmpty);
  });

  test('quick fix imports fit_scale extensions instead', () async {
    expect(
      await applyFix(rule, material + screenUtil + body),
      material + fitExtensions + body,
    );
  });

  test('quick fix removes it when fit_scale is already imported', () async {
    expect(
      await applyFix(rule, material + fitExtensions + screenUtil + body),
      material + fitExtensions + body,
    );
  });
}
