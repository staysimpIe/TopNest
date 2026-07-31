import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/system_status.dart';
import '../services/windows_system_status_service.dart';

class SystemStatusController extends ChangeNotifier {
  SystemStatusController(this._reader);

  final SystemStatusReader _reader;
  Timer? _timer;
  bool _refreshing = false;
  SystemMetricsSample? _previous;
  SystemStatusSnapshot _snapshot = const SystemStatusSnapshot();

  SystemStatusSnapshot get snapshot => _snapshot;

  void start() {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final sample = await _reader.read();
      final previous = _previous;
      final memoryUsage = sample.memoryTotalBytes <= 0
          ? null
          : sample.memoryUsedBytes / sample.memoryTotalBytes;
      double? cpuUsage;
      double? downloadSpeed;
      double? uploadSpeed;
      if (previous != null) {
        final kernelDelta = sample.kernelTime - previous.kernelTime;
        final userDelta = sample.userTime - previous.userTime;
        final idleDelta = sample.idleTime - previous.idleTime;
        final totalDelta = kernelDelta + userDelta;
        if (totalDelta > 0 && idleDelta >= 0) {
          cpuUsage = ((totalDelta - idleDelta) / totalDelta).clamp(0, 1);
        }

        final elapsedMilliseconds =
            sample.tickMilliseconds - previous.tickMilliseconds;
        final receivedDelta = sample.receivedBytes - previous.receivedBytes;
        final sentDelta = sample.sentBytes - previous.sentBytes;
        if (elapsedMilliseconds > 0 && receivedDelta >= 0 && sentDelta >= 0) {
          final seconds = elapsedMilliseconds / 1000;
          downloadSpeed = receivedDelta / seconds;
          uploadSpeed = sentDelta / seconds;
        }
      }
      _previous = sample;
      _snapshot = SystemStatusSnapshot(
        cpuUsage: cpuUsage,
        memoryUsage: memoryUsage,
        memoryUsedBytes: sample.memoryUsedBytes,
        memoryTotalBytes: sample.memoryTotalBytes,
        downloadBytesPerSecond: downloadSpeed,
        uploadBytesPerSecond: uploadSpeed,
      );
    } catch (error, stackTrace) {
      debugPrint('系统状态读取失败：$error\n$stackTrace');
      _snapshot = _snapshot.copyWith(error: '系统状态读取失败');
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
