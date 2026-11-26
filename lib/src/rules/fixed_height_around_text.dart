import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../ast_utils.dart';
import '../fix_utils.dart';

/// `SizedBox(height: 48.h, child: Text(...))`: the text grows with the
/// system font size, the box does not, so the text is cut off or
/// overflows on small screens and with large text.
class FixedHeightAroundText extends DartLintRule {
  const FixedHeightAroundText() : super(code: _code);

  static const _code = LintCode(
    name: 'fixed_height_around_text',
    problemMessage:
        'A fixed height around text overflows when the system text size '
        'grows or the screen is small.',
    correctionMessage:
        'Use FitBox(height: …) from fit_scale: a minimum height that grows '
        'with its content.',
    errorSeverity: ErrorSeverity.WARNING,
    url: 'https://pub.dev/packages/fit_scale_lint#fixed_height_around_text',
  );

  /// The box this rule reports on, or null.
  static NamedExpression? heightArg(InstanceCreationExpression node) {
    if (!isUnnamed(sizedBoxChecker, node) &&
        !isUnnamed(containerChecker, node)) {
      return null;
    }
    final height = namedArg(node, 'height');
    if (height == null || !isFixedHeight(height.expression)) return null;
    // Container(constraints: ...) already says what it wants.
    if (namedArg(node, 'constraints') != null) return null;
    return childHoldsText(node) ? height : null;
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (heightArg(node) != null) {
        reporter.atNode(node.constructorName, _code);
      }
    });
  }

  @override
  List<Fix> getFixes() => [_UseFitBox()];
}

class _UseFitBox extends ContentFix {
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
      final height = FixedHeightAroundText.heightArg(node);
      if (height == null || !isUsableHeight(height.expression)) return;

      final scaled = scaledValue(height.expression, const {'h', 'r'});
      final design = scaled?.designValue ?? doubleSource(height.expression);
      final interactive = isTapBox(node) ? 'interactive: true, ' : '';
      final unit = node.root as CompilationUnit;

      final change = reporter.createChangeBuilder(
        message: 'Replace with FitBox',
        priority: 80,
      );
      final content = this.content(context);
      change.addDartFileEdit((builder) {
        final onlyHeightAndChild = isUnnamed(sizedBoxChecker, node) &&
            node.argumentList.arguments.every(
              (a) =>
                  a is NamedExpression &&
                  const {'key', 'height', 'child'}.contains(a.name.label.name),
            );
        if (onlyHeightAndChild) {
          // SizedBox(height: 48.h, child: c) -> FitBox(height: 48, child: c)
          builder.addSimpleReplacement(
            SourceRange(
                node.constructorName.offset, node.constructorName.length),
            'FitBox',
          );
          builder.addSimpleReplacement(
            SourceRange(height.offset, height.length),
            'height: $design${interactive.isEmpty ? '' : ', interactive: true'}',
          );
        } else {
          // Keep the box for its other arguments and let FitBox own the
          // height: FitBox(height: 48, child: Container(color: ...)).
          final start = node.constructorName.offset;
          final inner =
              withoutArg(content, node, height).substring(start - node.offset);
          builder.addSimpleReplacement(
            SourceRange(start, node.end - start),
            'FitBox(height: $design, ${interactive}child: $inner)',
          );
        }
        ensureFitScaleImport(builder, unit);
      });
    });
  }
}
