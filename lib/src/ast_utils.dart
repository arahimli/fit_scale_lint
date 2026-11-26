// Helpers shared by the rules.
//
// Only AST APIs that are the same in analyzer 6, 7 and 8 are used here
// (no element model), so one release works on Flutter 3.24 through the
// latest stable. Types are matched with custom_lint's TypeChecker, which
// hides the element-model differences.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

TypeChecker _flutter(String name) =>
    TypeChecker.fromName(name, packageName: 'flutter');

/// `SizedBox` (unnamed constructor only; `SizedBox.shrink` etc. are fine).
final sizedBoxChecker = _flutter('SizedBox');

/// `Container`.
final containerChecker = _flutter('Container');

/// Widgets whose height grows with the system text size.
final textChecker = TypeChecker.any([
  _flutter('Text'),
  _flutter('RichText'),
  _flutter('SelectableText'),
  _flutter('TextField'),
  _flutter('TextFormField'),
  _flutter('CupertinoTextField'),
]);

/// Widgets the user taps: buttons, tiles and gesture wrappers.
final tapChecker = TypeChecker.any([
  _flutter('ButtonStyleButton'), // Elevated/Filled/Outlined/TextButton
  _flutter('IconButton'),
  _flutter('FloatingActionButton'),
  _flutter('MaterialButton'),
  _flutter('RawMaterialButton'),
  _flutter('CupertinoButton'),
  _flutter('ListTile'),
  _flutter('CheckboxListTile'),
  _flutter('SwitchListTile'),
  _flutter('RadioListTile'),
  _flutter('InkResponse'), // and InkWell
  _flutter('GestureDetector'),
]);

/// Single-child wrappers that do not change what the child is.
final _wrapperChecker = TypeChecker.any([
  _flutter('Padding'),
  _flutter('Center'),
  _flutter('Align'),
  _flutter('Expanded'),
  _flutter('Flexible'),
  _flutter('Semantics'),
]);

/// Subtrees below these never overflow a fixed height: they scroll or
/// scale their content down.
final _stopChecker = TypeChecker.any([
  _flutter('ListView'),
  _flutter('GridView'),
  _flutter('PageView'),
  _flutter('SingleChildScrollView'),
  _flutter('CustomScrollView'),
  _flutter('FittedBox'),
  _flutter('OverflowBox'),
  TypeChecker.fromName('FitText', packageName: 'fit_scale'),
  TypeChecker.fromName('FitBox', packageName: 'fit_scale'),
]);

bool _is(TypeChecker checker, InstanceCreationExpression node) {
  final type = node.staticType;
  return type != null && checker.isExactlyType(type);
}

bool _isAssignable(TypeChecker checker, InstanceCreationExpression node) {
  final type = node.staticType;
  return type != null && checker.isAssignableFromType(type);
}

/// Whether [node] is the unnamed constructor of a class matched by
/// [checker], such as `SizedBox(...)` but not `SizedBox.square(...)`.
bool isUnnamed(TypeChecker checker, InstanceCreationExpression node) =>
    node.constructorName.name == null && _is(checker, node);

bool isTapWidget(InstanceCreationExpression node) =>
    _isAssignable(tapChecker, node);

/// The named argument [name] of [node], or null.
NamedExpression? namedArg(InstanceCreationExpression node, String name) {
  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return arg;
  }
  return null;
}

/// A `value.h` / `value.w` / ... extension access on a number.
class ScaledValue {
  ScaledValue(this.node, this.target, this.suffix);

  /// The whole `56.h` expression.
  final Expression node;

  /// The number being scaled (`56`).
  final Expression target;

  /// The extension getter (`h`).
  final SimpleIdentifier suffix;

  /// [target] as source that can be passed where a `double` is expected.
  String get designValue => doubleSource(target);
}

/// Returns the `56.h` parts of [e] when [e] is `<number>.<suffix>` with a
/// suffix in [suffixes].
ScaledValue? scaledValue(Expression? e, Set<String> suffixes) {
  if (e is PropertyAccess) {
    final target = e.target;
    if (target != null &&
        suffixes.contains(e.propertyName.name) &&
        _isNumber(target.staticType)) {
      return ScaledValue(e, target, e.propertyName);
    }
  } else if (e is PrefixedIdentifier) {
    if (suffixes.contains(e.identifier.name) &&
        _isNumber(e.prefix.staticType)) {
      return ScaledValue(e, e.prefix, e.identifier);
    }
  }
  return null;
}

bool _isNumber(DartType? type) =>
    type != null &&
    type.nullabilitySuffix == NullabilitySuffix.none &&
    (type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum);

/// Source for [e] in a position typed `double`.
String doubleSource(Expression e) {
  final source = e.toSource();
  if (e is IntegerLiteral || e is DoubleLiteral) return source;
  final type = e.staticType;
  if (type != null && type.isDartCoreDouble) return source;
  final needsParens = e is! Identifier &&
      e is! ParenthesizedExpression &&
      e is! PropertyAccess &&
      e is! MethodInvocation;
  return needsParens ? '($source).toDouble()' : '$source.toDouble()';
}

/// Whether [e] can be used as a non-null `double` design value.
bool isUsableHeight(Expression e) {
  final type = e.staticType;
  if (type == null || type.nullabilitySuffix != NullabilitySuffix.none) {
    return false;
  }
  return type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum;
}

/// Whether [height] is a real fixed height (not 0 or infinity).
bool isFixedHeight(Expression height) {
  if (height is IntegerLiteral && height.value == 0) return false;
  if (height is DoubleLiteral && height.value == 0) return false;
  final source = height.toSource();
  return !source.contains('infinity') && !source.contains('maxFinite');
}

/// Whether the `child:` subtree of [box] contains a text widget that is
/// not inside a scrollable, a scale-down box or another fixed-height box.
bool childHoldsText(InstanceCreationExpression box) {
  final child = namedArg(box, 'child')?.expression;
  if (child == null) return false;
  final finder = _TextFinder();
  child.accept(finder);
  return finder.found;
}

class _TextFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (found) return;
    if (_is(textChecker, node)) {
      found = true;
      return;
    }
    if (_is(_stopChecker, node) || _isAssignable(_stopChecker, node)) return;
    // A nested fixed-height box is reported on its own.
    if ((isUnnamed(sizedBoxChecker, node) ||
            isUnnamed(containerChecker, node)) &&
        namedArg(node, 'height') != null) {
      return;
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Whether [box] sizes a touch target: its child is a button or tile, or
/// it is the child of one (through wrappers such as `Padding`).
bool isTapBox(InstanceCreationExpression box) {
  // Down: the child (through wrappers) is a tap widget.
  Expression? child = namedArg(box, 'child')?.expression;
  while (child is InstanceCreationExpression) {
    if (isTapWidget(child)) return true;
    if (!_is(_wrapperChecker, child)) break;
    child = namedArg(child, 'child')?.expression;
  }
  // Up: the box is the child (through wrappers) of a tap widget.
  AstNode current = box;
  while (true) {
    final named = current.parent;
    if (named is! NamedExpression || named.name.label.name != 'child') {
      return false;
    }
    final owner = named.parent?.parent;
    if (owner is! InstanceCreationExpression) return false;
    if (isTapWidget(owner)) return true;
    if (!_is(_wrapperChecker, owner)) return false;
    current = owner;
  }
}

/// Text of [node] in [content] (the file), comments included.
String textOf(String content, AstNode node) =>
    content.substring(node.offset, node.end);

/// Text of [node] in [content] with the argument [remove] taken out.
String withoutArg(
  String content,
  InstanceCreationExpression node,
  NamedExpression remove,
) {
  final args = node.argumentList.arguments;
  final index = args.indexOf(remove);
  int start;
  int end;
  if (index < args.length - 1) {
    start = remove.offset;
    end = args[index + 1].offset;
  } else if (index > 0) {
    start = args[index - 1].end;
    end = remove.end;
  } else {
    start = remove.offset;
    end = remove.end;
    final next = remove.endToken.next;
    if (next != null && next.lexeme == ',') end = next.end;
  }
  return content.substring(node.offset, start) +
      content.substring(end, node.end);
}
