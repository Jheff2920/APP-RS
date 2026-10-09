import 'package:flutter/material.dart';

/// Marco de página compartido: SafeArea y ancho máximo de 600 dp en tablets.
/// Las acciones fijas van en `Scaffold.bottomNavigationBar` con
/// `BottomActions`, para que los avisos (SnackBar) salgan encima.
class BoletaPage extends StatelessWidget {
  const BoletaPage({
    super.key,
    required this.child,
    this.maxContentWidth = 600,
    this.constrainWhenWidthAtLeast = 600,
    this.safeAreaTop = false,
  });

  final Widget child;
  final double maxContentWidth;
  final double constrainWhenWidthAtLeast;
  final bool safeAreaTop;

  @override
  Widget build(BuildContext context) {
    // widthOf: el teclado cambia la altura y no debe relayout de toda la página.
    final capped = _widthCapped(context, child);
    return SafeArea(top: safeAreaTop, bottom: false, child: capped);
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
