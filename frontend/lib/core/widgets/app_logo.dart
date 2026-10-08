import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;
  final TextStyle? titleStyle;

  const AppLogo({
    super.key,
    this.size = 56,
    this.showText = false,
    this.isDark = false,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoBadge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.28),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Elegant fallback vector icon
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.auto_graph_rounded,
                size: size * 0.55,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );

    if (!showText) {
      return logoBadge;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoBadge,
        const SizedBox(height: 14),
        Text(
          'GradeNexus',
          style: titleStyle ??
              TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Grade Sheet Intelligence & CGPA Analytics',
          style: TextStyle(
            fontSize: size * 0.18,
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
