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
import 'fixed_height_around_text.dart';

/// `SizedBox(height: 40.h, child: IconButton(...))`: `.h` follows the
/// screen height, so on a short screen the touch target drops below the
/// 48 px (Android) / 44 pt (iOS) minimum.
class TapHeightWithH extends AnalysisRule {
  TapHeightWithH()
    : super(
        name: 'tap_height_with_h',
        description:
            'A touch target sized with .h can shrink below 48 px '
            '(44 pt on iOS) on short screens.',
      );

  static const LintCode code = LintCode(
    'tap_height_with_h',
    'A touch target sized with .h can shrink below 48 px (44 pt on iOS) on '
        'short screens.',
    correctionMessage:
        'Try .tap from fit_scale: the uniform scale, never '
        'below the platform minimum.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  /// Height arguments of tap widgets themselves.
  static const _tapHeightArgs = {
    'height', // MaterialButton
    'minHeight',
    'minTileHeight', // ListTile
    'minSize', // CupertinoButton (before 3.27)
    'minimumSize', // CupertinoButton (3.27+)
  };

  /// `styleFrom(minimumSize: Size(w, 48.h))` and friends.
  static const _sizeArgs = {'minimumSize', 'fixedSize'};

  void _report(Expression? e) {
    final scaled = scaledValue(e, const {'h'});
    if (scaled != null) rule.reportAtNode(scaled.node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // A box around a button, or inside a tappable area. Text inside it is
    // reported by fixed_height_around_text, whose fix also keeps the touch
    // target, so the same box is not reported twice.
    if (isHeightBox(node)) {
      if (isTapBox(node) && FixedHeightAroundText.heightArg(node) == null) {
        _report(namedArg(node, 'height')?.expression);
      }
      return;
    }
    // A height argument of the tap widget itself.
    if (isTapWidget(node)) {
      for (final name in _tapHeightArgs) {
        final value = namedArg(node, name)?.expression;
        _report(value);
        if (value is InstanceCreationExpression) _reportSize(value);
      }
    }
  }

  // ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48.h))
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'styleFrom') return;
    for (final AstNode arg in node.argumentList.arguments) {
      final named = asNamedArg(arg);
      if (named != null && _sizeArgs.contains(named.name)) {
        final value = named.expression;
        if (value is InstanceCreationExpression) _reportSize(value);
      }
    }
  }

  /// The height of `Size(w, h)` / `Size.fromHeight(h)` / `Size.square(s)`.
  void _reportSize(InstanceCreationExpression size) {
    final type = size.constructorName.type.toSource();
    if (type != 'Size' && !type.endsWith('.Size')) return;
    final args = positional(argsOf(size));
    if (args.length != size.argumentList.arguments.length) return;
    final ctor = size.constructorName.name?.name;
    if (ctor == null && args.length == 2) _report(args[1]);
    if ((ctor == 'fromHeight' || ctor == 'square') && args.length == 1) {
      _report(args[0]);
    }
  }
}

/// `40.h` -> `40.tap`, importing fit_scale's extensions.
class UseTap extends ResolvedCorrectionProducer {
  UseTap({required super.context});

  static const _kind = FixKind(
    'fit_scale_lint.fix.useTap',
    DartFixKindPriority.standard,
    'Use .tap',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final diagnostic = this.diagnostic;
    if (diagnostic == null) return;
    AstNode? current = node;
    ScaledValue? scaled;
    while (current != null && scaled == null) {
      if (current is Expression &&
          current.offset == diagnostic.offset &&
          current.length == diagnostic.length) {
        scaled = scaledValue(current, const {'h'});
      }
      current = current.parent;
    }
    if (scaled == null) return;
    final suffix = scaled.suffix;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(suffix.offset, suffix.length),
        'tap',
      );
      ensureFitExtensionsImport(builder, unit);
    });
  }
}
