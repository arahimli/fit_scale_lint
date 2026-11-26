import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

import 'stubs.dart' as stubs;

const material = "import 'package:flutter/material.dart';\n";
const fitExtensions = "import 'package:fit_scale/extensions.dart';\n";
const fitScale = "import 'package:fit_scale/fit_scale.dart';\n";
const screenUtil =
    "import 'package:flutter_screenutil/flutter_screenutil.dart';\n";

/// Wraps [expression] in a function so it can be written on its own.
String widget(String expression, {String imports = material + fitExtensions}) =>
    '${imports}Widget build(int n) => $expression;\n';

typedef FixConstructor =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

/// A rule test with stub Flutter, fit_scale and flutter_screenutil
/// packages, and helpers that work with source text instead of offsets.
abstract class FitRuleTest extends AnalysisRuleTest {
  AnalysisRule createRule();

  @override
  void setUp() {
    rule = createRule();
    newPackage('flutter')
      ..addFile('lib/widgets.dart', stubs.flutterWidgets)
      ..addFile('lib/src/ui.dart', stubs.flutterUi)
      ..addFile('lib/material.dart', stubs.flutterMaterial);
    newPackage('fit_scale')
      ..addFile('lib/fit_scale.dart', stubs.fitScale)
      ..addFile('lib/extensions.dart', stubs.fitExtensions);
    newPackage(
      'flutter_screenutil',
    ).addFile('lib/flutter_screenutil.dart', stubs.screenUtil);
    super.setUp();
  }

  Future<ResolvedUnitResult> _resolve(String code) async {
    newFile(testFile.path, code);
    final result = await resolveFile(testFile.path);
    final errors = result.diagnostics.where(
      (d) =>
          d.severity == Severity.error &&
          // Tests that keep both screenutil and fit_scale imported.
          !d.diagnosticCode.lowerCaseName.contains('ambiguous'),
    );
    if (errors.isNotEmpty) {
      throw StateError('Test source does not compile: $errors\n$code');
    }
    return result;
  }

  List<Diagnostic> _lints(ResolvedUnitResult result) => result.diagnostics
      .where((d) => d.diagnosticCode.lowerCaseName == rule.name)
      .toList();

  /// The source text each lint of the rule in [code] points at.
  Future<List<String>> lints(String code) async {
    final result = await _resolve(code);
    return [
      for (final d in _lints(result))
        code.substring(d.offset, d.offset + d.length),
    ];
  }

  /// [code] after [fix] for the first lint of the rule, or null when the
  /// fix offers no change there.
  Future<String?> applyFix(FixConstructor fix, String code) async {
    final result = await _resolve(code);
    final lints = _lints(result);
    if (lints.isEmpty) throw StateError('No lint to fix in:\n$code');
    final diagnostic = lints.first;
    final library =
        await result.session.getResolvedLibrary(result.path)
            as ResolvedLibraryResult;
    final context = CorrectionProducerContext.createResolved(
      libraryResult: library,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
      selectionLength: diagnostic.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await fix(context: context).compute(builder);
    final edits = builder.sourceChange.edits;
    if (edits.isEmpty) return null;
    return SourceEdit.applySequence(code, edits.single.edits);
  }
}
