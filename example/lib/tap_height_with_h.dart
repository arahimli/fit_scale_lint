import 'package:fit_scale/extensions.dart';
import 'package:flutter/material.dart';

class TapExamples extends StatelessWidget {
  const TapExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bad: on a short screen 40.h is ~32 px, below the 48 px minimum.
        SizedBox(
          // expect_lint: tap_height_with_h
          height: 40.h,
          child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ),

        // Bad: the tappable area itself is sized with .h.
        InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              // expect_lint: tap_height_with_h
              height: 36.h,
              width: 36.h,
              child: const Icon(Icons.close),
            ),
          ),
        ),

        // Bad: button style sizes.
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            // expect_lint: tap_height_with_h
            minimumSize: Size(double.infinity, 44.h),
          ),
          onPressed: () {},
          child: const Text('Continue'),
        ),

        // Bad: a height argument of the button itself.
        MaterialButton(
          // expect_lint: tap_height_with_h
          height: 40.h,
          onPressed: () {},
          child: const Text('Old style'),
        ),

        // Good: never below the platform minimum.
        SizedBox(
          height: 40.tap,
          child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 44.tap),
          ),
          onPressed: () {},
          child: const Text('Continue'),
        ),

        // Good: .h on a box that is not a touch target.
        SizedBox(height: 40.h, child: const Icon(Icons.star)),
      ],
    );
  }
}
