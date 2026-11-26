/// Lint rules and quick fixes for layouts that break on small screens or
/// with large system text, built on custom_lint.
///
/// Add `custom_lint` and `fit_scale_lint` to `dev_dependencies` and enable
/// the plugin in `analysis_options.yaml`; see the README.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/fixed_height_around_text.dart';
import 'src/rules/screenutil_import.dart';
import 'src/rules/separately_scaled_square.dart';
import 'src/rules/tap_height_with_h.dart';

export 'src/rules/fixed_height_around_text.dart' show FixedHeightAroundText;
export 'src/rules/screenutil_import.dart' show ScreenutilImport;
export 'src/rules/separately_scaled_square.dart' show SeparatelyScaledSquare;
export 'src/rules/tap_height_with_h.dart' show TapHeightWithH;

/// Entry point used by custom_lint.
PluginBase createPlugin() => _FitScaleLint();

class _FitScaleLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        FixedHeightAroundText(),
        SeparatelyScaledSquare(),
        TapHeightWithH(),
        ScreenutilImport(),
      ];
}
