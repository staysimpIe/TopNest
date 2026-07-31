import 'package:flutter/services.dart';

import '../models/system_status.dart';

abstract interface class SystemStatusReader {
  Future<SystemMetricsSample> read();
}

class WindowsSystemStatusService implements SystemStatusReader {
  static const _channel = MethodChannel('topnest/appbar');

  @override
  Future<SystemMetricsSample> read() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getSystemStatus',
    );
    if (value == null) throw StateError('Windows 未返回系统状态');

    int integer(String key) {
      final number = value[key];
      if (number is! num) throw StateError('系统状态缺少 $key');
      return number.toInt();
    }

    return SystemMetricsSample(
      tickMilliseconds: integer('tickMilliseconds'),
      idleTime: integer('idleTime'),
      kernelTime: integer('kernelTime'),
      userTime: integer('userTime'),
      memoryUsedBytes: integer('memoryUsedBytes'),
      memoryTotalBytes: integer('memoryTotalBytes'),
      receivedBytes: integer('receivedBytes'),
      sentBytes: integer('sentBytes'),
    );
  }
}
