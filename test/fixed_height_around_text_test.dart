import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const rule = FixedHeightAroundText();

  group('reports', () {
    test('SizedBox with .h around Text', () async {
      expect(
        await lints(rule, widget("SizedBox(height: 48.h, child: Text('a'))")),
        ['SizedBox'],
      );
    });

    test('a plain constant around a Row with Text', () async {
      expect(
        await lints(
          rule,
          widget(
            "const SizedBox(height: 40, child: Row(children: [Text('a')]))",
          ),
        ),
        ['SizedBox'],
      );
    });

    test('Container, RichText and TextField', () async {
      expect(
        await lints(
          rule,
          widget(
            'Column(children: [\n'
            "  Container(height: 56.h, child: Text.rich(TextSpan(text: 'a'))),\n"
            '  SizedBox(height: 48, child: RichText(text: TextSpan())),\n'
            '  SizedBox(height: 48, child: TextField()),\n'
            '])',
          ),
        ),
        ['Container', 'SizedBox', 'SizedBox'],
      );
    });

    test('only the innermost of nested fixed boxes', () async {
      final code = widget(
        'SizedBox(height: 100, child: Column(children: [\n'
        "  Container(height: 20, child: Text('a')),\n"
        ']))',
      );
      expect(await lints(rule, code), ['Container']);
    });
  });

  group('does not report', () {
    for (final entry in {
      'no text': 'SizedBox(height: 24.h, child: Icon(Icons.star))',
      'spacing': 'SizedBox(height: 16.h)',
      'width only': "SizedBox(width: 100, child: Text('a'))",
      'zero': "SizedBox(height: 0, child: Text('a'))",
      'infinity': "SizedBox(height: double.infinity, child: Text('a'))",
      'scrollable':
          "SizedBox(height: 100, child: ListView(children: [Text('a')]))",
      'FittedBox': "SizedBox(height: 32, child: FittedBox(child: Text('a')))",
      'named constructor': "SizedBox.square(dimension: 40, child: Text('a'))",
      'Container with constraints':
          "Container(height: 40, constraints: BoxConstraints(), child: Text('a'))",
      'FitBox': "FitBox(height: 48, child: Text('a'))",
    }.entries) {
      test(entry.key, () async {
        expect(await lints(rule, widget(entry.value)), isEmpty);
      });
    }
  });

  group('quick fix', () {
    test('SizedBox -> FitBox, strips .h', () async {
      expect(
        await applyFix(
          rule,
          widget("SizedBox(height: 48.h, child: Text('a'))"),
        ),
        widget("FitBox(height: 48, child: Text('a'))"),
      );
    });

    test('adds the fit_scale import when missing', () async {
      expect(
        await applyFix(
          rule,
          widget("SizedBox(height: 40, child: Text('a'))", imports: material),
        ),
        widget(
          "FitBox(height: 40, child: Text('a'))",
          imports: fitScale + material,
        ),
      );
    });

    test('keeps a Container and moves the height to FitBox', () async {
      expect(
        await applyFix(
          rule,
          widget(
            "Container(height: 56.h, color: Colors.red, child: Text('a'))",
          ),
        ),
        widget(
          'FitBox(height: 56, child: '
          "Container(color: Colors.red, child: Text('a')))",
        ),
      );
    });

    test('keeps the width of a SizedBox', () async {
      expect(
        await applyFix(
          rule,
          widget("SizedBox(width: 100, height: 48.h, child: Text('a'))"),
        ),
        widget(
          "FitBox(height: 48, child: SizedBox(width: 100, child: Text('a')))",
        ),
      );
    });

    test('a button inside keeps its touch target', () async {
      expect(
        await applyFix(
          rule,
          widget(
            "SizedBox(height: 48.h, child: FilledButton(onPressed: null, child: Text('a')))",
          ),
        ),
        widget(
          'FitBox(height: 48, interactive: true, '
          "child: FilledButton(onPressed: null, child: Text('a')))",
        ),
      );
    });

    test('an int variable becomes a double', () async {
      expect(
        await applyFix(
          rule,
          widget("SizedBox(height: n.h, child: Text('a'))"),
        ),
        widget("FitBox(height: n.toDouble(), child: Text('a'))"),
      );
    });
  });
}
