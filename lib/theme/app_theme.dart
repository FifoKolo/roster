import 'package:flutter/material.dart';

/// Centralized theme system for the Roster App
/// Provides consistent colors, typography, and styling across all components
class AppTheme {
  // ===================
  // PRIMARY COLOR PALETTE
  // ===================
  
  /// Primary brand color - Blue
  static const primaryBlue = Color(0xFF1976D2);  // Material Blue 700
  static const primaryBlueLight = Color(0xFF42A5F5);  // Material Blue 400
  static const primaryBlueDark = Color(0xFF0D47A1);   // Material Blue 900
  
  /// Secondary color - Indigo (for settings, configuration)
  static const secondaryIndigo = Color(0xFF3F51B5);  // Material Indigo 500
  static const secondaryIndigoLight = Color(0xFF7986CB);  // Material Indigo 300
  static const secondaryIndigoDark = Color(0xFF1A237E);   // Material Indigo 900
  
  /// Accent color - Teal (for highlights, selections)
  static const accentTeal = Color(0xFF00BCD4);  // Material Cyan 500
  static const accentTealLight = Color(0xFF4DD0E1);  // Material Cyan 300
  static const accentTealDark = Color(0xFF00695C);   // Material Teal 800
  
  // ===================
  // SEMANTIC COLORS
  // ===================
  
  /// Success states (save, confirm, positive actions)
  static const success = Color(0xFF4CAF50);      // Material Green 500
  static const successLight = Color(0xFF81C784); // Material Green 300
  static const successDark = Color(0xFF1B5E20);  // Material Green 900
  
  /// Warning states (caution, pending)
  static const warning = Color(0xFFFF9800);      // Material Orange 500
  static const warningLight = Color(0xFFFFB74D); // Material Orange 300
  static const warningDark = Color(0xFFE65100);  // Material Orange 900
  
  /// Error states (delete, cancel, danger)
  static const error = Color(0xFFF44336);        // Material Red 500
  static const errorLight = Color(0xFFE57373);   // Material Red 300
  static const errorDark = Color(0xFFB71C1C);    // Material Red 900
  
  /// Info states (neutral information)
  static const info = Color(0xFF2196F3);         // Material Blue 500
  static const infoLight = Color(0xFF64B5F6);    // Material Blue 300
  static const infoDark = Color(0xFF0277BD);     // Material Blue 800
  
  // ===================
  // NEUTRAL COLORS
  // ===================
  
  /// Background colors
  static const backgroundPrimary = Color(0xFFFFFFFF);
  static const backgroundSecondary = Color(0xFFF5F5F5);  // Material Gray 100
  static const backgroundTertiary = Color(0xFFEEEEEE);   // Material Gray 200
  
  /// Surface colors (cards, dialogs)
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF8F9FA);
  
  /// Text colors
  static const textPrimary = Color(0xFF1A1A1A);         // Near black
  static const textSecondary = Color(0xFF6B6B6B);       // Medium gray
  static const textTertiary = Color(0xFF9E9E9E);        // Light gray
  static const textInverse = Color(0xFFFFFFFF);         // White on dark backgrounds
  
  /// Border and divider colors
  static const borderPrimary = Color(0xFFE0E0E0);       // Light gray border
  static const borderSecondary = Color(0xFFBDBDBD);     // Medium gray border
  static const divider = Color(0xFFEEEEEE);             // Very light gray
  
  // ===================
  // THEME EXTENSIONS
  // ===================
  
  /// Light background variations with subtle tints
  static const primaryBlueBackground = Color(0xFFF3F7FF);    // Very light blue
  static const secondaryIndigoBackground = Color(0xFFF5F6FF); // Very light indigo
  static const successBackground = Color(0xFFF1F8E9);        // Very light green
  static const warningBackground = Color(0xFFFFF8E1);        // Very light orange
  static const errorBackground = Color(0xFFFFEBEE);          // Very light red
  
  // ===================
  // BUTTON STYLES
  // ===================
  
  /// Primary button style (main actions)
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: primaryBlue.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
  
  /// Secondary button style (secondary actions)
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: backgroundSecondary,
    foregroundColor: textPrimary,
    elevation: 0,
    side: BorderSide(color: borderPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
    ),
  );
  
  /// Text button style (minimal actions)
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: primaryBlue,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
    ),
  );
  
  /// Success button style (confirm, save)
  static ButtonStyle get successButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: success,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: success.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
  
  /// Danger button style (delete, cancel)
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: error,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: error.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
  
  /// Warning button style (caution actions)
  static ButtonStyle get warningButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: warning,
    foregroundColor: textInverse,
    elevation: 2,
    shadowColor: warning.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
  
  // ===================
  // CARD STYLES
  // ===================
  
  /// Standard card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderPrimary),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Elevated card decoration (more prominent)
  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Primary themed card (blue accent)
  static BoxDecoration get primaryCard => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: primaryBlue.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: primaryBlue.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Success themed card (green accent)
  static BoxDecoration get successCard => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: success.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: success.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Warning themed card (orange accent)
  static BoxDecoration get warningCard => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: warning.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: warning.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Error themed card (red accent)
  static BoxDecoration get errorCard => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: error.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: error.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  // ===================
  // INPUT FIELD STYLES
  // ===================
  
  /// Standard input decoration
  static InputDecoration inputDecoration({
    String? hint,
    String? label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    labelText: label,
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: textSecondary) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: borderPrimary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: borderPrimary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: error, width: 2),
    ),
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  
  // ===================
  // TYPOGRAPHY STYLES
  // ===================
  
  /// Large title text style
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.3,
  );
  
  /// Medium title text style
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );
  
  /// Small title text style
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  /// Body text style
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );
  
  /// Body text style
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );
  
  /// Small body text style
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );
  
  /// Caption text style
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    height: 1.3,
  );
  
  // ===================
  // SPACING CONSTANTS
  // ===================
  
  /// Standard spacing values
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  /// Border radius values
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  
  // ===================
  // ICON CONTAINERS
  // ===================
  
  /// Primary themed icon container
  static Widget iconContainer({
    required IconData icon,
    Color? backgroundColor,
    Color? iconColor,
    double? size,
    double? padding,
  }) {
    return Container(
      padding: EdgeInsets.all(padding ?? 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? primaryBlueBackground,
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      child: Icon(
        icon,
        color: iconColor ?? primaryBlue,
        size: size ?? 20,
      ),
    );
  }
  
  /// Success themed icon container
  static Widget successIconContainer({
    required IconData icon,
    double? size,
    double? padding,
  }) {
    return iconContainer(
      icon: icon,
      backgroundColor: successBackground,
      iconColor: success,
      size: size,
      padding: padding,
    );
  }
  
  /// Warning themed icon container
  static Widget warningIconContainer({
    required IconData icon,
    double? size,
    double? padding,
  }) {
    return iconContainer(
      icon: icon,
      backgroundColor: warningBackground,
      iconColor: warning,
      size: size,
      padding: padding,
    );
  }
  
  /// Error themed icon container
  static Widget errorIconContainer({
    required IconData icon,
    double? size,
    double? padding,
  }) {
    return iconContainer(
      icon: icon,
      backgroundColor: errorBackground,
      iconColor: error,
      size: size,
      padding: padding,
    );
  }
}