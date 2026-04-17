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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 240;

        return Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: compact ? 20 : 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: NavalgoColors.storm,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: NavalgoColors.deepSea,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (note != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: compact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    note!,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: NavalgoColors.storm,
                      height: 1.3,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      width: compact ? 28 : 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: NavalgoColors.border,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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

class NavalgoFormDialog extends StatelessWidget {
  const NavalgoFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.eyebrow,
    this.actions,
    this.maxWidth = 560,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: NavalgoColors.heroGradient,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: NavalgoColors.deepSea.withValues(alpha: 0.26),
              blurRadius: 40,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              child,
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NavalgoFormStyles {
  const NavalgoFormStyles._();

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    String? helper,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.28),
      ),
    );

    return InputDecoration(
      hintText: hint ?? label,
      helperText: helper,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.94),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: NavalgoColors.storm,
      ),
      helperStyle: theme.textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.78),
      ),
      prefixIconColor: NavalgoColors.tide,
      suffixIconColor: NavalgoColors.tide,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: NavalgoColors.sand, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: NavalgoColors.alert),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: NavalgoColors.alert, width: 1.5),
      ),
    );
  }
}

class NavalgoFormFieldBlock extends StatelessWidget {
  const NavalgoFormFieldBlock({
    super.key,
    required this.label,
    required this.child,
    this.caption,
    this.inverse = true,
  });

  final String label;
  final Widget child;
  final String? caption;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelColor = inverse
        ? Colors.white.withValues(alpha: 0.94)
        : NavalgoColors.deepSea;
    final captionColor = inverse
        ? Colors.white.withValues(alpha: 0.76)
        : NavalgoColors.storm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: textTheme.bodySmall?.copyWith(color: captionColor),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class NavalgoGradientButton extends StatelessWidget {
  const NavalgoGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(
                colors: [
                  NavalgoColors.storm.withValues(alpha: 0.45),
                  NavalgoColors.storm.withValues(alpha: 0.35),
                ],
              )
            : NavalgoColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: NavalgoColors.deepSea.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ).copyWith(
          iconSize: const WidgetStatePropertyAll(18),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class NavalgoGhostButton extends StatelessWidget {
  const NavalgoGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
