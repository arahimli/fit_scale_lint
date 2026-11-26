import 'package:fit_scale/extensions.dart';
import 'package:flutter/material.dart';

class SquareExamples extends StatelessWidget {
  const SquareExamples({super.key});

  @override
  Widget build(BuildContext context) {
    const avatar = 40;
    return Row(
      children: [
        // Bad: a circle on the design frame, an oval anywhere else.
        // expect_lint: separately_scaled_square
        SizedBox(width: 56.w, height: 56.h, child: const CircleAvatar()),

        // Bad: same with a variable and a Container.
        // expect_lint: separately_scaled_square
        Container(
          width: avatar.w,
          height: avatar.h,
          decoration: const BoxDecoration(shape: BoxShape.circle),
        ),

        // Bad: any widget with width and height.
        // expect_lint: separately_scaled_square
        Image.asset('assets/logo.png', width: 32.w, height: 32.h),

        // Good: one uniform scale for both sides.
        const FitSquare(size: 56, child: CircleAvatar()),
        SizedBox(width: 56.r, height: 56.r),

        // Good: a rectangle on purpose (different sizes).
        SizedBox(width: 120.w, height: 48.h),
      ],
    );
  }
}
