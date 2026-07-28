import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/desktop_widget_config.dart';

class WidgetLayoutController extends ChangeNotifier {
  WidgetLayoutController(this._preferences);

  static const _key = 'widgetSlots';
  static const defaultSlots = <DesktopWidgetType?>[
    DesktopWidgetType.codex,
    DesktopWidgetType.gemini,
    DesktopWidgetType.claudeAndGpt,
  ];

  final SharedPreferences _preferences;
  List<DesktopWidgetType?> _slots = List.of(defaultSlots);

  List<DesktopWidgetType?> get slots => List.unmodifiable(_slots);

  void load() {
    final values = _preferences.getStringList(_key);
    if (values == null) return;
    final parsed = List<DesktopWidgetType?>.filled(3, null);
    final seen = <DesktopWidgetType>{};
    for (var index = 0; index < 3 && index < values.length; index++) {
      final type = DesktopWidgetTypeView.parse(
        values[index].isEmpty ? null : values[index],
      );
      if (type != null && seen.add(type)) parsed[index] = type;
    }
    _slots = parsed;
    notifyListeners();
  }

  bool add(DesktopWidgetType type) {
    if (_slots.contains(type)) return false;
    final empty = _slots.indexOf(null);
    if (empty < 0) return false;
    _slots[empty] = type;
    notifyListeners();
    return true;
  }

  bool remove(DesktopWidgetType type) {
    final index = _slots.indexOf(type);
    if (index < 0) return false;
    _slots[index] = null;
    notifyListeners();
    return true;
  }

  void move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= 3 ||
        newIndex < 0 ||
        newIndex >= 3) {
      return;
    }
    final value = _slots[oldIndex];
    _slots[oldIndex] = _slots[newIndex];
    _slots[newIndex] = value;
    notifyListeners();
  }

  void replace(List<DesktopWidgetType?> slots) {
    final normalized = List<DesktopWidgetType?>.filled(3, null);
    final seen = <DesktopWidgetType>{};
    for (var i = 0; i < 3 && i < slots.length; i++) {
      final value = slots[i];
      if (value != null && seen.add(value)) normalized[i] = value;
    }
    _slots = normalized;
    notifyListeners();
  }

  void replaceByNames(Iterable<Object?> names) {
    replace(
      names
          .take(3)
          .map(
            (name) => DesktopWidgetTypeView.parse(
              name is String && name.isNotEmpty ? name : null,
            ),
          )
          .toList(),
    );
  }

  Future<void> save() => _preferences.setStringList(
    _key,
    _slots.map((value) => value?.name ?? '').toList(),
  );
}
