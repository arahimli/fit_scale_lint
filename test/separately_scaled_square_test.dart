// Test methods are named test_* for test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SeparatelyScaledSquareTest);
  });
}

@reflectiveTest
class SeparatelyScaledSquareTest extends FitRuleTest {
  @override
  AnalysisRule createRule() => SeparatelyScaledSquare();

  Future<void> test_reports() async {
    expect(
      await lints(
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
  }

  Future<void> test_noReport() async {
    for (final code in [
      'SizedBox(width: 120.w, height: 48.h)',
      'SizedBox(width: 56.r, height: 56.r)',
      'SizedBox(width: 56.w, height: 56.w)',
      'SizedBox(width: 56, height: 56)',
    ]) {
      expect(await lints(widget(code)), isEmpty, reason: code);
    }
  }

  Future<void> test_fix_fitSquare() async {
    expect(
      await applyFix(
        UseFitSquare.new,
        widget('SizedBox(width: 56.w, height: 56.h, child: CircleAvatar())'),
      ),
      widget('FitSquare(size: 56, child: CircleAvatar())'),
    );
  }

  Future<void> test_fix_fitSquareAddsImportKeepsKey() async {
    expect(
      await applyFix(
        UseFitSquare.new,
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
  }

  Future<void> test_fix_fitSquareNotForContainer() async {
    expect(
      await applyFix(
        UseFitSquare.new,
        widget('Container(width: n.w, height: n.h)'),
      ),
      isNull,
    );
  }

  Future<void> test_fix_r() async {
    expect(
      await applyFix(
        ScaleBothSidesWithR.new,
        widget('Container(width: n.w, height: n.h)'),
      ),
      widget('Container(width: n.r, height: n.r)'),
    );
  }
}
