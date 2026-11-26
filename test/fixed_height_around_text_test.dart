// Test methods are named test_* for test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixedHeightAroundTextTest);
  });
}

@reflectiveTest
class FixedHeightAroundTextTest extends FitRuleTest {
  @override
  AnalysisRule createRule() => FixedHeightAroundText();

  Future<void> test_reports_sizedBoxWithH() async {
    expect(await lints(widget("SizedBox(height: 48.h, child: Text('a'))")), [
      'SizedBox',
    ]);
  }

  Future<void> test_reports_plainConstantAroundRow() async {
    expect(
      await lints(
        widget("const SizedBox(height: 40, child: Row(children: [Text('a')]))"),
      ),
      ['SizedBox'],
    );
  }

  Future<void> test_reports_containerRichTextTextField() async {
    expect(
      await lints(
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
  }

  Future<void> test_reports_onlyInnermostNestedBox() async {
    expect(
      await lints(
        widget(
          'SizedBox(height: 100, child: Column(children: [\n'
          "  Container(height: 20, child: Text('a')),\n"
          ']))',
        ),
      ),
      ['Container'],
    );
  }

  Future<void> test_noReport() async {
    for (final code in [
      'SizedBox(height: 24.h, child: Icon(Icons.star))',
      'SizedBox(height: 16.h)',
      "SizedBox(width: 100, child: Text('a'))",
      "SizedBox(height: 0, child: Text('a'))",
      "SizedBox(height: double.infinity, child: Text('a'))",
      "SizedBox(height: 100, child: ListView(children: [Text('a')]))",
      "SizedBox(height: 32, child: FittedBox(child: Text('a')))",
      "SizedBox.square(dimension: 40, child: Text('a'))",
      "Container(height: 40, constraints: BoxConstraints(), child: Text('a'))",
      "FitBox(height: 48, child: Text('a'))",
    ]) {
      expect(await lints(widget(code)), isEmpty, reason: code);
    }
  }

  Future<void> test_noReport_layoutHeight() async {
    const code =
        "${material}Widget build(Size size) => "
        "Container(height: size.height, child: Text('a'));\n";
    expect(await lints(code), isEmpty);
  }

  Future<void> test_fix_sizedBoxToFitBox() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget("SizedBox(height: 48.h, child: Text('a'))"),
      ),
      widget("FitBox(height: 48, child: Text('a'))"),
    );
  }

  Future<void> test_fix_addsImport() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget("SizedBox(height: 40, child: Text('a'))", imports: material),
      ),
      widget(
        "FitBox(height: 40, child: Text('a'))",
        imports: fitScale + material,
      ),
    );
  }

  Future<void> test_fix_keepsContainer() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget("Container(height: 56.h, color: Colors.red, child: Text('a'))"),
      ),
      widget(
        'FitBox(height: 56, child: '
        "Container(color: Colors.red, child: Text('a')))",
      ),
    );
  }

  Future<void> test_fix_keepsWidth() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget("SizedBox(width: 100, height: 48.h, child: Text('a'))"),
      ),
      widget(
        "FitBox(height: 48, child: SizedBox(width: 100, child: Text('a')))",
      ),
    );
  }

  Future<void> test_fix_buttonKeepsTouchTarget() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget(
          'SizedBox(height: 48.h, '
          "child: FilledButton(onPressed: null, child: Text('a')))",
        ),
      ),
      widget(
        'FitBox(height: 48, interactive: true, '
        "child: FilledButton(onPressed: null, child: Text('a')))",
      ),
    );
  }

  Future<void> test_fix_intVariableBecomesDouble() async {
    expect(
      await applyFix(
        UseFitBox.new,
        widget("SizedBox(height: n.h, child: Text('a'))"),
      ),
      widget("FitBox(height: n.toDouble(), child: Text('a'))"),
    );
  }
}
