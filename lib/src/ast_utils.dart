// Helpers shared by the rules and fixes.
//
// One release has to work with analyzer 12 (Dart 3.10) through 14, so
// only APIs that are the same in all of them are used here.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [type] is the class [name] declared in package [package].
bool _isClass(DartType? type, String package, Set<String> names) {
  if (type is! InterfaceType) return false;
  final element = type.element;
  if (!names.contains(element.name)) return false;
  final uri = element.library.uri;
  return uri.scheme == 'package' &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == package;
}

/// Whether [type] or one of its supertypes is a Flutter class in [names].
bool _isOrExtends(DartType? type, Set<String> names) {
  if (type is! InterfaceType) return false;
  if (_isClass(type, 'flutter', names)) return true;
  return type.allSupertypes.any((t) => _isClass(t, 'flutter', names));
}

/// Widgets whose height grows with the system text size.
const _textWidgets = {
  'Text',
  'RichText',
  'SelectableText',
  'TextField',
  'TextFormField',
  'CupertinoTextField',
};

/// Widgets the user taps: buttons, tiles and gesture wrappers.
const _tapWidgets = {
  'ButtonStyleButton', // Elevated/Filled/Outlined/TextButton
  'IconButton',
  'FloatingActionButton',
  'MaterialButton',
  'RawMaterialButton',
  'CupertinoButton',
  'ListTile',
  'CheckboxListTile',
  'SwitchListTile',
  'RadioListTile',
  'InkResponse', // and InkWell
  'GestureDetector',
};

/// Single-child wrappers that do not change what the child is.
const _wrappers = {
  'Padding',
  'Center',
  'Align',
  'Expanded',
  'Flexible',
  'Semantics',
};

/// Subtrees below these never overflow a fixed height: they scroll or
/// scale their content down.
const _stopWidgets = {
  'ListView',
  'GridView',
  'PageView',
  'SingleChildScrollView',
  'CustomScrollView',
  'FittedBox',
  'OverflowBox',
};

/// Whether [node] is the unnamed constructor of the Flutter class [name],
/// such as `SizedBox(...)` but not `SizedBox.square(...)`.
bool isUnnamed(InstanceCreationExpression node, String name) =>
    node.constructorName.name == null &&
    _isClass(node.staticType, 'flutter', {name});

/// `SizedBox(...)` or `Container(...)`.
bool isHeightBox(InstanceCreationExpression node) =>
    isUnnamed(node, 'SizedBox') || isUnnamed(node, 'Container');

bool isTapWidget(InstanceCreationExpression node) =>
    _isOrExtends(node.staticType, _tapWidgets);

bool _isWrapper(InstanceCreationExpression node) =>
    _isClass(node.staticType, 'flutter', _wrappers);

/// A `name: value` argument.
///
/// Analyzer 12-13 call it `NamedExpression` and analyzer 14 `NamedArgument`
/// (and neither type exists in the other), so it is recognised by its
/// shape: an identifier, a colon, then the value.
class NamedArg {
  NamedArg._(this.node, this.name, this.expression);

  /// The whole `name: value` node.
  final AstNode node;

  final String name;

  /// The value.
  final Expression expression;

  int get offset => node.offset;
  int get length => node.length;
  int get end => node.end;
}

/// [node] as a named argument, or null when it is positional.
NamedArg? asNamedArg(AstNode node) {
  final name = node.beginToken;
  final colon = name.next;
  if (colon == null || colon.lexeme != ':' || !name.isIdentifier) return null;
  // The value is the last child in both (`expression` in
  // NamedExpression, `argumentExpression` in NamedArgument).
  final value = node.childEntities.last;
  if (value is! Expression) return null;
  return NamedArg._(node, name.lexeme, value);
}

/// The arguments of [node] as plain AST nodes.
List<AstNode> argsOf(InstanceCreationExpression node) => [
  for (final AstNode a in node.argumentList.arguments) a,
];

/// The positional arguments of [args].
List<Expression> positional(Iterable<AstNode> args) => [
  for (final a in args)
    if (asNamedArg(a) == null && a is Expression) a,
];

/// The named argument [name] of [node], or null.
NamedArg? namedArg(InstanceCreationExpression node, String name) {
  for (final arg in argsOf(node)) {
    final named = asNamedArg(arg);
    if (named != null && named.name == name) return named;
  }
  return null;
}

/// Names of all arguments of [node], or null when one is positional.
Set<String>? argNames(InstanceCreationExpression node) {
  final names = <String>{};
  for (final arg in argsOf(node)) {
    final named = asNamedArg(arg);
    if (named == null) return null;
    names.add(named.name);
  }
  return names;
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

/// Returns the parts of [e] when it is `<number>.<suffix>` with a suffix
/// in [suffixes].
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
  final needsParens =
      e is! Identifier &&
      e is! ParenthesizedExpression &&
      e is! PropertyAccess &&
      e is! MethodInvocation;
  return needsParens ? '($source).toDouble()' : '$source.toDouble()';
}

/// Whether [e] can be used as a non-null `double` design value.
bool isUsableHeight(Expression e) => _isNumber(e.staticType);

/// Whether [height] is a design-time fixed height: not 0 or infinity, and
/// not read from the layout (`size.height`, `MediaQuery...`), which
/// already follows the screen.
bool isFixedHeight(Expression height) {
  if (height is IntegerLiteral && height.value == 0) return false;
  if (height is DoubleLiteral && height.value == 0) return false;
  final source = height.toSource();
  if (source.contains('infinity') ||
      source.contains('maxFinite') ||
      source.contains('MediaQuery')) {
    return false;
  }
  return !_isSizeHeight(height);
}

/// `size.height` / `constraints.maxHeight` style reads of a layout value.
bool _isSizeHeight(Expression e) {
  Expression? target;
  String? property;
  if (e is PrefixedIdentifier) {
    target = e.prefix;
    property = e.identifier.name;
  } else if (e is PropertyAccess) {
    target = e.target;
    property = e.propertyName.name;
  }
  final type = target?.staticType;
  if (type is! InterfaceType) return false;
  final name = type.element.name;
  return (name == 'Size' && property == 'height') ||
      (name == 'BoxConstraints' &&
          (property == 'maxHeight' || property == 'minHeight'));
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
    final type = node.staticType;
    if (_isClass(type, 'flutter', _textWidgets)) {
      found = true;
      return;
    }
    if (_isOrExtends(type, _stopWidgets) ||
        _isClass(type, 'fit_scale', const {'FitText', 'FitBox'})) {
      return;
    }
    // A nested fixed-height box is reported on its own.
    if (isHeightBox(node) && namedArg(node, 'height') != null) return;
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
    if (!_isWrapper(child)) break;
    child = namedArg(child, 'child')?.expression;
  }
  // Up: the box is the child (through wrappers) of a tap widget.
  AstNode current = box;
  while (true) {
    final parent = current.parent;
    final named = parent == null ? null : asNamedArg(parent);
    if (named == null || named.name != 'child') return false;
    final owner = parent!.parent?.parent;
    if (owner is! InstanceCreationExpression) return false;
    if (isTapWidget(owner)) return true;
    if (!_isWrapper(owner)) return false;
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
  NamedArg removed,
) {
  final args = argsOf(node);
  final remove = removed.node;
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

/// The `X(...)` call whose constructor name starts at [offset], found from
/// the node a fix was invoked on.
InstanceCreationExpression? creationAt(AstNode node, int offset) {
  AstNode? current = node;
  while (current != null) {
    if (current is InstanceCreationExpression &&
        current.constructorName.offset == offset) {
      return current;
    }
    current = current.parent;
  }
  return null;
}
