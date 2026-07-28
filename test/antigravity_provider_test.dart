import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/providers/antigravity_provider.dart';

void main() {
  test('解析 Gemini 与 Claude GPT 的明确窗口并忽略禁用桶', () {
    final result = parseAntigravitySummary({
      'response': {
        'groups': [
          {
            'name': 'Gemini Pro',
            'buckets': [
              {
                'displayName': '5 hour session',
                'remainingFraction': 0.42,
                'resetTime': '2026-07-29T01:00:00Z',
              },
              {
                'description': 'weekly limit',
                'remaining': {'remainingFraction': 0.8},
              },
              {
                'description': 'weekly disabled',
                'remainingFraction': 0.01,
                'disabled': true,
              },
            ],
          },
          {
            'displayName': 'Claude and GPT models',
            'quotaBuckets': [
              {'bucketId': '7d', 'remainingFraction': 0.21},
              {'bucketId': 'unmarked', 'remainingFraction': 0.01},
            ],
          },
        ],
      },
    });
    expect(result['Gemini']!.fiveHour.remainingPercent, closeTo(42, 0.001));
    expect(result['Gemini']!.weekly.remainingPercent, closeTo(80, 0.001));
    expect(result['Claude & GPT']!.weekly.remainingPercent, closeTo(21, 0.001));
    expect(result['Claude & GPT']!.fiveHour.hasData, isFalse);
  });

  test('缺少分组时不使用另一分组填充', () {
    final result = parseAntigravitySummary({
      'groups': [
        {
          'name': 'Gemini',
          'buckets': [
            {'description': 'week', 'remainingFraction': 0.5},
          ],
        },
      ],
    });
    expect(result['Gemini']!.hasData, isTrue);
    expect(result['Claude & GPT']!.hasData, isFalse);
    expect(result['Claude & GPT']!.error, isNotNull);
  });
}
