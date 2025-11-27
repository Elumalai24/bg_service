import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool showBackground;
  final Color? backgroundColor;
  final double borderRadius;

  const LogoWidget({
    super.key,
    this.size = 60,
    this.showBackground = false,
    this.backgroundColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      'assets/images/logos/logo_without_bg.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.directions_walk, size: size * 0.6, color: Colors.white),
    );

    if (showBackground) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(child: logo),
      );
    }
    return logo;
  }
}

class BrandedLogoWidget extends StatelessWidget {
  final double size;
  final double borderRadius;

  const BrandedLogoWidget({super.key, this.size = 80, this.borderRadius = 20});

  @override
  Widget build(BuildContext context) {
    return LogoWidget(size: size, showBackground: true, borderRadius: borderRadius);
  }
}
