import 'package:flutter/material.dart';

import '../../controllers/system_status_controller.dart';
import '../native_tooltip.dart';

class SystemStatusWidget extends StatelessWidget {
  const SystemStatusWidget({super.key, required this.controller});

  final SystemStatusController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    if (!snapshot.available) {
      return NativeTooltip(
        message: snapshot.error ?? '正在采集系统状态',
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 19),
              SizedBox(width: 8),
              Text('正在采集系统状态'),
            ],
          ),
        ),
      );
    }

    final muted = DefaultTextStyle.of(
      context,
    ).style.color?.withValues(alpha: 0.65);
    return NativeTooltip(
      message:
          '内存 ${_bytes(snapshot.memoryUsedBytes)} / '
          '${_bytes(snapshot.memoryTotalBytes)}\n'
          '下载 ${_speed(snapshot.downloadBytesPerSecond)} · '
          '上传 ${_speed(snapshot.uploadBytesPerSecond)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              size: 19,
              color: Color(0xff22c55e),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CPU ${_percent(snapshot.cpuUsage)}'
                    '  ·  内存 ${_percent(snapshot.memoryUsage)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '↓ ${_speed(snapshot.downloadBytesPerSecond)}'
                    '   ↑ ${_speed(snapshot.uploadBytesPerSecond)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _percent(double? value) =>
      value == null ? '--' : '${(value * 100).round()}%';

  static String _speed(double? bytesPerSecond) =>
      bytesPerSecond == null ? '--' : '${_bytes(bytesPerSecond.round())}/s';

  static String _bytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
