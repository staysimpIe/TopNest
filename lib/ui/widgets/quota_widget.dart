import 'package:flutter/material.dart';

import '../../models/desktop_widget_config.dart';
import '../../models/quota.dart';
import '../native_tooltip.dart';

class QuotaWidget extends StatelessWidget {
  const QuotaWidget({
    super.key,
    required this.type,
    required this.snapshot,
    required this.now,
  });

  final DesktopWidgetType type;
  final QuotaSnapshot? snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final error = data?.error;
    final message = [
      type.title,
      '数据来源：${type.source}',
      if (data?.stale == true) '当前显示旧数据',
      if (error != null) '错误：$error',
    ].join('\n');
    return NativeTooltip(
      message: message,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: _widgetColor(type),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                type.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: data == null || !data.hasData
                      ? const _UnavailableBadge()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (type != DesktopWidgetType.codex) ...[
                              _WindowProgress(
                                label: '5h',
                                window: data.fiveHour,
                                now: now,
                              ),
                              const SizedBox(width: 14),
                            ],
                            _WindowProgress(
                              label: '周',
                              window: data.weekly,
                              now: now,
                            ),
                            if (type == DesktopWidgetType.codex) ...[
                              const SizedBox(width: 14),
                              _ResetCredits(value: data.resetCreditsAvailable),
                            ],
                            if (data.stale) ...[
                              const SizedBox(width: 7),
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: Color(0xffffb020),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _widgetColor(DesktopWidgetType value) => switch (value) {
    DesktopWidgetType.codex => const Color(0xff42c7ff),
    DesktopWidgetType.gemini => const Color(0xff7c9cff),
    DesktopWidgetType.claudeAndGpt => const Color(0xffc084fc),
    DesktopWidgetType.neteaseMusic => const Color(0xffe83c3c),
  };
}

class _WindowProgress extends StatelessWidget {
  const _WindowProgress({
    required this.label,
    required this.window,
    required this.now,
  });

  final String label;
  final QuotaWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final percent = window.remainingPercent;
    final color = _quotaColor(percent);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: DefaultTextStyle.of(
              context,
            ).style.color?.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        _QuotaProgressBar(percent: percent, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            percent == null ? '--' : '${percent.round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          formatQuotaCountdown(window.resetsAt, now),
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _quotaColor(double? value) {
    if (value == null) return const Color(0xff94a3b8);
    if (value > 50) return const Color(0xff22c55e);
    if (value > 20) return const Color(0xfff59e0b);
    return const Color(0xffef4444);
  }
}

class _QuotaProgressBar extends StatelessWidget {
  const _QuotaProgressBar({required this.percent, required this.color});

  final double? percent;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox(
      width: 54,
      height: 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color:
                DefaultTextStyle.of(
                  context,
                ).style.color?.withValues(alpha: 0.14) ??
                Colors.white24,
          ),
          if (percent != null)
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent! / 100).clamp(0, 1),
              child: ColoredBox(color: color),
            ),
        ],
      ),
    ),
  );
}

class _ResetCredits extends StatelessWidget {
  const _ResetCredits({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('重置 ${value ?? '未提供'}'),
  );
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xffef4444).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: const Color(0xffef4444).withValues(alpha: 0.45),
      ),
    ),
    child: const Text(
      '不可用',
      style: TextStyle(color: Color(0xffff6b6b), fontWeight: FontWeight.w600),
    ),
  );
}

String formatQuotaCountdown(DateTime? reset, DateTime now) {
  if (reset == null) return '未提供';
  final duration = reset.difference(now);
  if (duration.isNegative) return '等待刷新';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final buffer = StringBuffer();
  if (days > 0) buffer.write('$days天');
  if (days > 0 || hours > 0) buffer.write('$hours小时');
  buffer
    ..write('$minutes分')
    ..write('$seconds秒');
  return buffer.toString();
}
