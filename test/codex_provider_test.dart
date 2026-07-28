import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/providers/codex_provider.dart';

void main() {
  group('Codex 本地 JSONL 解析', () {
    test('识别额度事件、选择最长窗口且不误用余额', () {
      final snapshot = parseCodexLocalEvent(
        jsonEncode({
          'type': 'event_msg',
          'timestamp': '2026-07-28T08:00:00Z',
          'payload': {
            'type': 'token_count',
            'rate_limits': {
              'primary': {
                'used_percent': 80,
                'window_minutes': 300,
                'resets_at': 1785229200,
              },
              'secondary': {
                'used_percent': 25,
                'window_minutes': 10080,
                'resets_at': 1785800000000,
              },
              'credits': {'balance': 99},
            },
          },
        }),
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.weekly.remainingPercent, 75);
      expect(snapshot.resetCreditsAvailable, isNull);
      expect(snapshot.updatedAt.toUtc(), DateTime.utc(2026, 7, 28, 8));
    });

    test('忽略无关事件和损坏 JSON', () {
      expect(parseCodexLocalEvent('{bad'), isNull);
      expect(
        parseCodexLocalEvent(
          jsonEncode({
            'type': 'event_msg',
            'payload': {'type': 'message'},
          }),
        ),
        isNull,
      );
    });
  });

  test('app-server 选择最长窗口并解析官方重置次数', () {
    final snapshot = parseCodexAppServerResponse({
      'result': {
        'rateLimits': {
          'primary': {'usedPercent': 60, 'windowDurationMins': 300},
          'secondary': {'usedPercent': -10, 'windowDurationMins': 10080},
          'rateLimitResetCredits': {'availableCount': 3},
        },
      },
    });
    expect(snapshot!.weekly.remainingPercent, 100);
    expect(snapshot.resetCreditsAvailable, 3);
  });
}
