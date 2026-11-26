import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../fix_utils.dart';

/// `import 'package:flutter_screenutil/flutter_screenutil.dart';`
///
/// fit_scale's extensions have the same names (`.w .h .r .sp .sw .sh`)
/// but clamp the scale factors, so swapping the import is the first step
/// of a migration.
class ScreenutilImport extends DartLintRule {
  const ScreenutilImport() : super(code: _code);

  static const _code = LintCode(
    name: 'screenutil_import',
    problemMessage:
        'flutter_screenutil scales without limits: fixed heights overflow '
        'and touch targets shrink on small screens.',
    correctionMessage:
        "Import 'package:fit_scale/extensions.dart' (same .w/.h/.r/.sp "
        'names) and replace ScreenUtilInit with FitScaleScope.',
    errorSeverity: ErrorSeverity.INFO,
    url: 'https://pub.dev/packages/fit_scale_lint#screenutil_import',
  );

  static bool _matches(ImportDirective node) =>
      node.uri.stringValue?.startsWith(screenUtilPackage) ?? false;

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      if (_matches(node)) reporter.atNode(node.uri, _code);
    });
  }

  @override
  List<Fix> getFixes() => [_UseFitExtensions()];
}

class _UseFitExtensions extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((node) {
      if (node.uri.offset != analysisError.offset ||
          !ScreenutilImport._matches(node)) {
        return;
      }
      final unit = node.parent! as CompilationUnit;
      final alreadyImported = unit.directives.any(
        (d) => d is ImportDirective && d.uri.stringValue == fitExtensionsUri,
      );
      final change = reporter.createChangeBuilder(
        message: alreadyImported
            ? 'Remove the flutter_screenutil import'
            : "Import 'package:fit_scale/extensions.dart' instead",
        priority: 80,
      );
      change.addDartFileEdit((builder) {
        if (alreadyImported) {
          // The whole line, so no blank line is left behind.
          final end = unit.lineInfo.getOffsetOfLineAfter(node.end);
          builder.addDeletion(SourceRange(node.offset, end - node.offset));
        } else {
          builder.addSimpleReplacement(
            SourceRange(node.uri.offset, node.uri.length),
            "'$fitExtensionsUri'",
          );
        }
      });
    });
  }
}
