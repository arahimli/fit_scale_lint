import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Test sources are resolved as if they were files in example/lib, so
/// they see Flutter, fit_scale and flutter_screenutil. Run
/// `flutter pub get` in example/ first.
final _root = Directory('example').absolute.path;
final _files = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
AnalysisContextCollection? _collection;
var _count = 0;

const material = "import 'package:flutter/material.dart';\n";
const fitExtensions = "import 'package:fit_scale/extensions.dart';\n";
const fitScale = "import 'package:fit_scale/fit_scale.dart';\n";
const screenUtil =
    "import 'package:flutter_screenutil/flutter_screenutil.dart';\n";

/// Wraps [expression] in a widget so it can be written on its own.
String widget(String expression, {String imports = material + fitExtensions}) =>
    '${imports}Widget build(int n) => $expression;\n';

Future<ResolvedUnitResult> resolve(String code) async {
  if (!File('$_root/.dart_tool/package_config.json').existsSync()) {
    throw StateError('Run `flutter pub get` in example/ before the tests.');
  }
  final path = '$_root/lib/_fit_scale_lint_test_${_count++}.dart';
  _files.setOverlay(path, content: code, modificationStamp: 0);
  final collection = _collection ??= AnalysisContextCollection(
    includedPaths: [_root],
    resourceProvider: _files,
  );
  final session = collection.contextFor(path).currentSession;
  final result = await session.getResolvedUnit(path) as ResolvedUnitResult;
  final errors = result.errors
      .where((e) => e.errorCode.errorSeverity == ErrorSeverity.ERROR)
      // Tests that keep both screenutil and fit_scale imported.
      .where((e) => !e.errorCode.name.toLowerCase().contains('ambiguous'));
  if (errors.isNotEmpty) {
    throw StateError('Test source does not compile: $errors\n$code');
  }
  return result;
}

/// The source text each lint of [rule] in [code] points at.
Future<List<String>> lints(DartLintRule rule, String code) async {
  final result = await resolve(code);
  final errors = await rule.testRun(result);
  return [
    for (final e in errors) code.substring(e.offset, e.offset + e.length),
  ];
}

/// [code] after the quick fix number [fix] for the first lint of [rule],
/// or null when that fix does not offer a change.
Future<String?> applyFix(DartLintRule rule, String code, {int fix = 0}) async {
  final result = await resolve(code);
  final errors = await rule.testRun(result);
  if (errors.isEmpty) throw StateError('No lint to fix in:\n$code');
  final dartFix = rule.getFixes()[fix] as DartFix;
  final changes = await dartFix.testRun(result, errors.first, errors);
  if (changes.isEmpty) return null;
  final edits = changes.single.change.edits.single.edits;
  return SourceEdit.applySequence(code, edits);
}
