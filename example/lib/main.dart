import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/material.dart';

import 'fixed_height_around_text.dart';
import 'separately_scaled_square.dart';
import 'tap_height_with_h.dart';

/// Run `dart run tool/check_example.dart` in the repository root. Each
/// "expect_lint" comment in lib/ marks the next line as one that must
/// report that rule; any other report, or a marked line without one, fails.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FitScaleScope(
      config: const FitScaleConfig(designSize: Size(360, 690)),
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              FixedHeightExamples(),
              SquareExamples(),
              TapExamples(),
            ],
          ),
        ),
      ),
    );
  }
}
