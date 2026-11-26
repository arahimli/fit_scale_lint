import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const rule = SeparatelyScaledSquare();

  group('reports', () {
    test('SizedBox, Container and any widget with width/height', () async {
      expect(
        await lints(
          rule,
          widget(
            'Column(children: [\n'
            '  SizedBox(width: 56.w, height: 56.h),\n'
            '  Container(width: n.w, height: n.h),\n'
            "  Image.asset('a.png', width: 32.w, height: 32.h),\n"
            '])',
          ),
        ),
        ['SizedBox', 'Container', 'Image.asset'],
      );
    });
  });

  group('does not report', () {
    for (final entry in {
      'different sizes': 'SizedBox(width: 120.w, height: 48.h)',
      '.r on both sides': 'SizedBox(width: 56.r, height: 56.r)',
      '.w on both sides': 'SizedBox(width: 56.w, height: 56.w)',
      'plain numbers': 'SizedBox(width: 56, height: 56)',
    }.entries) {
      test(entry.key, () async {
        expect(await lints(rule, widget(entry.value)), isEmpty);
      });
    }
  });

  group('quick fix', () {
    test('SizedBox -> FitSquare', () async {
      expect(
        await applyFix(
          rule,
          widget('SizedBox(width: 56.w, height: 56.h, child: CircleAvatar())'),
        ),
        widget('FitSquare(size: 56, child: CircleAvatar())'),
      );
    });

    test('FitSquare adds the import and keeps the key', () async {
      expect(
        await applyFix(
          rule,
          widget(
            "SizedBox(key: Key('k'), width: 56.w, height: 56.h)",
            imports: material + screenUtil,
          ),
        ),
        widget(
          "FitSquare(key: Key('k'), size: 56)",
          imports: fitScale + material + screenUtil,
        ),
      );
    });

    test('.r for both sides', () async {
      expect(
        await applyFix(
          rule,
          widget('Container(width: n.w, height: n.h)'),
        ),
        widget('Container(width: n.r, height: n.r)'),
      );
    });

    test('one fix per lint', () async {
      // `dart run custom_lint --fix` applies every fix a lint offers.
      expect(SeparatelyScaledSquare().getFixes(), hasLength(1));
    });
  });
}
