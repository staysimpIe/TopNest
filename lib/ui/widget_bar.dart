import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/quota_controller.dart';
import '../controllers/music_controller.dart';
import '../controllers/system_status_controller.dart';
import '../controllers/widget_layout_controller.dart';
import '../services/settings_service.dart';
import 'native_tooltip.dart';
import 'widget_slot.dart';

class WidgetBar extends StatefulWidget {
  const WidgetBar({
    super.key,
    required this.layout,
    required this.quota,
    required this.settings,
    required this.music,
    required this.systemStatus,
    required this.onSettings,
    required this.onHide,
  });

  final WidgetLayoutController layout;
  final QuotaController quota;
  final AppSettings settings;
  final MusicController music;
  final SystemStatusController systemStatus;
  final VoidCallback onSettings;
  final VoidCallback onHide;

  @override
  State<WidgetBar> createState() => _WidgetBarState();
}

class _WidgetBarState extends State<WidgetBar> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.layout,
      widget.quota,
      widget.music,
      widget.systemStatus,
      widget.settings,
    ]),
    builder: (context, _) {
      final slots = widget.layout.slots;
      final dark = switch (widget.settings.textColor) {
        TextColorMode.dark => false,
        TextColorMode.light => true,
        TextColorMode.automatic =>
          Theme.of(context).brightness == Brightness.dark,
      };
      return DefaultTextStyle(
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xff17202a),
          fontFamily: 'Microsoft YaHei UI',
          fontSize: 12,
        ),
        child: ColoredBox(
          color: widget.settings.effect == BackgroundEffect.transparent
              ? (dark ? Colors.black : Colors.white).withValues(
                  alpha: widget.settings.opacity,
                )
              : Colors.transparent,
          child: Row(
            children: [
              for (var index = 0; index < 3; index++)
                Expanded(
                  child: WidgetSlot(
                    type: slots[index],
                    snapshots: widget.quota.snapshots,
                    now: _now,
                    music: widget.music,
                    systemStatus: widget.systemStatus,
                  ),
                ),
              SizedBox(
                width: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_updatedText(widget.quota.lastUpdated)),
                    const SizedBox(width: 6),
                    _ActionButton(
                      message: '立即刷新真实额度数据',
                      icon: widget.quota.refreshing
                          ? Icons.hourglass_top
                          : Icons.refresh,
                      onPressed: widget.quota.refresh,
                    ),
                    _ActionButton(
                      message: '打开组件栏设置',
                      icon: Icons.settings_outlined,
                      onPressed: widget.onSettings,
                    ),
                    _ActionButton(
                      message: '收起到系统托盘',
                      icon: Icons.keyboard_arrow_up,
                      onPressed: widget.onHide,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  String _updatedText(DateTime? value) {
    if (value == null) return '尚未更新';
    String two(int number) => number.toString().padLeft(2, '0');
    return '更新 ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.message,
    required this.icon,
    required this.onPressed,
  });

  final String message;
  final IconData icon;
  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => NativeTooltip(
    message: message,
    child: SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 17,
        color: DefaultTextStyle.of(context).style.color,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    ),
  );
}
