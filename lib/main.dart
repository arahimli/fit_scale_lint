/// Analyzer plugin entry point. The Dart analysis server loads this
/// library and reads [plugin]; enable it in `analysis_options.yaml`:
///
/// ```yaml
/// plugins:
///   fit_scale_lint: ^0.2.0
/// ```
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'fit_scale_lint.dart';

/// The plugin instance the analysis server looks for.
final plugin = FitScaleLintPlugin();

/// Registers the fit_scale_lint rules and their quick fixes.
class FitScaleLintPlugin extends Plugin {
  @override
  String get name => 'fit_scale_lint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(FixedHeightAroundText())
      ..registerFixForRule(FixedHeightAroundText.code, UseFitBox.new)
      ..registerWarningRule(SeparatelyScaledSquare())
      ..registerFixForRule(SeparatelyScaledSquare.code, UseFitSquare.new)
      ..registerFixForRule(SeparatelyScaledSquare.code, ScaleBothSidesWithR.new)
      ..registerWarningRule(TapHeightWithH())
      ..registerFixForRule(TapHeightWithH.code, UseTap.new)
      ..registerWarningRule(ScreenutilImport())
      ..registerFixForRule(ScreenutilImport.code, UseFitExtensions.new);
  }
}
