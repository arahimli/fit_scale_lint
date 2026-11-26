import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const rule = TapHeightWithH();

  group('reports', () {
    test('a box around a button', () async {
      expect(
        await lints(
          rule,
          widget(
            'SizedBox(height: 40.h, '
            'child: IconButton(onPressed: null, icon: Icon(Icons.add)))',
          ),
        ),
        ['40.h'],
      );
    });

    test('a box inside a tappable area, through Padding', () async {
      expect(
        await lints(
          rule,
          widget(
            'InkWell(onTap: null, child: Padding(padding: EdgeInsets.zero, '
            'child: SizedBox(height: n.h, child: Icon(Icons.close))))',
          ),
        ),
        ['n.h'],
      );
    });

    test('button style and button height arguments', () async {
      expect(
        await lints(
          rule,
          widget(
            'Column(children: [\n'
            '  ElevatedButton(style: ElevatedButton.styleFrom('
            'minimumSize: Size(double.infinity, 44.h)), '
            'onPressed: null, child: Icon(Icons.add)),\n'
            '  FilledButton(style: FilledButton.styleFrom('
            'fixedSize: Size.fromHeight(48.h)), '
            'onPressed: null, child: Icon(Icons.add)),\n'
            '  MaterialButton(height: 40.h, onPressed: null),\n'
            '  ListTile(minTileHeight: 56.h),\n'
            '])',
          ),
        ),
        ['44.h', '48.h', '40.h', '56.h'],
      );
    });
  });

  group('does not report', () {
    for (final entry in {
      'not a touch target': 'SizedBox(height: 40.h, child: Icon(Icons.star))',
      '.tap': 'SizedBox(height: 40.tap, '
          'child: IconButton(onPressed: null, icon: Icon(Icons.add)))',
      '.r': 'SizedBox(height: 40.r, '
          'child: IconButton(onPressed: null, icon: Icon(Icons.add)))',
      'a width': 'SizedBox(width: 40.w, '
          'child: IconButton(onPressed: null, icon: Icon(Icons.add)))',
      // Reported by fixed_height_around_text, whose fix keeps the target.
      'text inside': 'SizedBox(height: 48.h, '
          "child: FilledButton(onPressed: null, child: Text('Pay')))",
      'Size width': 'ElevatedButton(style: ElevatedButton.styleFrom('
          'minimumSize: Size(44.h, 48)), onPressed: null, child: null)',
    }.entries) {
      test(entry.key, () async {
        expect(await lints(rule, widget(entry.value)), isEmpty);
      });
    }
  });

  group('quick fix', () {
    const button = 'IconButton(onPressed: null, icon: Icon(Icons.add))';

    test('.h -> .tap', () async {
      expect(
        await applyFix(
          rule,
          widget('SizedBox(height: 40.h, child: $button)'),
        ),
        widget('SizedBox(height: 40.tap, child: $button)'),
      );
    });

    test('swaps a flutter_screenutil import for fit_scale', () async {
      expect(
        await applyFix(
          rule,
          widget(
            'SizedBox(height: 40.h, child: $button)',
            imports: material + screenUtil,
          ),
        ),
        widget(
          'SizedBox(height: 40.tap, child: $button)',
          imports: material + fitExtensions,
        ),
      );
    });
  });
}
