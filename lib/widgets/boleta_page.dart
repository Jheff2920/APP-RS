import 'package:flutter/material.dart';

/// Shared page chrome: SafeArea, optional 600 dp cap, optional sticky bar.
class BoletaPage extends StatelessWidget {
  const BoletaPage({
    super.key,
    required this.child,
    this.bottomBar,
    this.maxContentWidth = 600,
    this.constrainWhenWidthAtLeast = 600,
    this.safeAreaTop = false,
  });

  final Widget child;
  final Widget? bottomBar;
  final double maxContentWidth;
  final double constrainWhenWidthAtLeast;
  final bool safeAreaTop;

  @override
  Widget build(BuildContext context) {
    // widthOf: el teclado cambia la altura y no debe relayout de toda la página.
    final capped = _widthCapped(context, child);
    if (bottomBar == null) {
      return SafeArea(top: safeAreaTop, child: capped);
    }
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: safeAreaTop,
            bottom: false,
            child: capped,
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: bottomBar,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _widthCapped(BuildContext context, Widget child) {
    final width = MediaQuery.widthOf(context);
    if (width < constrainWhenWidthAtLeast) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
