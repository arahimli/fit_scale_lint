// Minimal stand-ins for the Flutter, fit_scale and flutter_screenutil
// APIs the rules look at. The rules match classes by name and package,
// so these resolve the same way as the real packages.

const flutterWidgets = r'''
export 'src/ui.dart';

class Key { const Key(String value); }
abstract class Widget { const Widget({Key? key}); }
abstract class StatelessWidget extends Widget { const StatelessWidget({super.key}); }
class EdgeInsets { static const EdgeInsets zero = EdgeInsets.all(0); const EdgeInsets.all(double v); }
class BoxConstraints { const BoxConstraints({double minHeight = 0}); }
class Alignment { static const Alignment center = Alignment(0, 0); const Alignment(double x, double y); }
class Color { const Color(int v); }
class IconData { const IconData(int c); }
class Icons { static const IconData add = IconData(1); static const IconData star = IconData(2); static const IconData close = IconData(3); }

class SizedBox extends Widget {
  const SizedBox({super.key, double? width, double? height, Widget? child});
  const SizedBox.square({super.key, double? dimension, Widget? child});
}
class Container extends Widget {
  Container({super.key, double? width, double? height, Color? color, Alignment? alignment, BoxConstraints? constraints, Object? decoration, Widget? child});
}
class TextSpan { const TextSpan({String? text}); }
class Text extends Widget {
  const Text(String data, {super.key});
  const Text.rich(TextSpan span, {super.key});
}
class RichText extends Widget { const RichText({super.key, required TextSpan text}); }
class SelectableText extends Widget { const SelectableText(String data, {super.key}); }
class Icon extends Widget { const Icon(IconData icon, {super.key}); }
class Image extends Widget { Image.asset(String name, {super.key, double? width, double? height}); }
class Padding extends Widget { const Padding({super.key, required EdgeInsets padding, Widget? child}); }
class Center extends Widget { const Center({super.key, Widget? child}); }
class Align extends Widget { const Align({super.key, Alignment alignment = Alignment.center, Widget? child}); }
class Expanded extends Widget { const Expanded({super.key, required Widget child}); }
class Flexible extends Widget { const Flexible({super.key, required Widget child}); }
class Semantics extends Widget { const Semantics({super.key, Widget? child}); }
class Column extends Widget { const Column({super.key, List<Widget> children = const []}); }
class Row extends Widget { const Row({super.key, List<Widget> children = const []}); }
class ListView extends Widget { const ListView({super.key, List<Widget> children = const []}); }
class SingleChildScrollView extends Widget { const SingleChildScrollView({super.key, Widget? child}); }
class FittedBox extends Widget { const FittedBox({super.key, Widget? child}); }
class GestureDetector extends Widget { const GestureDetector({super.key, void Function()? onTap, Widget? child}); }
''';

const flutterUi = r'''
class Size {
  double get height => 0;
  const Size(double width, double height);
  const Size.fromHeight(double height);
  const Size.square(double dimension);
}
''';

const flutterMaterial = r'''
export 'widgets.dart';
import 'widgets.dart';

class Colors { static const Color red = Color(1); }
class ButtonStyle { const ButtonStyle(); }
abstract class ButtonStyleButton extends Widget {
  const ButtonStyleButton({super.key, required void Function()? onPressed, ButtonStyle? style, Widget? child});
}
class ElevatedButton extends ButtonStyleButton {
  const ElevatedButton({super.key, required super.onPressed, super.style, super.child});
  static ButtonStyle styleFrom({Size? minimumSize, Size? fixedSize}) => const ButtonStyle();
}
class FilledButton extends ButtonStyleButton {
  const FilledButton({super.key, required super.onPressed, super.style, super.child});
  static ButtonStyle styleFrom({Size? minimumSize, Size? fixedSize}) => const ButtonStyle();
}
class IconButton extends Widget { const IconButton({super.key, required void Function()? onPressed, required Widget icon}); }
class MaterialButton extends Widget { const MaterialButton({super.key, required void Function()? onPressed, double? height, Widget? child}); }
class ListTile extends Widget { const ListTile({super.key, double? minTileHeight, Widget? title}); }
class InkResponse extends Widget { const InkResponse({super.key, void Function()? onTap, Widget? child}); }
class InkWell extends InkResponse { const InkWell({super.key, super.onTap, super.child}); }
class TextField extends Widget { const TextField({super.key}); }
class CircleAvatar extends Widget { const CircleAvatar({super.key}); }
''';

const fitScale = r'''
import 'package:flutter/widgets.dart';
class FitBox extends Widget { const FitBox({super.key, required double height, bool interactive = false, Widget? child}); }
class FitSquare extends Widget { const FitSquare({super.key, required double size, Widget? child}); }
class FitText extends Widget { const FitText(String data, {super.key}); }
''';

const fitExtensions = r'''
export 'fit_scale.dart';
extension FitScaleNum on num {
  double get w => 0; double get h => 0; double get r => 0;
  double get sp => 0; double get tap => 0;
}
''';

const screenUtil = r'''
extension SizeExtension on num {
  double get w => 0; double get h => 0; double get r => 0; double get sp => 0;
}
''';
