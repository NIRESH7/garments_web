import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'color_palette.dart';

final themeProvider = NotifierProvider<ThemeNotifier, Color>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<Color> {
  final _storage = const FlutterSecureStorage();
  static const String _key = 'app_primary_color';

  @override
  Color build() {
    _loadTheme();
    return ColorPalette.primary;
  }

  Future<void> _loadTheme() async {
    final colorHex = await _storage.read(key: _key);
    if (colorHex != null) {
      state = Color(int.parse(colorHex, radix: 16));
    }
  }

  Future<void> setThemeColor(Color color) async {
    state = color;
    await _storage.write(key: _key, value: color.value.toRadixString(16));
  }

  Future<void> resetTheme() async {
    state = ColorPalette.primary;
    await _storage.delete(key: _key);
  }
}
