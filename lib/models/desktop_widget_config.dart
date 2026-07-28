enum DesktopWidgetType { codex, gemini, claudeAndGpt }

extension DesktopWidgetTypeView on DesktopWidgetType {
  String get title => switch (this) {
    DesktopWidgetType.codex => 'Codex',
    DesktopWidgetType.gemini => 'Gemini',
    DesktopWidgetType.claudeAndGpt => 'Claude & GPT',
  };

  String get source => switch (this) {
    DesktopWidgetType.codex => 'ChatGPT App',
    DesktopWidgetType.gemini || DesktopWidgetType.claudeAndGpt => 'Antigravity',
  };

  static DesktopWidgetType? parse(String? value) {
    for (final type in DesktopWidgetType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

class DesktopWidgetConfig {
  const DesktopWidgetConfig({required this.type, required this.slot});

  final DesktopWidgetType type;
  final int slot;
}
