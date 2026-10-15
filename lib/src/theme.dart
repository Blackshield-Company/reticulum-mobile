import 'package:flutter/material.dart';

/// Blackshield synthwave palette.
const kMagenta = Color(0xFFFF2E97);
const kCyan = Color(0xFF00E5FF);
const kBg = Color(0xFF0D0B1A);
const kSurface = Color(0xFF1A1630);

ThemeData blackshieldTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kMagenta,
        secondary: kCyan,
        surface: kSurface,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: kSurface, elevation: 0),
    );
