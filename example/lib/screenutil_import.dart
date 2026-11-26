// expect_lint: screenutil_import
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/widgets.dart';

/// The quick fix swaps the import for package:fit_scale/extensions.dart;
/// `.w`, `.h`, `.r` and `.sp` keep working, now with clamped factors.
Widget card() => Padding(padding: EdgeInsets.all(16.w));
