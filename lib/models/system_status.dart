class SystemMetricsSample {
  const SystemMetricsSample({
    required this.tickMilliseconds,
    required this.idleTime,
    required this.kernelTime,
    required this.userTime,
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    required this.receivedBytes,
    required this.sentBytes,
  });

  final int tickMilliseconds;
  final int idleTime;
  final int kernelTime;
  final int userTime;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final int receivedBytes;
  final int sentBytes;
}

class SystemStatusSnapshot {
  const SystemStatusSnapshot({
    this.cpuUsage,
    this.memoryUsage,
    this.memoryUsedBytes = 0,
    this.memoryTotalBytes = 0,
    this.downloadBytesPerSecond,
    this.uploadBytesPerSecond,
    this.error,
  });

  final double? cpuUsage;
  final double? memoryUsage;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final double? downloadBytesPerSecond;
  final double? uploadBytesPerSecond;
  final String? error;

  bool get available => memoryUsage != null;

  SystemStatusSnapshot copyWith({String? error}) => SystemStatusSnapshot(
    cpuUsage: cpuUsage,
    memoryUsage: memoryUsage,
    memoryUsedBytes: memoryUsedBytes,
    memoryTotalBytes: memoryTotalBytes,
    downloadBytesPerSecond: downloadBytesPerSecond,
    uploadBytesPerSecond: uploadBytesPerSecond,
    error: error,
  );
}
