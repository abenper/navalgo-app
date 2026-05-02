import 'package:flutter/material.dart';

enum NavalgoLogoVariant { icon, horizontal, stacked, colorBadge }

class NavalgoLogo extends StatelessWidget {
  const NavalgoLogo({
    super.key,
    this.variant = NavalgoLogoVariant.icon,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final NavalgoLogoVariant variant;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetForVariant(variant),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      semanticLabel: 'NavalGO',
    );
  }

  String _assetForVariant(NavalgoLogoVariant variant) {
    return switch (variant) {
      NavalgoLogoVariant.icon => 'assets/branding/logo_navalgo_icon.png',
      NavalgoLogoVariant.horizontal =>
        'assets/branding/logo_navalgo_horizontal.png',
      NavalgoLogoVariant.stacked =>
        'assets/branding/logo_navalgo_stacked.png',
      NavalgoLogoVariant.colorBadge =>
        'assets/branding/logo_navalgo_color.png',
    };
  }
}
