import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/controllers/system_status_controller.dart';
import 'package:topnest/models/system_status.dart';
import 'package:topnest/services/windows_system_status_service.dart';

class _FakeSystemStatusReader implements SystemStatusReader {
  _FakeSystemStatusReader(this.samples);

  final List<SystemMetricsSample> samples;
  int index = 0;

  @override
  Future<SystemMetricsSample> read() async => samples[index++];
}

SystemMetricsSample _sample({
  required int tick,
  required int idle,
  required int kernel,
  required int user,
  required int received,
  required int sent,
}) => SystemMetricsSample(
  tickMilliseconds: tick,
  idleTime: idle,
  kernelTime: kernel,
  userTime: user,
  memoryUsedBytes: 6 * 1024 * 1024 * 1024,
  memoryTotalBytes: 10 * 1024 * 1024 * 1024,
  receivedBytes: received,
  sentBytes: sent,
);

void main() {
  test('根据两次累计计数计算 CPU、内存和网速', () async {
    final reader = _FakeSystemStatusReader([
      _sample(
        tick: 1000,
        idle: 100,
        kernel: 200,
        user: 100,
        received: 1000,
        sent: 500,
      ),
      _sample(
        tick: 3000,
        idle: 140,
        kernel: 280,
        user: 140,
        received: 51000,
        sent: 10500,
      ),
    ]);
    final controller = SystemStatusController(reader);

    await controller.refresh();
    expect(controller.snapshot.memoryUsage, closeTo(0.6, 0.001));
    expect(controller.snapshot.cpuUsage, isNull);

    await controller.refresh();
    expect(controller.snapshot.cpuUsage, closeTo(2 / 3, 0.001));
    expect(controller.snapshot.downloadBytesPerSecond, 25000);
    expect(controller.snapshot.uploadBytesPerSecond, 5000);
  });
}
