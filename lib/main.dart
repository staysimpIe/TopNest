import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/quota_controller.dart';
import 'controllers/music_controller.dart';
import 'controllers/widget_layout_controller.dart';
import 'providers/antigravity_provider.dart';
import 'providers/codex_provider.dart';
import 'services/settings_service.dart';
import 'services/windows_media_service.dart';
import 'services/windows_shell_service.dart';
import 'ui/settings_window.dart';
import 'ui/widget_bar.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final controller = await WindowController.fromCurrentEngine();
  if (controller.arguments == 'settings' || args.contains('--settings')) {
    await _configureSettingsWindow();
    runApp(SettingsWindow(windowController: controller));
    return;
  }
  await _configureMainWindow();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    DesktopWidgetBarApp(preferences: preferences, windowController: controller),
  );
}

Future<void> _configureMainWindow() async {
  const options = WindowOptions(
    size: Size(1200, 36),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(true);
    await windowManager.show();
  });
}

Future<void> _configureSettingsWindow() async {
  const options = WindowOptions(
    size: Size(900, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setTitle('组件栏设置');
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
}

class DesktopWidgetBarApp extends StatefulWidget {
  const DesktopWidgetBarApp({
    super.key,
    required this.preferences,
    required this.windowController,
  });

  final SharedPreferences preferences;
  final WindowController windowController;

  @override
  State<DesktopWidgetBarApp> createState() => _DesktopWidgetBarAppState();
}

class _DesktopWidgetBarAppState extends State<DesktopWidgetBarApp>
    with WindowListener, TrayListener {
  final _shell = WindowsShellService();
  late final WidgetLayoutController _layout;
  late final QuotaController _quota;
  late final MusicController _music;
  late final AppSettings _settings;
  File? _temporaryTrayIcon;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _layout = WidgetLayoutController(widget.preferences)..load();
    _settings = AppSettings(widget.preferences)..addListener(_applySettings);
    _quota = QuotaController([CodexQuotaProvider(), AntigravityQuotaProvider()])
      ..start(Duration(minutes: _settings.refreshMinutes));
    _music = MusicController(WindowsMediaService())..start();
    windowManager.addListener(this);
    trayManager.addListener(this);
    widget.windowController.setWindowMethodHandler((call) async {
      if (call.method == 'settingsSaved') {
        await _reloadSettings(call.arguments);
      }
      if (call.method == 'appearanceChanged') {
        await _applyAppearanceChange(call.arguments);
      }
      if (call.method == 'refresh') await _quota.refresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _shell.register();
      await _shell.reposition();
      await _applySettingsAfterWindowShown();
      await _installTray();
    });
  }

  Future<void> _installTray() async {
    final bytes = await rootBundle.load('assets/tray_icon.ico');
    final file = File(
      '${Directory.systemTemp.path}\\desktop_widget_bar_tray.ico',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    _temporaryTrayIcon = file;
    await trayManager.setIcon(file.path);
    await trayManager.setToolTip('顶栖（TopNest）');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示组件栏'),
          MenuItem(key: 'refresh', label: '立即刷新'),
          MenuItem(key: 'settings', label: '设置'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> _applySettings() async {
    if (!mounted) return;
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ??
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    final dark =
        _settings.themeMode == ThemeMode.dark ||
        (_settings.themeMode == ThemeMode.system &&
            brightness == Brightness.dark);
    final acrylic = _settings.effect == BackgroundEffect.acrylic;
    final effectStrength = acrylic
        ? dark
              ? (1 / 255) + _settings.acrylicStrength * (0.72 - 1 / 255)
              : 0.055 + _settings.acrylicStrength * (0.32 - 0.055)
        : _settings.opacity;
    await _shell.setEffect(
      acrylic: acrylic,
      dark: dark,
      alpha: effectStrength,
      red: dark ? 22 : 238,
      green: dark ? 24 : 242,
      blue: dark ? 30 : 248,
    );
  }

  Future<void> _applySettingsAfterWindowShown() async {
    // 等待 Windows 完成窗口显示和 AppBar 定位，避免效果被后续流程覆盖。
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) await _applySettings();
  }

  Future<void> _showBar() async {
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await _shell.register();
    await _shell.reposition();
    await _applySettingsAfterWindowShown();
  }

  Future<void> _hideBar() async {
    await _shell.hideTooltip();
    await _shell.unregister();
    await windowManager.hide();
  }

  Future<void> _reloadSettings(Object? arguments) async {
    await widget.preferences.reload();
    if (arguments is Map && arguments['slots'] is List) {
      _layout.replaceByNames(arguments['slots'] as List);
    } else {
      _layout.load();
    }
    final oldInterval = _settings.refreshMinutes;
    _settings.reload();
    if (oldInterval != _settings.refreshMinutes) {
      _quota.start(Duration(minutes: _settings.refreshMinutes));
    }
    await _applySettings();
  }

  Future<void> _applyAppearanceChange(Object? arguments) async {
    if (arguments is! Map) return;
    T? enumValue<T extends Enum>(List<T> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    await _settings.update(
      effect: enumValue(BackgroundEffect.values, arguments['effect']),
      themeMode: enumValue(ThemeMode.values, arguments['themeMode']),
      textColor: enumValue(TextColorMode.values, arguments['textColor']),
      opacity: (arguments['opacity'] as num?)?.toDouble(),
      acrylicStrength: (arguments['acrylicStrength'] as num?)?.toDouble(),
    );
  }

  Future<void> _openSettings() async {
    final windows = await WindowController.getAll();
    for (final window in windows) {
      if (window.arguments == 'settings') {
        await window.show();
        await window.invokeMethod('focus');
        return;
      }
    }
    final window = await WindowController.create(
      const WindowConfiguration(arguments: 'settings'),
    );
    await window.show();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    final windows = await WindowController.getAll();
    for (final window in windows) {
      if (window.arguments == 'settings') await window.invokeMethod('close');
    }
    await _shell.unregister();
    await trayManager.destroy();
    try {
      if (await _temporaryTrayIcon?.exists() == true) {
        await _temporaryTrayIcon?.delete();
      }
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (!_exiting) _hideBar();
  }

  @override
  void onTrayIconMouseDown() => _showBar();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showBar();
        return;
      case 'refresh':
        _quota.refresh();
        return;
      case 'settings':
        _openSettings();
        return;
      case 'exit':
        _exit();
        return;
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _settings.removeListener(_applySettings);
    _layout.dispose();
    _quota.dispose();
    _music.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settings,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '顶栖（TopNest）',
      themeMode: _settings.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Microsoft YaHei UI',
        dividerColor: Colors.black12,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Microsoft YaHei UI',
        dividerColor: Colors.white12,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox(
          height: 36,
          child: WidgetBar(
            layout: _layout,
            quota: _quota,
            music: _music,
            settings: _settings,
            onSettings: _openSettings,
            onHide: _hideBar,
          ),
        ),
      ),
    ),
  );
}
