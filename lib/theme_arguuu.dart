import 'package:flutter/material.dart';

// Copying AppColors from Arguuu
class AppColors {
  // Base Palette
  static const Color cream = Color(0xFFFAF6F0);
  static const Color cottonWhite = Color(0xFFFDF9F4);
  static const Color sand = Color(0xFFE8DDD0);
  static const Color tan = Color(0xFFC9B99E);
  static const Color terracotta = Color(0xFFC4724A);
  
  // Accents
  static const Color copper = Color(0xFFC4724A); // Primary Accent
  static const Color rust = Color(0xFFA85535);
  static const Color brown = Color(0xFF5C3D2E);
  static const Color darkWood = Color(0xFF2A1F17);
  
  // Text
  static const Color textMain = Color(0xFF3D2B1F);
  static const Color textLight = Color(0xFF7A5C4A);
  static const Color ink = Color(0xFF1A110A);
  
  // Functional
  static const Color forBg = Color(0xFFE6F1FB);
  static const Color forTxt = Color(0xFF0C447C);
  static const Color forStroke = Color(0xFF185FA5);
  
  static const Color againstBg = Color(0xFFFAECE7);
  static const Color againstTxt = Color(0xFF712B13);
  static const Color againstStroke = Color(0xFF993C1D);
  
  static const Color winBg = Color(0xFFEAF3DE);
  static const Color winTxt = Color(0xFF27500A);
  
  static const Color lossBg = Color(0xFFFCEBEB);
  static const Color lossTxt = Color(0xFF791F1F);
}

// Copying AppFonts from Arguuu
class AppFonts {
  static const String serifFamily = 'Anthropic Serif';
  static const String sansFamily = 'Anthropic Sans';
  static const String monoFamily = 'Anthropic Mono';

  static TextStyle serif({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle sans({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

// Reusable ArguuuCard Widget
class ArguuuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const ArguuuCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? const Color(0xFF25211E) : AppColors.cottonWhite);
    final borderColor = isDark ? Colors.white.withOpacity(0.15) : AppColors.sand;
    final resolvedRadius = borderRadius ?? BorderRadius.circular(20);

    if (onTap == null) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: resolvedRadius,
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: padding ?? const EdgeInsets.all(10),
        child: child,
      );
    }

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: bgColor,
        borderRadius: resolvedRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: resolvedRadius,
          splashColor: AppColors.copper.withOpacity(0.05),
          highlightColor: AppColors.copper.withOpacity(0.02),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: resolvedRadius,
              border: Border.all(color: borderColor, width: 1.0),
            ),
            padding: padding ?? const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Reusable ArguuuButton Widget
class ArguuuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isSecondary;
  final bool isTerra;
  final bool isDanger;
  final bool fullWidth;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final Color? textColor;
  final Color? borderColor;
  final Widget? icon;
  final Color? backgroundColor;

  const ArguuuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isSecondary = false,
    this.isTerra = false,
    this.isDanger = false,
    this.fullWidth = false,
    this.fontSize,
    this.padding,
    this.textColor,
    this.borderColor,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    if (isDanger) {
      bg = AppColors.lossBg;
      fg = AppColors.lossTxt;
      border = const BorderSide(color: Color(0xFFF09595), width: 0.5);
    } else if (isTerra) {
      bg = AppColors.terracotta;
      fg = AppColors.cream;
    } else if (isSecondary) {
      bg = isDark ? const Color(0xFF2A2420) : AppColors.cottonWhite;
      fg = isDark ? Colors.white70 : AppColors.darkWood;
      border = BorderSide(
        color: isDark ? Colors.white12 : const Color(0xFFD4C2AE),
        width: 1.0,
      );
    } else {
      bg = AppColors.darkWood;
      fg = AppColors.cream;
    }

    if (backgroundColor != null) bg = backgroundColor!;
    if (textColor != null) fg = textColor!;
    if (borderColor != null) border = BorderSide(color: borderColor!, width: 1.0);

    Widget button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            border: border == BorderSide.none ? null : Border.fromBorderSide(border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 10),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.serif(
                  color: fg,
                  fontSize: fontSize ?? 15,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (fullWidth) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(width: double.infinity, child: button),
      );
    }
    return button;
  }
}

// Reusable ArguuuConfirmDialog Widget
class ArguuuConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String yesLabel;
  final String noLabel;
  final VoidCallback? onYes;
  final VoidCallback onNo;
  final bool isDanger;
  final Widget? content;

  const ArguuuConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.yesLabel,
    required this.noLabel,
    this.onYes,
    required this.onNo,
    this.isDanger = true,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2A2420) : const Color(0xFFFAF6F1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alert Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDanger 
                      ? (isDark ? const Color(0xFF993C1D).withOpacity(0.2) : const Color(0xFFFBECE8))
                      : (isDark ? const Color(0xFF185FA5).withOpacity(0.2) : const Color(0xFFE6F1FB)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: isDanger 
                      ? (isDark ? const Color(0xFFF09595) : const Color(0xFF993C1D))
                      : (isDark ? const Color(0xFFB5D4F5) : const Color(0xFF185FA5)),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.serif(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2C2622),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppFonts.serif(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: isDanger 
                      ? const Color(0xFF993C1D).withOpacity(0.7) 
                      : (isDark ? Colors.white70 : const Color(0xFF2C2622).withOpacity(0.6)),
                  height: 1.4,
                ),
              ),
              if (content != null) ...[
                const SizedBox(height: 24),
                content!,
              ],
              const SizedBox(height: 32),
              // YES Button
              GestureDetector(
                onTap: onYes,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDanger 
                        ? (isDark ? const Color(0xFF993C1D).withOpacity(0.25) : const Color(0xFFFBECE8))
                        : (isDark ? const Color(0xFF185FA5).withOpacity(0.25) : const Color(0xFFE6F1FB)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDanger 
                          ? (isDark ? const Color(0xFF993C1D).withOpacity(0.5) : const Color(0xFFF09595))
                          : (isDark ? const Color(0xFF185FA5).withOpacity(0.5) : const Color(0xFFB5D4F5)),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    yesLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppFonts.mono(
                      color: isDanger 
                          ? (isDark ? const Color(0xFFF09595) : const Color(0xFF993C1D))
                          : (isDark ? const Color(0xFFB5D4F5) : const Color(0xFF185FA5)),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // NO Button
              GestureDetector(
                onTap: onNo,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE5DCD0),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    noLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppFonts.mono(
                      color: isDark ? Colors.white70 : const Color(0xFF4A342B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
