import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../ast_utils.dart';
import '../fix_utils.dart';
import 'fixed_height_around_text.dart';

/// `SizedBox(height: 40.h, child: IconButton(...))`: `.h` follows the
/// screen height, so on a short screen the touch target drops below the
/// 48 px (Android) / 44 pt (iOS) minimum.
class TapHeightWithH extends DartLintRule {
  const TapHeightWithH() : super(code: _code);

  static const _code = LintCode(
    name: 'tap_height_with_h',
    problemMessage:
        'A touch target sized with .h can shrink below 48 px (44 pt on iOS) '
        'on short screens.',
    correctionMessage:
        'Use .tap from fit_scale: the uniform scale, never below the '
        'platform minimum.',
    errorSeverity: ErrorSeverity.WARNING,
    url: 'https://pub.dev/packages/fit_scale_lint#tap_height_with_h',
  );

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

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    void report(Expression? e) {
      final scaled = scaledValue(e, const {'h'});
      if (scaled != null) reporter.atNode(scaled.node, _code);
    }

    context.registry.addInstanceCreationExpression((node) {
      // A box around a button, or inside a tappable area. Text inside it
      // is reported by fixed_height_around_text, whose fix also keeps the
      // touch target, so do not report the same box twice.
      if (isUnnamed(sizedBoxChecker, node) ||
          isUnnamed(containerChecker, node)) {
        if (isTapBox(node) && FixedHeightAroundText.heightArg(node) == null) {
          report(namedArg(node, 'height')?.expression);
        }
        return;
      }
      // A height argument of the tap widget itself.
      if (isTapWidget(node)) {
        for (final name in _tapHeightArgs) {
          final value = namedArg(node, name)?.expression;
          report(value);
          if (value is InstanceCreationExpression) _reportSize(value, report);
        }
      }
    });

    // ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48.h))
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'styleFrom') return;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && _sizeArgs.contains(arg.name.label.name)) {
          final value = arg.expression;
          if (value is InstanceCreationExpression) _reportSize(value, report);
        }
      }
    });
  }

  /// The height of `Size(w, h)` / `Size.fromHeight(h)` / `Size.square(s)`.
  static void _reportSize(
    InstanceCreationExpression size,
    void Function(Expression?) report,
  ) {
    final type = size.constructorName.type.toSource();
    if (type != 'Size' && !type.endsWith('.Size')) return;
    final args = size.argumentList.arguments;
    final ctor = size.constructorName.name?.name;
    if (ctor == null && args.length == 2) report(args[1]);
    if ((ctor == 'fromHeight' || ctor == 'square') && args.length == 1) {
      report(args[0]);
    }
  }

  @override
  List<Fix> getFixes() => [_UseTap()];
}

class _UseTap extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    void fix(Expression node) {
      if (node.offset != analysisError.offset ||
          node.length != analysisError.length) {
        return;
      }
      final scaled = scaledValue(node, const {'h'});
      if (scaled == null) return;
      final unit = node.root as CompilationUnit;
      final change = reporter.createChangeBuilder(
        message: 'Use .tap',
        priority: 80,
      );
      change.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(scaled.suffix.offset, scaled.suffix.length),
          'tap',
        );
        ensureFitExtensionsImport(builder, unit);
      });
    }

    context.registry.addPropertyAccess(fix);
    context.registry.addPrefixedIdentifier(fix);
  }
}
