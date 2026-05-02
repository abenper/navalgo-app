import 'package:flutter/material.dart';

import '../theme/navalgo_theme.dart';

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
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width == null
        ? null
        : (width! * devicePixelRatio).round();
    final cacheHeight = height == null
        ? null
        : (height! * devicePixelRatio).round();
    if (variant == NavalgoLogoVariant.colorBadge) {
      final resolvedWidth = width ?? height ?? 64;
      final resolvedHeight = height ?? width ?? resolvedWidth;
      final iconPadding = (resolvedWidth * 0.16).clamp(6.0, 20.0);
      return SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: NavalgoColors.heroGradient,
            borderRadius: BorderRadius.circular(resolvedWidth * 0.28),
            boxShadow: [
              BoxShadow(
                color: NavalgoColors.deepSea.withValues(alpha: 0.10),
                blurRadius: resolvedWidth * 0.18,
                offset: Offset(0, resolvedWidth * 0.08),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(iconPadding),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                _assetForVariant(NavalgoLogoVariant.icon),
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                isAntiAlias: true,
                filterQuality: FilterQuality.high,
                semanticLabel: 'NavalGO',
              ),
            ),
          ),
        ),
      );
    }

    return Image.asset(
      _assetForVariant(variant),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      isAntiAlias: true,
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
