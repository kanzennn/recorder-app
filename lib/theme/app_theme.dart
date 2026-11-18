import 'package:flutter/material.dart';

// Token dari DESIGN.md (Notion-style). Nama mengikuti token di spesifikasi.
abstract final class NotionColors {
  static const primary = Color(0xFF5645D4);
  static const primaryPressed = Color(0xFF4534B3);
  static const onPrimary = Color(0xFFFFFFFF);
  static const brandNavy = Color(0xFF0A1530);
  static const linkBlue = Color(0xFF0075DE);
  static const brandGreen = Color(0xFF1AAE39);
  static const brandPurple800 = Color(0xFF391C57);
  static const brandOrangeDeep = Color(0xFF793400);
  static const cardTintPeach = Color(0xFFFFE8D4);
  static const cardTintMint = Color(0xFFD9F3E1);
  static const cardTintLavender = Color(0xFFE6E0F5);
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F5F4);
  static const hairline = Color(0xFFE5E3DF);
  static const hairlineStrong = Color(0xFFC8C4BE);
  static const inkDeep = Color(0xFF000000);
  static const ink = Color(0xFF1A1A1A);
  static const charcoal = Color(0xFF37352F);
  static const steel = Color(0xFF787671);
  static const muted = Color(0xFFBBB8B1);
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkMuted = Color(0xFFA4A097);
  static const semanticSuccess = Color(0xFF1AAE39);
  static const semanticWarning = Color(0xFFDD5B00);
  static const semanticError = Color(0xFFE03131);
}

// Radius dari DESIGN.md: tombol & input 8px (persegi, BUKAN pill), kartu 12px.
const double kRadiusButton = 8;
const double kRadiusCard = 12;
const double kRadiusTag = 4;

// Font: spesifikasi memakai Notion Sans (Inter-based). Font itu tidak
// di-bundle di app ini, jadi fallback ke Inter lalu font sistem Android.
const List<String> _fontFallback = [
  'Inter',
  'Roboto',
  'Segoe UI',
  'Helvetica',
  'sans-serif',
];

TextStyle _s(
  double size,
  FontWeight weight, {
  double height = 1.5,
  double letterSpacing = 0,
  Color? color,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: letterSpacing,
  color: color ?? NotionColors.ink,
  fontFamilyFallback: _fontFallback,
);

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: NotionColors.primary,
    onPrimary: NotionColors.onPrimary,
    secondary: NotionColors.linkBlue,
    onSecondary: NotionColors.onPrimary,
    error: NotionColors.semanticError,
    onError: NotionColors.onPrimary,
    surface: NotionColors.canvas,
    onSurface: NotionColors.ink,
    outline: NotionColors.hairlineStrong,
    outlineVariant: NotionColors.hairline,
  );

  final textTheme = TextTheme(
    headlineLarge: _s(36, FontWeight.w600, height: 1.2, letterSpacing: -0.5),
    headlineSmall: _s(28, FontWeight.w600, height: 1.25),
    titleLarge: _s(22, FontWeight.w600, height: 1.3),
    titleMedium: _s(18, FontWeight.w600, height: 1.4),
    titleSmall: _s(16, FontWeight.w500, height: 1.55),
    bodyLarge: _s(16, FontWeight.w400, height: 1.55),
    bodyMedium: _s(14, FontWeight.w400, height: 1.5),
    bodySmall: _s(13, FontWeight.w400, height: 1.4, color: NotionColors.steel),
    labelLarge: _s(14, FontWeight.w500, height: 1.3),
    labelSmall: _s(
      11,
      FontWeight.w600,
      height: 1.4,
      letterSpacing: 1,
      color: NotionColors.steel,
    ),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kRadiusButton),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NotionColors.canvas,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: NotionColors.canvas,
      foregroundColor: NotionColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: _s(18, FontWeight.w600, height: 1.4),
      shape: const Border(bottom: BorderSide(color: NotionColors.hairline)),
    ),
    cardTheme: CardThemeData(
      color: NotionColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: NotionColors.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NotionColors.primary,
        foregroundColor: NotionColors.onPrimary,
        disabledBackgroundColor: NotionColors.hairline,
        disabledForegroundColor: NotionColors.muted,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NotionColors.ink,
        disabledForegroundColor: NotionColors.muted,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        side: const BorderSide(color: NotionColors.hairlineStrong),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NotionColors.linkBlue,
        textStyle: _s(14, FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: NotionColors.hairline,
      space: 1,
      thickness: 1,
    ),
  );
}

// Tag/badge kecil, sesuai badge-tag-* di DESIGN.md (radius 4px, teks tebal kecil).
class TagBadge extends StatelessWidget {
  const TagBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kRadiusTag),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: foreground,
          fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
        ),
      ),
    );
  }
}

// Tile pilihan (responden/huruf/variasi). Terpilih = ink-deep (pola pill-tab-active),
// BUKAN ungu -- ungu dicadangkan untuk CTA utama sesuai DESIGN.md.
class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hasData = false,
  });

  final String label;
  final bool selected;
  final bool hasData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? NotionColors.onDark : NotionColors.ink;
    return Material(
      color: selected ? NotionColors.inkDeep : NotionColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        side: BorderSide(
          color: selected ? NotionColors.inkDeep : NotionColors.hairlineStrong,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusButton),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              if (hasData) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check,
                  size: 14,
                  color: selected
                      ? NotionColors.onDark
                      : NotionColors.brandGreen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
