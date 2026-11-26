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

/// `SizedBox(height: 48.h, child: Text(...))`: the text grows with the
/// system font size, the box does not, so the text is cut off or
/// overflows on small screens and with large text.
class FixedHeightAroundText extends AnalysisRule {
  FixedHeightAroundText()
    : super(
        name: 'fixed_height_around_text',
        description:
            'A fixed height around text overflows when the system '
            'text size grows or the screen is small.',
      );

  static const LintCode code = LintCode(
    'fixed_height_around_text',
    'A fixed height around text overflows when the system text size grows '
        'or the screen is small.',
    correctionMessage:
        'Try FitBox(height: …) from fit_scale: a minimum '
        'height that grows with its content.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  /// The height argument of the box this rule reports on, or null.
  static NamedArg? heightArg(InstanceCreationExpression node) {
    if (!isHeightBox(node)) return null;
    final height = namedArg(node, 'height');
    if (height == null || !isFixedHeight(height.expression)) return null;
    // Container(constraints: ...) already says what it wants.
    if (namedArg(node, 'constraints') != null) return null;
    return childHoldsText(node) ? height : null;
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
    if (FixedHeightAroundText.heightArg(node) != null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `SizedBox(height: 48.h, child: c)` -> `FitBox(height: 48, child: c)`;
/// other boxes keep their other arguments inside a FitBox.
class UseFitBox extends ResolvedCorrectionProducer {
  UseFitBox({required super.context});

  static const _kind = FixKind(
    'fit_scale_lint.fix.useFitBox',
    DartFixKindPriority.standard,
    'Replace with FitBox',
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
    final height = FixedHeightAroundText.heightArg(box);
    if (height == null || !isUsableHeight(height.expression)) return;

    final scaled = scaledValue(height.expression, const {'h', 'r'});
    final design = scaled?.designValue ?? doubleSource(height.expression);
    final interactive = isTapBox(box);
    final content = unitResult.content;
    final names = argNames(box);
    final onlyHeightAndChild =
        isUnnamed(box, 'SizedBox') &&
        names != null &&
        const {'key', 'height', 'child'}.containsAll(names);

    await builder.addDartFileEdit(file, (builder) {
      final name = box.constructorName;
      if (onlyHeightAndChild) {
        builder.addSimpleReplacement(
          SourceRange(name.offset, name.length),
          'FitBox',
        );
        builder.addSimpleReplacement(
          SourceRange(height.offset, height.length),
          'height: $design${interactive ? ', interactive: true' : ''}',
        );
      } else {
        // Keep the box for its other arguments and let FitBox own the
        // height: FitBox(height: 48, child: Container(color: ...)).
        final inner = withoutArg(
          content,
          box,
          height,
        ).substring(name.offset - box.offset);
        builder.addSimpleReplacement(
          SourceRange(name.offset, box.end - name.offset),
          'FitBox(height: $design, '
          '${interactive ? 'interactive: true, ' : ''}child: $inner)',
        );
      }
      ensureFitScaleImport(builder, unit);
    });
  }
}
