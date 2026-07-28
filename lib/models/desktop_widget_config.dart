enum DesktopWidgetType { codex, gemini, claudeAndGpt, neteaseMusic }

extension DesktopWidgetTypeView on DesktopWidgetType {
  String get title => switch (this) {
    DesktopWidgetType.codex => 'Codex',
    DesktopWidgetType.gemini => 'Gemini',
    DesktopWidgetType.claudeAndGpt => 'Claude & GPT',
    DesktopWidgetType.neteaseMusic => '音乐控制',
  };

  String get source => switch (this) {
    DesktopWidgetType.codex => 'ChatGPT App',
    DesktopWidgetType.gemini || DesktopWidgetType.claudeAndGpt => 'Antigravity',
    DesktopWidgetType.neteaseMusic => 'Windows 系统媒体会话',
  };

  bool get isQuota => this != DesktopWidgetType.neteaseMusic;

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
