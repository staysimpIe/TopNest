import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/ui/widgets/quota_widget.dart';

void main() {
  test('倒计时使用天小时分钟秒', () {
    final now = DateTime(2026, 7, 28, 10);
    final reset = now.add(
      const Duration(days: 2, hours: 3, minutes: 4, seconds: 5),
    );
    expect(formatQuotaCountdown(reset, now), '2天3小时4分5秒');
  });

  test('不足一小时不显示无意义的小时', () {
    final now = DateTime(2026, 7, 28, 10);
    expect(
      formatQuotaCountdown(
        now.add(const Duration(minutes: 8, seconds: 6)),
        now,
      ),
      '8分6秒',
    );
  });
}
