import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final List<BoxShadow>? shadow;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 0.0,
    this.opacity = 0.0,
    this.borderOpacity = 0.0,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedRadius = borderRadius ?? BorderRadius.circular(12);
    final resolvedColor = color ?? theme.cardTheme.color ?? theme.colorScheme.surface;

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: resolvedRadius,
        border: border ?? Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: shadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
