import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/controllers/quota_controller.dart';
import 'package:topnest/models/quota.dart';
import 'package:topnest/providers/quota_provider.dart';

class _FakeProvider implements QuotaProvider {
  _FakeProvider(this.callback, {this.type = QuotaProviderType.codex});
  final Future<Map<String, QuotaSnapshot>> Function() callback;
  @override
  final QuotaProviderType type;
  int calls = 0;

  @override
  Future<Map<String, QuotaSnapshot>> fetch() {
    calls++;
    return callback();
  }
}

QuotaSnapshot _snapshot(String name, double percent) => QuotaSnapshot(
  provider: QuotaProviderType.codex,
  groupName: name,
  updatedAt: DateTime.now(),
  weekly: QuotaWindow(remainingPercent: percent),
);

void main() {
  test('同一时间不重复刷新且不同 Provider 并行开始', () async {
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    final first = _FakeProvider(() async {
      await firstGate.future;
      return {'Codex': _snapshot('Codex', 80)};
    });
    final second = _FakeProvider(() async {
      await secondGate.future;
      return {'Gemini': _snapshot('Gemini', 60)};
    }, type: QuotaProviderType.antigravity);
    final controller = QuotaController([first, second]);
    final pending = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(first.calls, 1);
    expect(second.calls, 1);
    await controller.refresh();
    expect(first.calls, 1);
    firstGate.complete();
    secondGate.complete();
    await pending;
  });

  test('失败时保留旧数据并标记 stale', () async {
    var fail = false;
    final provider = _FakeProvider(() async {
      if (fail) throw StateError('认证失败');
      return {'Codex': _snapshot('Codex', 70)};
    });
    final controller = QuotaController([provider]);
    await controller.refresh();
    fail = true;
    await controller.refresh();
    expect(controller.snapshots['Codex']!.weekly.remainingPercent, 70);
    expect(controller.snapshots['Codex']!.stale, isTrue);
    expect(controller.snapshots['Codex']!.error, contains('认证失败'));
  });
}
