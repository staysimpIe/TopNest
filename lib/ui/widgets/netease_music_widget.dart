import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/music_controller.dart';
import '../native_tooltip.dart';

class NeteaseMusicWidget extends StatelessWidget {
  const NeteaseMusicWidget({super.key, required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final coverPixelSize = (28 * MediaQuery.devicePixelRatioOf(context)).round();
    if (!state.available) {
      return NativeTooltip(
        message: state.error ?? '请打开音乐播放器并播放歌曲',
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.music_note_rounded, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '暂无音乐播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subtitle = [
      state.artist,
      state.album,
    ].where((value) => value.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox.square(
              dimension: 28,
              child: state.cover != null
                  ? Image.memory(
                      state.cover!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      cacheWidth: coverPixelSize,
                      cacheHeight: coverPixelSize,
                    )
                  : state.coverUrl != null
                  ? Image.network(
                      state.coverUrl!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      cacheWidth: coverPixelSize,
                      cacheHeight: coverPixelSize,
                      errorBuilder: (_, _, _) => const _MusicPlaceholder(),
                    )
                  : const _MusicPlaceholder(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NativeTooltip(
              message: [
                state.title,
                subtitle,
              ].where((e) => e.isNotEmpty).join('\n'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.title.isEmpty ? '未知歌曲' : state.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: DefaultTextStyle.of(
                          context,
                        ).style.color?.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _MusicButton(
            message: '上一首',
            icon: Icons.skip_previous_rounded,
            enabled: state.canPrevious,
            onPressed: controller.previous,
          ),
          _MusicButton(
            message: state.playing ? '暂停' : '播放',
            icon: state.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            enabled: state.canPlayPause,
            onPressed: controller.togglePlayPause,
          ),
          _MusicButton(
            message: '下一首',
            icon: Icons.skip_next_rounded,
            enabled: state.canNext,
            onPressed: controller.next,
          ),
        ],
      ),
    );
  }
}

class _MusicPlaceholder extends StatelessWidget {
  const _MusicPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xffe83c3c),
    child: Icon(Icons.music_note_rounded, size: 17, color: Colors.white),
  );
}

class _MusicButton extends StatelessWidget {
  const _MusicButton({
    required this.message,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String message;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => NativeTooltip(
    message: message,
    child: SizedBox.square(
      dimension: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 17,
        color: DefaultTextStyle.of(context).style.color,
        disabledColor: DefaultTextStyle.of(
          context,
        ).style.color?.withValues(alpha: 0.28),
        onPressed: enabled ? () => unawaited(onPressed()) : null,
        icon: Icon(icon),
      ),
    ),
  );
}
