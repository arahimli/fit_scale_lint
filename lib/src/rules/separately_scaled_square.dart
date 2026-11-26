import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../ast_utils.dart';
import '../fix_utils.dart';

/// `width: 56.w, height: 56.h`: width and height scale by different
/// factors, so the square becomes a rectangle (and a circle an oval) as
/// soon as the screen's proportions differ from the design.
class SeparatelyScaledSquare extends DartLintRule {
  const SeparatelyScaledSquare() : super(code: _code);

  static const _code = LintCode(
    name: 'separately_scaled_square',
    problemMessage:
        'The same size scaled with .w for width and .h for height is not '
        'square on other aspect ratios.',
    correctionMessage:
        'Use FitSquare(size: …) from fit_scale, or .r for both sides.',
    errorSeverity: ErrorSeverity.WARNING,
    url: 'https://pub.dev/packages/fit_scale_lint#separately_scaled_square',
  );

  /// The `(width, height)` pair this rule reports on, or null.
  static (ScaledValue, ScaledValue)? square(InstanceCreationExpression node) {
    final width = scaledValue(namedArg(node, 'width')?.expression, {'w'});
    final height = scaledValue(namedArg(node, 'height')?.expression, {'h'});
    if (width == null || height == null) return null;
    if (width.target.toSource() != height.target.toSource()) return null;
    return (width, height);
  }

  /// Whether [node] is a `SizedBox` that `FitSquare` can replace as is.
  ///
  static bool fitsFitSquare(InstanceCreationExpression node) {
    if (!isUnnamed(sizedBoxChecker, node)) return false;
    final args = node.argumentList.arguments;
    final names = {
      for (final a in args)
        if (a is NamedExpression) a.name.label.name,
    };
    return names.length == args.length &&
        const {'key', 'width', 'height', 'child'}.containsAll(names);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (square(node) != null) {
        reporter.atNode(node.constructorName, _code);
      }
    });
  }

  @override
  List<Fix> getFixes() => [_MakeSquare()];
}

/// FitSquare for a plain SizedBox, `.r` on both sides for anything else.
///
/// One fix class: `dart run custom_lint --fix` reruns a single fix across
/// every lint of a rule, and applies every fix a lint offers.
class _MakeSquare extends ContentFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.offset != analysisError.offset) return;
      final pair = SeparatelyScaledSquare.square(node);
      if (pair == null) return;
      if (SeparatelyScaledSquare.fitsFitSquare(node)) {
        _fitSquare(reporter, content(context), node, pair.$1);
      } else {
        _useR(reporter, [pair.$1, pair.$2]);
      }
    });
  }

  void _fitSquare(
    ChangeReporter reporter,
    String content,
    InstanceCreationExpression node,
    ScaledValue width,
  ) {
    final key = namedArg(node, 'key');
    final child = namedArg(node, 'child');
    final unit = node.root as CompilationUnit;
    final change = reporter.createChangeBuilder(
      message: 'Replace with FitSquare',
      priority: 80,
    );
    change.addDartFileEdit((builder) {
      final parts = [
        if (key != null) textOf(content, key),
        'size: ${width.designValue}',
        if (child != null) textOf(content, child),
      ];
      final start = node.constructorName.offset;
      builder.addSimpleReplacement(
        SourceRange(start, node.end - start),
        'FitSquare(${parts.join(', ')})',
      );
      ensureFitScaleImport(builder, unit);
    });
  }

  void _useR(ChangeReporter reporter, List<ScaledValue> sides) {
    final change = reporter.createChangeBuilder(
      message: 'Scale both sides with .r',
      priority: 80,
    );
    change.addDartFileEdit((builder) {
      for (final side in sides) {
        builder.addSimpleReplacement(
          SourceRange(side.suffix.offset, side.suffix.length),
          'r',
        );
      }
    });
  }
}
