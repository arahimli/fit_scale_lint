import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../fix_utils.dart';

/// `import 'package:flutter_screenutil/flutter_screenutil.dart';`
///
/// fit_scale's extensions have the same names (`.w .h .r .sp .sw .sh`) but
/// clamp the scale factors, so swapping the import is the first step of a
/// migration.
class ScreenutilImport extends AnalysisRule {
  ScreenutilImport()
    : super(
        name: 'screenutil_import',
        description:
            'flutter_screenutil scales without limits: fixed '
            'heights overflow and touch targets shrink on small screens.',
      );

  static const LintCode code = LintCode(
    'screenutil_import',
    'flutter_screenutil scales without limits: fixed heights overflow and '
        'touch targets shrink on small screens.',
    correctionMessage:
        "Try 'package:fit_scale/extensions.dart' (same "
        '.w/.h/.r/.sp names) and FitScaleScope instead of ScreenUtilInit.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  LintCode get diagnosticCode => code;

  static bool matches(ImportDirective node) =>
      node.uri.stringValue?.startsWith(screenUtilPackage) ?? false;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitImportDirective(ImportDirective node) {
    if (ScreenutilImport.matches(node)) rule.reportAtNode(node.uri);
  }
}

/// Swaps the import for fit_scale's extensions, or removes it when those
/// are already imported.
class UseFitExtensions extends ResolvedCorrectionProducer {
  UseFitExtensions({required super.context});

  static const _kind = FixKind(
    'fit_scale_lint.fix.useFitExtensions',
    DartFixKindPriority.standard,
    "Import 'package:fit_scale/extensions.dart' instead",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final offset = diagnostic?.offset;
    ImportDirective? import;
    for (final d in unit.directives) {
      if (d is ImportDirective && d.uri.offset == offset) import = d;
    }
    if (import == null || !ScreenutilImport.matches(import)) return;
    final directive = import;
    final alreadyImported = unit.directives.any(
      (d) => d is ImportDirective && d.uri.stringValue == fitExtensionsUri,
    );

    await builder.addDartFileEdit(file, (builder) {
      if (alreadyImported) {
        // The whole line, so no blank line is left behind.
        final end = unit.lineInfo.getOffsetOfLineAfter(directive.end);
        builder.addDeletion(
          SourceRange(directive.offset, end - directive.offset),
        );
      } else {
        builder.addSimpleReplacement(
          SourceRange(directive.uri.offset, directive.uri.length),
          "'$fitExtensionsUri'",
        );
      }
    });
  }
}
