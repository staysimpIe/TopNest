import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/widget_layout_controller.dart';
import '../models/desktop_widget_config.dart';
import '../services/settings_service.dart';

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key, required this.windowController});

  final WindowController windowController;

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  AppSettings? _settings;
  WidgetLayoutController? _layout;
  WindowController? _mainWindow;
  List<DesktopWidgetType?> _draftSlots = [];
  int _page = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.windowController.setWindowMethodHandler((call) async {
      if (call.method == 'focus') await windowManager.focus();
      if (call.method == 'close') await windowManager.close();
    });
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final layout = WidgetLayoutController(preferences)..load();
    final windows = await WindowController.getAll();
    for (final window in windows) {
      if (window.windowId != widget.windowController.windowId &&
          window.arguments != 'settings') {
        _mainWindow = window;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _layout = layout;
      _draftSlots = List.of(layout.slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(child: CircularProgressIndicator()),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '组件栏设置',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2563eb),
          brightness: Brightness.light,
          surface: const Color(0xfff8fafc),
        ),
        scaffoldBackgroundColor: const Color(0xfff8fafc),
        dividerColor: const Color(0xffe2e8f0),
        fontFamily: 'Microsoft YaHei UI',
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffffffff),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffdbe3ef)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffdbe3ef)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7aa2ff),
          brightness: Brightness.dark,
          surface: const Color(0xff15181e),
        ),
        scaffoldBackgroundColor: const Color(0xff111318),
        dividerColor: const Color(0xff2a303a),
        fontFamily: 'Microsoft YaHei UI',
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff1b1f27),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xff303744)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xff303744)),
          ),
        ),
      ),
      themeMode: settings.themeMode,
      home: Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                _SettingsSidebar(
                  selectedIndex: _page,
                  onSelected: (value) => setState(() => _page = value),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _pageBody(settings)),
                      _SettingsBottomBar(
                        immediate: _page == 1,
                        saving: _saving,
                        onSave: _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 54,
              child: _WindowDragArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBody(AppSettings settings) => switch (_page) {
    0 => _GeneralPanel(settings: settings),
    1 => _AppearancePanel(
      settings: settings,
      onChanged: _applyAppearanceImmediately,
    ),
    _ => _ComponentPanel(
      slots: _draftSlots,
      onChanged: (slots) => setState(() => _draftSlots = slots),
    ),
  };

  Future<void> _applyAppearanceImmediately() async {
    final settings = _settings!;
    await settings.update();
    var mainWindow = _mainWindow;
    if (mainWindow == null) {
      final windows = await WindowController.getAll();
      for (final window in windows) {
        if (window.windowId != widget.windowController.windowId &&
            window.arguments != 'settings') {
          mainWindow = window;
          _mainWindow = window;
          break;
        }
      }
    }
    if (mainWindow != null) {
      await mainWindow.invokeMethod('appearanceChanged', {
        'effect': settings.effect.name,
        'themeMode': settings.themeMode.name,
        'textColor': settings.textColor.name,
        'opacity': settings.opacity,
        'acrylicStrength': settings.acrylicStrength,
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final settings = _settings!;
    _layout!.replace(_draftSlots);
    await _layout!.save();
    await settings.update();
    launchAtStartup.setup(
      appName: '顶栖（TopNest）',
      appPath: Platform.resolvedExecutable,
    );
    if (settings.autoStart) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    var mainWindow = _mainWindow;
    if (mainWindow == null) {
      final windows = await WindowController.getAll();
      for (final window in windows) {
        if (window.windowId != widget.windowController.windowId &&
            window.arguments != 'settings') {
          mainWindow = window;
          _mainWindow = window;
          break;
        }
      }
    }
    if (mainWindow != null) {
      await mainWindow.invokeMethod('settingsSaved', {
        'slots': _layout!.slots.map((slot) => slot?.name ?? '').toList(),
      });
    }
    if (mounted) setState(() => _saving = false);
    await windowManager.close();
  }
}

class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.move,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(windowManager.startDragging()),
      child: const SizedBox.expand(),
    ),
  );
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.tune_rounded, '通用'),
    (Icons.palette_outlined, '外观'),
    (Icons.widgets_outlined, '组件管理'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 164,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff15181e) : const Color(0xfff1f5f9),
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '组件栏设置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < _items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selectedIndex == index
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _items[index].$1,
                          size: 20,
                          color: selectedIndex == index
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _items[index].$2,
                          style: TextStyle(
                            fontWeight: selectedIndex == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsBottomBar extends StatelessWidget {
  const _SettingsBottomBar({
    required this.immediate,
    required this.saving,
    required this.onSave,
  });

  final bool immediate;
  final bool saving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        if (immediate)
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
                const Text('外观更改会自动保存并立即生效'),
              ],
            ),
          )
        else
          const Spacer(),
        TextButton(
          onPressed: windowManager.close,
          child: Text(immediate ? '关闭' : '取消'),
        ),
        if (!immediate) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(saving ? '保存中…' : '保存并应用'),
          ),
        ],
      ],
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _GeneralPanel extends StatefulWidget {
  const _GeneralPanel({required this.settings});
  final AppSettings settings;

  @override
  State<_GeneralPanel> createState() => _GeneralPanelState();
}

class _GeneralPanelState extends State<_GeneralPanel> {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
    children: [
      const _PageHeader(title: '通用', description: '设置组件栏的数据刷新与启动行为。'),
      const SizedBox(height: 24),
      _SettingsSection(
        title: '数据刷新',
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('额度刷新间隔'),
                  SizedBox(height: 4),
                  Text('定时更新组件栏中的额度和重置时间。', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int>(
                initialValue: widget.settings.refreshMinutes,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: const [1, 5, 10, 15, 30, 60]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) widget.settings.refreshMinutes = value;
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _SettingsSection(
        title: '启动',
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('开机自动启动'),
          subtitle: const Text('登录 Windows 后自动显示顶栖。'),
          value: widget.settings.autoStart,
          onChanged: (value) =>
              setState(() => widget.settings.autoStart = value),
        ),
      ),
    ],
  );
}

class _AppearancePanel extends StatefulWidget {
  const _AppearancePanel({required this.settings, required this.onChanged});
  final AppSettings settings;
  final Future<void> Function() onChanged;

  @override
  State<_AppearancePanel> createState() => _AppearancePanelState();
}

class _AppearancePanelState extends State<_AppearancePanel> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        const _PageHeader(title: '外观', description: '调整会实时保存并应用到顶部组件栏。'),
        const SizedBox(height: 24),
        _SettingsSection(
          title: '背景效果',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<BackgroundEffect>(
                segments: const [
                  ButtonSegment(
                    value: BackgroundEffect.transparent,
                    icon: Icon(Icons.blur_off_rounded),
                    label: Text('全透明'),
                  ),
                  ButtonSegment(
                    value: BackgroundEffect.acrylic,
                    icon: Icon(Icons.blur_on_rounded),
                    label: Text('毛玻璃'),
                  ),
                ],
                selected: {settings.effect},
                onSelectionChanged: (value) {
                  setState(() => settings.effect = value.first);
                  unawaited(widget.onChanged());
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      settings.effect == BackgroundEffect.transparent
                          ? '背景透明度'
                          : '毛玻璃强度',
                    ),
                  ),
                  Text(
                    '${((settings.effect == BackgroundEffect.transparent ? settings.opacity : settings.acrylicStrength) * 100).round()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: settings.effect == BackgroundEffect.transparent
                    ? settings.opacity
                    : settings.acrylicStrength,
                divisions: 20,
                onChanged: (value) => setState(() {
                  if (settings.effect == BackgroundEffect.transparent) {
                    settings.opacity = value;
                  } else {
                    settings.acrylicStrength = value;
                  }
                  unawaited(widget.onChanged());
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsSection(
          title: '颜色',
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ThemeMode>(
                  initialValue: settings.themeMode,
                  decoration: const InputDecoration(labelText: '主题'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('跟随系统'),
                    ),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                  ],
                  onChanged: (value) {
                    setState(() => settings.themeMode = value!);
                    unawaited(widget.onChanged());
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<TextColorMode>(
                  initialValue: settings.textColor,
                  decoration: const InputDecoration(labelText: '顶部栏文字'),
                  items: const [
                    DropdownMenuItem(
                      value: TextColorMode.automatic,
                      child: Text('自动'),
                    ),
                    DropdownMenuItem(
                      value: TextColorMode.dark,
                      child: Text('深色文字'),
                    ),
                    DropdownMenuItem(
                      value: TextColorMode.light,
                      child: Text('浅色文字'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => settings.textColor = value!);
                    unawaited(widget.onChanged());
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ComponentGroup { all, quota, music, system }

extension on _ComponentGroup {
  String get title => switch (this) {
    _ComponentGroup.all => '全部组件',
    _ComponentGroup.quota => '额度统计',
    _ComponentGroup.music => '音乐',
    _ComponentGroup.system => '系统',
  };

  IconData get icon => switch (this) {
    _ComponentGroup.all => Icons.grid_view_rounded,
    _ComponentGroup.quota => Icons.data_usage_rounded,
    _ComponentGroup.music => Icons.music_note_rounded,
    _ComponentGroup.system => Icons.monitor_heart_outlined,
  };
}

class _ComponentPanel extends StatefulWidget {
  const _ComponentPanel({required this.slots, required this.onChanged});

  final List<DesktopWidgetType?> slots;
  final ValueChanged<List<DesktopWidgetType?>> onChanged;

  @override
  State<_ComponentPanel> createState() => _ComponentPanelState();
}

class _ComponentPanelState extends State<_ComponentPanel> {
  _ComponentGroup _group = _ComponentGroup.all;

  List<DesktopWidgetType> get _visibleTypes => switch (_group) {
    _ComponentGroup.all => DesktopWidgetType.values,
    _ComponentGroup.quota =>
      DesktopWidgetType.values.where((type) => type.isQuota).toList(),
    _ComponentGroup.music =>
      DesktopWidgetType.values.where((type) => type.isMusic).toList(),
    _ComponentGroup.system =>
      DesktopWidgetType.values
          .where((type) => type == DesktopWidgetType.systemStatus)
          .toList(),
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: _PageHeader(
                title: '组件管理',
                description: '选择组件加入顶部栏，拖动当前预览可调整显示顺序。',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '已添加 ${widget.slots.whereType<DesktopWidgetType>().length}/3',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          height: 104,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_week_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '当前顶部栏预览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '拖动组件进行排序',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: const Color(0xff07111f),
                    child: Row(
                      children: [
                        for (var index = 0; index < 3; index++)
                          Expanded(
                            child: _PreviewSlot(
                              index: index,
                              slots: widget.slots,
                              onChanged: widget.onChanged,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 5, 9, 12),
                      child: Text(
                        '组件分组',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    for (final group in _ComponentGroup.values)
                      _GroupButton(
                        group: group,
                        selected: _group == group,
                        count: switch (group) {
                          _ComponentGroup.all =>
                            DesktopWidgetType.values.length,
                          _ComponentGroup.quota =>
                            DesktopWidgetType.values
                                .where((type) => type.isQuota)
                                .length,
                          _ComponentGroup.music =>
                            DesktopWidgetType.values
                                .where((type) => type.isMusic)
                                .length,
                          _ComponentGroup.system =>
                            DesktopWidgetType.values
                                .where(
                                  (type) =>
                                      type == DesktopWidgetType.systemStatus,
                                )
                                .length,
                        },
                        onTap: () => setState(() => _group = group),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '后续新增的内置组件会归入对应分组。',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.62,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _visibleTypes.length,
                  itemBuilder: (context, index) {
                    final type = _visibleTypes[index];
                    return _ComponentCard(
                      type: type,
                      selected: widget.slots.contains(type),
                      onTap: () => _toggle(type),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _toggle(DesktopWidgetType type) {
    final next = List<DesktopWidgetType?>.of(widget.slots);
    if (next.contains(type)) {
      next[next.indexOf(type)] = null;
    } else {
      final empty = next.indexOf(null);
      if (empty >= 0) next[empty] = type;
    }
    widget.onChanged(next);
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.group,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final _ComponentGroup group;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Icon(
                group.icon,
                size: 18,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text('$count', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DesktopWidgetType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.75)
                : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: const Color(0xff07111f),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _MiniWidgetPreview(type: type)),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xff07111f),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 18,
                            color: selected
                                ? const Color(0xff6ea8ff)
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    type.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.isQuota
                        ? '额度统计'
                        : type.isMusic
                        ? '音乐'
                        : '系统',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              type.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MiniWidgetPreview extends StatelessWidget {
  const _MiniWidgetPreview({required this.type, this.compact = false});

  final DesktopWidgetType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      DesktopWidgetType.codex => const Color(0xff4ade80),
      DesktopWidgetType.gemini => const Color(0xff60a5fa),
      DesktopWidgetType.claudeAndGpt => const Color(0xffc084fc),
      DesktopWidgetType.neteaseMusic => const Color(0xffef4444),
      DesktopWidgetType.neteaseLyrics => const Color(0xffef4444),
      DesktopWidgetType.systemStatus => const Color(0xff22c55e),
    };
    final metric = switch (type) {
      DesktopWidgetType.codex => '周 56%',
      DesktopWidgetType.gemini => '72% · 28%',
      DesktopWidgetType.claudeAndGpt => '68% · 41%',
      DesktopWidgetType.neteaseMusic => '播放中',
      DesktopWidgetType.neteaseLyrics => '正在播放的歌词',
      DesktopWidgetType.systemStatus => 'CPU 17% · 内存 63%',
    };
    final detail = switch (type) {
      DesktopWidgetType.codex =>
        compact ? '4天 23小时 · 重置 2' : '4天 23小时 36分钟 2秒   重置 2',
      DesktopWidgetType.gemini => '3天 12小时 · 1天 6小时',
      DesktopWidgetType.claudeAndGpt => '4天 8小时 · 2天 19小时',
      DesktopWidgetType.neteaseMusic => '歌曲名称 · 歌手名称',
      DesktopWidgetType.neteaseLyrics => '下一句歌词',
      DesktopWidgetType.systemStatus => '↓ 1.2 MB/s · ↑ 82.0 KB/s',
    };
    final progresses = switch (type) {
      DesktopWidgetType.codex => const [0.56],
      DesktopWidgetType.gemini => const [0.72, 0.28],
      DesktopWidgetType.claudeAndGpt => const [0.68, 0.41],
      DesktopWidgetType.neteaseMusic => const [0.72],
      DesktopWidgetType.neteaseLyrics => const [0.45],
      DesktopWidgetType.systemStatus => const [0.17, 0.63],
    };
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 9,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: compact ? 25 : 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 9 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      metric,
                      style: TextStyle(
                        color: color,
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 7),
                Row(
                  children: [
                    for (var index = 0; index < progresses.length; index++) ...[
                      Expanded(
                        child: _PreviewProgress(
                          color: color,
                          progress: progresses[index],
                        ),
                      ),
                      if (index != progresses.length - 1)
                        SizedBox(width: compact ? 4 : 7),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: compact ? 7 : 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewProgress extends StatelessWidget {
  const _PreviewProgress({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      height: 5,
      color: Colors.white12,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        child: ColoredBox(color: color),
      ),
    ),
  );
}

class _PreviewSlot extends StatelessWidget {
  const _PreviewSlot({
    required this.index,
    required this.slots,
    required this.onChanged,
  });

  final int index;
  final List<DesktopWidgetType?> slots;
  final ValueChanged<List<DesktopWidgetType?>> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = slots[index];
    final content = type == null
        ? const Center(
            child: Text(
              '空槽位',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          )
        : _MiniWidgetPreview(type: type, compact: true);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        final next = List<DesktopWidgetType?>.of(slots);
        final value = next[details.data];
        next[details.data] = next[index];
        next[index] = value;
        onChanged(next);
      },
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Colors.transparent
              : const Color(0xff4f7cff).withValues(alpha: 0.24),
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            bottom: BorderSide(
              color: candidates.isEmpty
                  ? Colors.transparent
                  : const Color(0xff75a7ff),
              width: 2,
            ),
          ),
        ),
        child: type == null
            ? content
            : Draggable<int>(
                data: index,
                feedback: Material(
                  color: const Color(0xff081120),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 190, height: 52, child: content),
                ),
                childWhenDragging: const Center(
                  child: Text(
                    '移动到其他槽位',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
                child: content,
              ),
      ),
    );
  }
}
