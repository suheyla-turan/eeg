import 'package:flutter/material.dart';

/// Tablet / telefon kırılım noktaları.
abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 900;
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isTablet => screenSize.width >= Breakpoints.tablet;

  bool get isDesktop => screenSize.width >= Breakpoints.desktop;

  bool get isPhone => screenSize.width < Breakpoints.tablet;

  /// İçerik max genişliği (tablet'te ortalanmış okuma alanı).
  double get contentMaxWidth {
    if (isDesktop) return 960;
    if (isTablet) return 720;
    return double.infinity;
  }

  EdgeInsets get pagePadding {
    if (isDesktop) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (isTablet) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  int gridColumns({int phone = 2, int tablet = 3, int desktop = 4}) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet;
    return phone;
  }
}

/// Tablet'te içeriği ortalayan sarmalayıcı.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final max = maxWidth ?? context.contentMaxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );
  }
}
