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

import '../ast_utils.dart';
import '../fix_utils.dart';

/// `width: 56.w, height: 56.h`: width and height scale by different
/// factors, so the square becomes a rectangle (and a circle an oval) as
/// soon as the screen's proportions differ from the design.
class SeparatelyScaledSquare extends AnalysisRule {
  SeparatelyScaledSquare()
    : super(
        name: 'separately_scaled_square',
        description:
            'The same size scaled with .w for width and .h for '
            'height is not square on other aspect ratios.',
      );

  static const LintCode code = LintCode(
    'separately_scaled_square',
    'The same size scaled with .w for width and .h for height is not square '
        'on other aspect ratios.',
    correctionMessage:
        'Try FitSquare(size: …) from fit_scale, or .r for both sides.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  /// The `(width, height)` pair this rule reports on, or null.
  static (ScaledValue, ScaledValue)? square(InstanceCreationExpression node) {
    final width = scaledValue(namedArg(node, 'width')?.expression, {'w'});
    final height = scaledValue(namedArg(node, 'height')?.expression, {'h'});
    if (width == null || height == null) return null;
    if (width.target.toSource() != height.target.toSource()) return null;
    return (width, height);
  }

  /// Whether [node] is a `SizedBox` that `FitSquare` can replace as is.
  static bool fitsFitSquare(InstanceCreationExpression node) {
    if (!isUnnamed(node, 'SizedBox')) return false;
    final names = argNames(node);
    return names != null &&
        const {'key', 'width', 'height', 'child'}.containsAll(names);
  }

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (SeparatelyScaledSquare.square(node) != null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `SizedBox(width: 56.w, height: 56.h)` -> `FitSquare(size: 56)`.
class UseFitSquare extends ResolvedCorrectionProducer {
  UseFitSquare({required super.context});

  static const _kind = FixKind(
    'fit_scale_lint.fix.useFitSquare',
    DartFixKindPriority.standard,
    'Replace with FitSquare',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final offset = diagnostic?.offset;
    if (offset == null) return;
    final box = creationAt(node, offset);
    if (box == null || !SeparatelyScaledSquare.fitsFitSquare(box)) return;
    final pair = SeparatelyScaledSquare.square(box);
    if (pair == null) return;
    final content = unitResult.content;
    final key = namedArg(box, 'key');
    final child = namedArg(box, 'child');

    await builder.addDartFileEdit(file, (builder) {
      final parts = [
        if (key != null) textOf(content, key.node),
        'size: ${pair.$1.designValue}',
        if (child != null) textOf(content, child.node),
      ];
      final start = box.constructorName.offset;
      builder.addSimpleReplacement(
        SourceRange(start, box.end - start),
        'FitSquare(${parts.join(', ')})',
      );
      ensureFitScaleImport(builder, unit);
    });
  }
}

/// `width: n.w, height: n.h` -> `width: n.r, height: n.r`.
class ScaleBothSidesWithR extends ResolvedCorrectionProducer {
  ScaleBothSidesWithR({required super.context});

  static const _kind = FixKind(
    'fit_scale_lint.fix.scaleBothSidesWithR',
    DartFixKindPriority.standard - 1,
    'Scale both sides with .r',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final offset = diagnostic?.offset;
    if (offset == null) return;
    final box = creationAt(node, offset);
    if (box == null) return;
    final pair = SeparatelyScaledSquare.square(box);
    if (pair == null) return;

    await builder.addDartFileEdit(file, (builder) {
      for (final side in [pair.$1, pair.$2]) {
        builder.addSimpleReplacement(
          SourceRange(side.suffix.offset, side.suffix.length),
          'r',
        );
      }
    });
  }
}
