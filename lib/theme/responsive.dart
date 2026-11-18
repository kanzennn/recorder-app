import 'package:flutter/widgets.dart';

// Breakpoint mengikuti kelas lebar Material: compact <600, medium 600-839, expanded >=840.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}

double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

bool isExpandedWidth(BuildContext context) =>
    screenWidth(context) >= Breakpoints.expanded;

/// Membatasi lebar konten dan memusatkannya, supaya di tablet tidak melebar penuh.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // SafeArea bawah: supaya konten tidak tertutup navigasi sistem (tombol/taskbar Android).
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
