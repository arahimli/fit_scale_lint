// Test methods are named test_* for test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ScreenutilImportTest);
  });
}

const _body = 'Widget build() => SizedBox(height: 16.h);\n';

@reflectiveTest
class ScreenutilImportTest extends FitRuleTest {
  @override
  AnalysisRule createRule() => ScreenutilImport();

  Future<void> test_reports() async {
    expect(await lints(material + screenUtil + _body), [
      "'package:flutter_screenutil/flutter_screenutil.dart'",
    ]);
  }

  Future<void> test_noReport_fitScale() async {
    expect(await lints(material + fitExtensions + _body), isEmpty);
  }

  Future<void> test_fix_swapsImport() async {
    expect(
      await applyFix(UseFitExtensions.new, material + screenUtil + _body),
      material + fitExtensions + _body,
    );
  }

  Future<void> test_fix_removesWhenFitScaleImported() async {
    expect(
      await applyFix(
        UseFitExtensions.new,
        material + fitExtensions + screenUtil + _body,
      ),
      material + fitExtensions + _body,
    );
  }
}
