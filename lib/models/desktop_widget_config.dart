enum DesktopWidgetType {
  codex,
  gemini,
  claudeAndGpt,
  neteaseMusic,
  neteaseLyrics,
  systemStatus,
}

extension DesktopWidgetTypeView on DesktopWidgetType {
  String get title => switch (this) {
    DesktopWidgetType.codex => 'Codex',
    DesktopWidgetType.gemini => 'Gemini',
    DesktopWidgetType.claudeAndGpt => 'Claude & GPT',
    DesktopWidgetType.neteaseMusic => '音乐控制',
    DesktopWidgetType.neteaseLyrics => '歌词',
    DesktopWidgetType.systemStatus => '系统状态',
  };

  String get source => switch (this) {
    DesktopWidgetType.codex => 'ChatGPT App',
    DesktopWidgetType.gemini || DesktopWidgetType.claudeAndGpt => 'Antigravity',
    DesktopWidgetType.neteaseMusic => 'Windows 系统媒体会话',
    DesktopWidgetType.neteaseLyrics => 'Windows SMTC · 网易云 / LRCLIB',
    DesktopWidgetType.systemStatus => 'Windows 系统',
  };

  bool get isQuota => switch (this) {
    DesktopWidgetType.codex ||
    DesktopWidgetType.gemini ||
    DesktopWidgetType.claudeAndGpt => true,
    DesktopWidgetType.neteaseMusic ||
    DesktopWidgetType.neteaseLyrics ||
    DesktopWidgetType.systemStatus => false,
  };

  bool get isMusic =>
      this == DesktopWidgetType.neteaseMusic ||
      this == DesktopWidgetType.neteaseLyrics;

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
