import 'dart:convert';
import 'dart:io';

import '../models/quota.dart';
import 'quota_provider.dart';

class AntigravityQuotaProvider implements QuotaProvider {
  @override
  QuotaProviderType get type => QuotaProviderType.antigravity;

  @override
  Future<Map<String, QuotaSnapshot>> fetch() async {
    final process = await _findProcess();
    if (process == null) throw StateError('Antigravity 未运行');
    final ports = await _findPorts(process.pid);
    if (ports.isEmpty) throw StateError('未找到 Antigravity 监听端口');
    Object? lastError;
    for (final port in ports) {
      for (final secure in [true, false]) {
        try {
          final result = await _requestPort(port, secure, process.csrfToken);
          if (result != null) return result;
        } catch (error) {
          lastError = error;
        }
      }
    }
    throw StateError('Antigravity 接口不可用：${sanitizeError(lastError)}');
  }

  Future<({int pid, String? csrfToken})?> _findProcess() async {
    final script =
        r'''Get-CimInstance Win32_Process | Where-Object { ($_.Name -match 'language[_-]server') -and ($_.CommandLine -match 'antigravity') } | Select-Object -First 1 ProcessId,CommandLine | ConvertTo-Json -Compress''';
    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        script,
      ]).timeout(const Duration(seconds: 5));
      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        return null;
      }
      final value = jsonDecode(result.stdout.toString());
      if (value is! Map || value['ProcessId'] is! num) return null;
      final command = value['CommandLine']?.toString() ?? '';
      final match = RegExp(
        r'''--csrf_token(?:=|\s+)(?:"([^"]+)"|'([^']+)'|([^\s]+))''',
      ).firstMatch(command);
      return (
        pid: (value['ProcessId'] as num).toInt(),
        csrfToken: match?.group(1) ?? match?.group(2) ?? match?.group(3),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _findPorts(int pid) async {
    final result = await Process.run('netstat.exe', [
      '-ano',
      '-p',
      'tcp',
    ]).timeout(const Duration(seconds: 5));
    final ports = <int>{};
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 5 ||
          fields[0].toUpperCase() != 'TCP' ||
          fields[3].toUpperCase() != 'LISTENING' ||
          int.tryParse(fields[4]) != pid) {
        continue;
      }
      final port = int.tryParse(fields[1].split(':').last);
      if (port != null) ports.add(port);
    }
    return ports.toList()..sort();
  }

  Future<Map<String, QuotaSnapshot>?> _requestPort(
    int port,
    bool secure,
    String? csrfToken,
  ) async {
    for (final endpoint in const [
      (
        '/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary',
        '{"forceRefresh":true}',
        true,
      ),
      (
        '/exa.language_server_pb.LanguageServerService/GetUserStatus',
        '{}',
        false,
      ),
    ]) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      if (secure) {
        client.badCertificateCallback = (_, host, certificatePort) =>
            host == '127.0.0.1' && certificatePort == port;
      }
      try {
        final uri = Uri.parse(
          '${secure ? 'https' : 'http'}://127.0.0.1:$port${endpoint.$1}',
        );
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.headers.set('Connect-Protocol-Version', '1');
        if (csrfToken != null && csrfToken.isNotEmpty) {
          request.headers.set('X-Codeium-Csrf-Token', csrfToken);
        }
        request.write(endpoint.$2);
        final response = await request.close().timeout(
          const Duration(seconds: 4),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final text = await utf8.decoder.bind(response).join();
        final value = jsonDecode(text);
        if (value is! Map) continue;
        final parsed = endpoint.$3
            ? parseAntigravitySummary(value.cast<String, dynamic>())
            : parseAntigravityLegacy(value.cast<String, dynamic>());
        if (parsed.values.any((snapshot) => snapshot.hasData)) return parsed;
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }
}

Map<String, QuotaSnapshot> parseAntigravitySummary(Map<String, dynamic> root) {
  Object? container = root['response'] ?? root['summary'] ?? root;
  if (container is Map && container['summary'] is Map) {
    container = container['summary'];
  }
  final groups = container is Map ? container['groups'] : null;
  final found = <String, ({QuotaWindow five, QuotaWindow week})>{};
  if (groups is List) {
    for (final rawGroup in groups) {
      if (rawGroup is! Map) continue;
      final name = [
        rawGroup['name'],
        rawGroup['displayName'],
        rawGroup['groupName'],
      ].whereType<Object>().join(' ').toLowerCase();
      final group = _groupName(name);
      if (group == null) continue;
      var five = const QuotaWindow();
      var week = const QuotaWindow();
      final buckets = rawGroup['buckets'] ?? rawGroup['quotaBuckets'];
      if (buckets is List) {
        for (final bucket in buckets) {
          if (bucket is! Map || bucket['disabled'] == true) continue;
          final description = [
            bucket['bucketId'],
            bucket['displayName'],
            bucket['description'],
          ].whereType<Object>().join(' ').toLowerCase();
          final window = _fractionWindow(bucket);
          if (_isFiveHour(description)) five = _lowerQuota(five, window);
          if (_isWeekly(description)) week = _lowerQuota(week, window);
        }
      }
      found[group] = (five: five, week: week);
    }
  }
  return _snapshots(found, '未返回该分组额度');
}

Map<String, QuotaSnapshot> parseAntigravityLegacy(Map<String, dynamic> root) {
  Object? current = root;
  for (final key in [
    'userStatus',
    'cascadeModelConfigData',
    'clientModelConfigs',
  ]) {
    if (current is Map) current = current[key];
  }
  final found = <String, ({QuotaWindow five, QuotaWindow week})>{};
  if (current is List) {
    for (final model in current) {
      if (model is! Map) continue;
      final name = [
        model['name'],
        model['displayName'],
        model['modelId'],
      ].whereType<Object>().join(' ').toLowerCase();
      final group = _groupName(name);
      final info = model['quotaInfo'];
      if (group == null || info is! Map) continue;
      final window = _fractionWindow(info);
      final reset = window.resetsAt;
      if (reset == null) continue;
      final hours = reset.difference(DateTime.now()).inMinutes / 60;
      final old =
          found[group] ??
          (five: const QuotaWindow(), week: const QuotaWindow());
      if (hours <= 6) {
        found[group] = (five: _lowerQuota(old.five, window), week: old.week);
      } else if (hours >= 20) {
        found[group] = (five: old.five, week: _lowerQuota(old.week, window));
      }
    }
  }
  return _snapshots(found, '旧接口未返回该分组额度');
}

Map<String, QuotaSnapshot> _snapshots(
  Map<String, ({QuotaWindow five, QuotaWindow week})> values,
  String missingMessage,
) {
  final now = DateTime.now();
  return {
    for (final name in ['Gemini', 'Claude & GPT'])
      name: values[name] == null
          ? QuotaSnapshot.unavailable(
              QuotaProviderType.antigravity,
              name,
              missingMessage,
            )
          : QuotaSnapshot(
              provider: QuotaProviderType.antigravity,
              groupName: name,
              updatedAt: now,
              fiveHour: values[name]!.five,
              weekly: values[name]!.week,
            ),
  };
}

String? _groupName(String name) {
  if (name.contains('gemini')) return 'Gemini';
  if (name.contains('claude') || name.contains('gpt')) return 'Claude & GPT';
  return null;
}

bool _isFiveHour(String value) =>
    value.contains('five') ||
    value.contains('5h') ||
    value.contains('5 hour') ||
    value.contains('session');

bool _isWeekly(String value) =>
    value.contains('week') || value.contains('7d') || value.contains('7 day');

QuotaWindow _fractionWindow(Map value) {
  final remaining =
      value['remainingFraction'] ??
      (value['remaining'] is Map
          ? (value['remaining'] as Map)['remainingFraction']
          : null);
  return QuotaWindow(
    remainingPercent: remaining is num ? remaining.toDouble() * 100 : null,
    resetsAt: parseFlexibleTime(value['resetTime']),
  ).normalized();
}

QuotaWindow _lowerQuota(QuotaWindow current, QuotaWindow candidate) {
  if (!current.hasData) return candidate;
  final currentPercent = current.remainingPercent ?? double.infinity;
  final candidatePercent = candidate.remainingPercent ?? double.infinity;
  return candidatePercent < currentPercent ? candidate : current;
}

String sanitizeError(Object? error) {
  var text = error?.toString() ?? '未知错误';
  text = text.replaceAll(
    RegExp(
      r'(token|authorization|csrf)[=: ]+[A-Za-z0-9._\-]{12,}',
      caseSensitive: false,
    ),
    r'$1=***',
  );
  return text.length > 180 ? '${text.substring(0, 180)}…' : text;
}
