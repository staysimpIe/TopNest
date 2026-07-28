import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BackgroundEffect { transparent, acrylic }

enum TextColorMode { automatic, dark, light }

class AppSettings extends ChangeNotifier {
  AppSettings(this.preferences) {
    _load();
  }

  final SharedPreferences preferences;
  BackgroundEffect effect = BackgroundEffect.acrylic;
  ThemeMode themeMode = ThemeMode.system;
  TextColorMode textColor = TextColorMode.automatic;
  double opacity = 0.72;
  double acrylicStrength = 0.55;
  bool autoStart = false;
  int refreshMinutes = 1;

  void _load() {
    effect = _enumValue(
      BackgroundEffect.values,
      preferences.getString('effect'),
      BackgroundEffect.acrylic,
    );
    themeMode = _enumValue(
      ThemeMode.values,
      preferences.getString('themeMode'),
      ThemeMode.system,
    );
    textColor = _enumValue(
      TextColorMode.values,
      preferences.getString('textColor'),
      TextColorMode.automatic,
    );
    opacity = (preferences.getDouble('opacity') ?? 0.72).clamp(0, 1);
    acrylicStrength = (preferences.getDouble('acrylicStrength') ?? 0.55).clamp(
      0,
      1,
    );
    autoStart = preferences.getBool('autoStart') ?? false;
    refreshMinutes = (preferences.getInt('refreshMinutes') ?? 1).clamp(1, 60);
  }

  void reload() {
    _load();
    notifyListeners();
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((value) => value.name == name).firstOrNull ?? fallback;

  Future<void> update({
    BackgroundEffect? effect,
    ThemeMode? themeMode,
    TextColorMode? textColor,
    double? opacity,
    double? acrylicStrength,
    bool? autoStart,
    int? refreshMinutes,
  }) async {
    this.effect = effect ?? this.effect;
    this.themeMode = themeMode ?? this.themeMode;
    this.textColor = textColor ?? this.textColor;
    this.opacity = opacity ?? this.opacity;
    this.acrylicStrength = acrylicStrength ?? this.acrylicStrength;
    this.autoStart = autoStart ?? this.autoStart;
    this.refreshMinutes = refreshMinutes ?? this.refreshMinutes;
    await Future.wait([
      preferences.setString('effect', this.effect.name),
      preferences.setString('themeMode', this.themeMode.name),
      preferences.setString('textColor', this.textColor.name),
      preferences.setDouble('opacity', this.opacity),
      preferences.setDouble('acrylicStrength', this.acrylicStrength),
      preferences.setBool('autoStart', this.autoStart),
      preferences.setInt('refreshMinutes', this.refreshMinutes),
    ]);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
