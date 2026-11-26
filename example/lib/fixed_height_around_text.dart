import 'package:fit_scale/extensions.dart';
import 'package:flutter/material.dart';

class FixedHeightExamples extends StatelessWidget {
  const FixedHeightExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bad: the text grows with the system font size, the box does not.
        // expect_lint: fixed_height_around_text
        SizedBox(height: 48.h, child: const Text('Total: 12.50 AZN')),

        // Bad: a plain constant is just as fixed.
        // expect_lint: fixed_height_around_text
        const SizedBox(
          height: 40,
          child: Row(children: [Icon(Icons.info), Text('Read more')]),
        ),

        // Bad: Container with a height and text inside.
        // expect_lint: fixed_height_around_text
        Container(
          height: 56.h,
          color: Colors.amber,
          alignment: Alignment.center,
          child: const Text('Limited offer'),
        ),

        // Bad: text inside a button inside a fixed box. The fix keeps the
        // touch target too (FitBox(interactive: true)).
        // expect_lint: fixed_height_around_text
        SizedBox(
          height: 48.h,
          width: double.infinity,
          child: FilledButton(onPressed: () {}, child: const Text('Pay')),
        ),

        // Good: a minimum height that grows with its content.
        const FitBox(height: 48, child: Text('Total: 12.50 AZN')),

        // Good: no text inside.
        SizedBox(height: 24.h, child: const Icon(Icons.star)),

        // Good: spacing, no child.
        SizedBox(height: 16.h),

        // Good: the text scrolls instead of overflowing.
        SizedBox(
          height: 120.h,
          child: ListView(children: const [Text('A long list')]),
        ),

        // Good: FittedBox scales the text down to fit.
        const SizedBox(
          height: 32,
          child: FittedBox(child: Text('Scaled down')),
        ),

        // Good: not a fixed height.
        const SizedBox(height: double.infinity, child: Text('Fills')),
      ],
    );
  }
}
