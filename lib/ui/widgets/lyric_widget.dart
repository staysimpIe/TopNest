import 'package:flutter/material.dart';

import '../../controllers/music_controller.dart';
import '../native_tooltip.dart';

class LyricWidget extends StatefulWidget {
  const LyricWidget({super.key, required this.controller});

  final MusicController controller;

  @override
  State<LyricWidget> createState() => _LyricWidgetState();
}

class _LyricWidgetState extends State<LyricWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late _LyricContent _current;
  _LyricContent? _previous;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
    _current = _content;
  }

  @override
  void didUpdateWidget(covariant LyricWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _content;
    if (next.key == _current.key) return;
    _previous = _current;
    _current = next;
    _animation.forward(from: 0);
  }

  _LyricContent get _content {
    final state = widget.controller.state;
    final current = widget.controller.currentLyric;
    final next = widget.controller.nextLyric;
    final hint = !state.available
        ? '请打开支持 SMTC 的音乐播放器'
        : widget.controller.loadingLyrics
        ? '正在读取歌词…'
        : widget.controller.lyricError ?? '等待歌词播放';
    final primary = current?.text ?? hint;
    final secondary =
        next?.text ??
        [
          state.title,
          state.artist,
        ].where((value) => value.isNotEmpty).join(' · ');
    return _LyricContent(
      key: current?.timeMs.toString() ?? '$primary\n$secondary',
      primary: primary,
      secondary: secondary,
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NativeTooltip(
      message: [
        _current.primary,
        _current.secondary,
      ].where((value) => value.isNotEmpty).join('\n'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(
              Icons.lyrics_rounded,
              size: 18,
              color: Color(0xffe83c3c),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, constraints) {
                      final offset = constraints.maxHeight;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_previous != null)
                            Transform.translate(
                              offset: Offset(0, -offset * _animation.value),
                              child: Opacity(
                                opacity: 1 - _animation.value,
                                child: _LyricText(content: _previous!),
                              ),
                            ),
                          Transform.translate(
                            offset: Offset(0, offset * (1 - _animation.value)),
                            child: Opacity(
                              opacity: _animation.value,
                              child: _LyricText(content: _current),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricContent {
  const _LyricContent({
    required this.key,
    required this.primary,
    required this.secondary,
  });

  final String key;
  final String primary;
  final String secondary;
}

class _LyricText extends StatelessWidget {
  const _LyricText({required this.content});

  final _LyricContent content;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        content.primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      if (content.secondary.isNotEmpty)
        Text(
          content.secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: DefaultTextStyle.of(
              context,
            ).style.color?.withValues(alpha: 0.58),
          ),
        ),
    ],
  );
}
