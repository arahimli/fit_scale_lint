// Test methods are named test_* for test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fit_scale_lint/fit_scale_lint.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TapHeightWithHTest);
  });
}

const _button = 'IconButton(onPressed: null, icon: Icon(Icons.add))';

@reflectiveTest
class TapHeightWithHTest extends FitRuleTest {
  @override
  AnalysisRule createRule() => TapHeightWithH();

  Future<void> test_reports_boxAroundButton() async {
    expect(await lints(widget('SizedBox(height: 40.h, child: $_button)')), [
      '40.h',
    ]);
  }

  Future<void> test_reports_boxInsideTappableThroughPadding() async {
    expect(
      await lints(
        widget(
          'InkWell(onTap: null, child: Padding(padding: EdgeInsets.zero, '
          'child: SizedBox(height: n.h, child: Icon(Icons.close))))',
        ),
      ),
      ['n.h'],
    );
  }

  Future<void> test_reports_styleAndButtonArguments() async {
    expect(
      await lints(
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
  }

  Future<void> test_noReport() async {
    for (final code in [
      'SizedBox(height: 40.h, child: Icon(Icons.star))',
      'SizedBox(height: 40.tap, child: $_button)',
      'SizedBox(height: 40.r, child: $_button)',
      'SizedBox(width: 40.w, child: $_button)',
      // Reported by fixed_height_around_text, whose fix keeps the target.
      "SizedBox(height: 48.h, child: FilledButton(onPressed: null, child: Text('Pay')))",
      'ElevatedButton(style: ElevatedButton.styleFrom('
          'minimumSize: Size(44.h, 48)), onPressed: null)',
    ]) {
      expect(await lints(widget(code)), isEmpty, reason: code);
    }
  }

  Future<void> test_fix_tap() async {
    expect(
      await applyFix(
        UseTap.new,
        widget('SizedBox(height: 40.h, child: $_button)'),
      ),
      widget('SizedBox(height: 40.tap, child: $_button)'),
    );
  }

  Future<void> test_fix_swapsScreenutilImport() async {
    expect(
      await applyFix(
        UseTap.new,
        widget(
          'SizedBox(height: 40.h, child: $_button)',
          imports: material + screenUtil,
        ),
      ),
      widget(
        'SizedBox(height: 40.tap, child: $_button)',
        imports: material + fitExtensions,
      ),
    );
  }
}
