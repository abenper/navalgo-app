import 'package:flutter/material.dart';

import '../theme/navalgo_theme.dart';

class NavalgoPageIntro extends StatelessWidget {
  const NavalgoPageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
    this.footer,
    this.stackTrailingBreakpoint = 760,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final Widget? footer;
  final double stackTrailingBreakpoint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailing =
            trailing != null && constraints.maxWidth < stackTrailingBreakpoint;
        final introContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                style: textTheme.labelLarge?.copyWith(
                  color: NavalgoColors.sand,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 18), footer!],
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: NavalgoColors.heroGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: NavalgoColors.deepSea.withValues(alpha: 0.2),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: stackTrailing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    introContent,
                    const SizedBox(height: 20),
                    trailing!,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: introContent),
                    if (trailing != null) ...[
                      const SizedBox(width: 24),
                      Flexible(child: trailing!),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class NavalgoSectionHeader extends StatelessWidget {
  const NavalgoSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(subtitle, style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class NavalgoMetricCard extends StatelessWidget {
  const NavalgoMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const Spacer(),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: NavalgoColors.storm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class NavalgoPanel extends StatelessWidget {
  const NavalgoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.border),
        boxShadow: [
          BoxShadow(
            color: NavalgoColors.deepSea.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class NavalgoStatusChip extends StatelessWidget {
  const NavalgoStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class NavalgoPageBackground extends StatelessWidget {
  const NavalgoPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: NavalgoColors.pageGradient),
      child: child,
    );
  }
}
