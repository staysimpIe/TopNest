import 'package:flutter/material.dart';

import '../models/desktop_widget_config.dart';
import '../models/quota.dart';
import '../controllers/music_controller.dart';
import 'widgets/lyric_widget.dart';
import 'widgets/netease_music_widget.dart';
import 'widgets/quota_widget.dart';

class WidgetSlot extends StatelessWidget {
  const WidgetSlot({
    super.key,
    required this.type,
    required this.snapshots,
    required this.now,
    required this.music,
    this.showDivider = true,
  });

  final DesktopWidgetType? type;
  final Map<String, QuotaSnapshot> snapshots;
  final DateTime now;
  final MusicController music;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: showDivider
          ? Border(
              left: BorderSide(
                color: DefaultTextStyle.of(
                  context,
                ).style.color!.withValues(alpha: 0.13),
              ),
              right: BorderSide(
                color: DefaultTextStyle.of(
                  context,
                ).style.color!.withValues(alpha: 0.08),
              ),
            )
          : null,
    ),
    child: type == null
        ? const SizedBox.expand()
        : type == DesktopWidgetType.neteaseMusic
        ? NeteaseMusicWidget(controller: music)
        : type == DesktopWidgetType.neteaseLyrics
        ? LyricWidget(controller: music)
        : QuotaWidget(type: type!, snapshot: snapshots[type!.title], now: now),
  );
}
