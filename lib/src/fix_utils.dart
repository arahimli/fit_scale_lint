import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

const fitScaleUri = 'package:fit_scale/fit_scale.dart';
const fitExtensionsUri = 'package:fit_scale/extensions.dart';
const screenUtilPackage = 'package:flutter_screenutil/';

/// Imports of [unit], keyed by URI.
Map<String, ImportDirective> _imports(CompilationUnit unit) => {
  for (final d in unit.directives)
    if (d is ImportDirective && d.uri.stringValue != null)
      d.uri.stringValue!: d,
};

bool _isPlain(ImportDirective d) => d.prefix == null && d.combinators.isEmpty;

/// Makes `FitBox`, `FitSquare` and friends available in [unit].
void ensureFitScaleImport(DartFileEditBuilder builder, CompilationUnit unit) {
  final imports = _imports(unit);
  if (imports.containsKey(fitScaleUri) ||
      imports.containsKey(fitExtensionsUri)) {
    return;
  }
  builder.importLibrary(Uri.parse(fitScaleUri));
}

/// Makes the fit_scale `num` extensions (`.tap`) available in [unit].
///
/// A flutter_screenutil import is replaced rather than kept next to it:
/// both define `.w`/`.h`, so keeping both makes every use ambiguous.
void ensureFitExtensionsImport(
  DartFileEditBuilder builder,
  CompilationUnit unit,
) {
  final imports = _imports(unit);
  if (imports.containsKey(fitExtensionsUri)) return;
  for (final entry in imports.entries) {
    if (entry.key.startsWith(screenUtilPackage) ||
        (entry.key == fitScaleUri && _isPlain(entry.value))) {
      final uri = entry.value.uri;
      builder.addSimpleReplacement(
        SourceRange(uri.offset, uri.length),
        "'$fitExtensionsUri'",
      );
      return;
    }
  }
  builder.importLibrary(Uri.parse(fitExtensionsUri));
}
