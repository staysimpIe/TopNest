import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/quota.dart';
import 'quota_provider.dart';

class CodexQuotaProvider implements QuotaProvider {
  CodexQuotaProvider({String? codexHome})
    : codexHome =
          codexHome ?? '${Platform.environment['USERPROFILE'] ?? ''}\\.codex';

  final String codexHome;
  int? _resetCredits;
  bool _askedForResetCredits = false;

  @override
  QuotaProviderType get type => QuotaProviderType.codex;

  @override
  Future<Map<String, QuotaSnapshot>> fetch() async {
    final local = await _readLocalCache();
    if (local != null) {
      if (!_askedForResetCredits) {
        _askedForResetCredits = true;
        try {
          final server = await _readAppServer();
          _resetCredits = server?.resetCreditsAvailable;
        } catch (_) {
          // 本地额度可用时，重置次数读取失败不影响主数据。
        }
      }
      return {
        'Codex': QuotaSnapshot(
          provider: local.provider,
          groupName: local.groupName,
          updatedAt: local.updatedAt,
          weekly: local.weekly,
          resetCreditsAvailable: _resetCredits,
        ),
      };
    }

    final server = await _readAppServer();
    if (server == null) throw StateError('未找到有效的 Codex 额度数据');
    _resetCredits = server.resetCreditsAvailable;
    return {'Codex': server};
  }

  Future<QuotaSnapshot?> _readLocalCache() async {
    final files = <File>[];
    for (final folder in ['sessions', 'archived_sessions']) {
      final directory = Directory('$codexHome\\$folder');
      if (!await directory.exists()) continue;
      try {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
            files.add(entity);
          }
        }
      } catch (_) {
        // 单个目录不可读时继续检查其他目录。
      }
    }
    final dated = <({File file, DateTime modified})>[];
    for (final file in files) {
      try {
        dated.add((file: file, modified: (await file.stat()).modified));
      } catch (_) {}
    }
    dated.sort((a, b) => b.modified.compareTo(a.modified));
    for (final entry in dated.take(20)) {
      try {
        final text = await readFileTail(entry.file, 1024 * 1024);
        final lines = const LineSplitter().convert(text);
        for (var index = lines.length - 1; index >= 0; index--) {
          final snapshot = parseCodexLocalEvent(lines[index]);
          if (snapshot != null) return snapshot;
        }
      } catch (_) {
        // 单个会话损坏时继续检查其他文件。
      }
    }
    return null;
  }

  Future<QuotaSnapshot?> _readAppServer() async {
    final executable = await _findCodexExecutable();
    if (executable == null) return null;
    Process? process;
    StreamSubscription<String>? stdoutSubscription;
    StreamSubscription<String>? stderrSubscription;
    try {
      process = await Process.start(executable, ['app-server', '--stdio']);
      final responses = <int, Completer<Map<String, dynamic>>>{};
      stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            try {
              final value = jsonDecode(line);
              if (value is Map && value['id'] is int) {
                responses
                    .remove(value['id'])
                    ?.complete(value.cast<String, dynamic>());
              }
            } catch (_) {}
          });
      stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .listen((_) {});

      Future<Map<String, dynamic>> request(
        int id,
        String method, [
        Map<String, dynamic>? params,
      ]) {
        final completer = Completer<Map<String, dynamic>>();
        responses[id] = completer;
        process!.stdin.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'method': method,
            'params': ?params,
          }),
        );
        return completer.future.timeout(const Duration(seconds: 12));
      }

      await request(1, 'initialize', {
        'clientInfo': {
          'name': 'desktop-widget-bar',
          'title': '顶栖（TopNest）',
          'version': '1.0.0',
        },
        'capabilities': <String, dynamic>{},
      });
      process.stdin.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialized',
          'params': <String, dynamic>{},
        }),
      );
      final response = await request(2, 'account/rateLimits/read');
      return parseCodexAppServerResponse(response);
    } finally {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      await process?.stdin.close();
      process?.kill();
    }
  }

  Future<String?> _findCodexExecutable() async {
    final sandbox = File('$codexHome\\.sandbox-bin\\codex.exe');
    if (await sandbox.exists()) return sandbox.path;
    try {
      final result = await Process.run('where.exe', [
        'codex.exe',
      ]).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        return const LineSplitter()
            .convert(result.stdout.toString())
            .firstOrNull;
      }
    } catch (_) {}
    return null;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Future<String> readFileTail(File file, int maxBytes) async {
  final reader = await file.open();
  try {
    final length = await reader.length();
    final start = length > maxBytes ? length - maxBytes : 0;
    await reader.setPosition(start);
    final bytes = await reader.read(length - start);
    var text = utf8.decode(bytes, allowMalformed: true);
    if (start > 0) {
      final newline = text.indexOf('\n');
      if (newline >= 0) text = text.substring(newline + 1);
    }
    return text;
  } finally {
    await reader.close();
  }
}

QuotaSnapshot? parseCodexLocalEvent(String line) {
  try {
    final root = jsonDecode(line);
    if (root is! Map || root['type'] != 'event_msg') return null;
    final payload = root['payload'];
    if (payload is! Map || payload['type'] != 'token_count') return null;
    final limits = payload['rate_limits'];
    if (limits is! Map) return null;
    final windows = <Map>[];
    for (final key in ['primary', 'secondary', 'individual_limit']) {
      final value = limits[key];
      if (value is Map && value['window_minutes'] is num) windows.add(value);
    }
    if (windows.isEmpty) return null;
    windows.sort(
      (a, b) =>
          (b['window_minutes'] as num).compareTo(a['window_minutes'] as num),
    );
    final weekly = _localWindow(windows.first);
    if (!weekly.hasData) return null;
    return QuotaSnapshot(
      provider: QuotaProviderType.codex,
      groupName: 'Codex',
      updatedAt: parseFlexibleTime(root['timestamp']) ?? DateTime.now(),
      weekly: weekly,
      // credits.balance 是账户余额，不能作为官方重置次数。
    );
  } catch (_) {
    return null;
  }
}

QuotaWindow _localWindow(Map value) {
  final used = value['used_percent'];
  return QuotaWindow(
    remainingPercent: used is num ? 100 - used.toDouble() : null,
    resetsAt: parseFlexibleTime(value['resets_at']),
  ).normalized();
}

QuotaSnapshot? parseCodexAppServerResponse(Map<String, dynamic> response) {
  final result = response['result'];
  if (result is! Map) return null;
  final rateLimits = result['rateLimits'] ?? result;
  if (rateLimits is! Map) return null;
  final windows = <Map>[];
  void addWindow(Object? value) {
    if (value is Map &&
        (value['windowDurationMins'] is num ||
            value['window_minutes'] is num)) {
      windows.add(value);
    }
  }

  addWindow(rateLimits['primary']);
  addWindow(rateLimits['secondary']);
  addWindow(rateLimits['individualLimit']);
  final byId =
      rateLimits['rateLimitsByLimitId'] ?? result['rateLimitsByLimitId'];
  if (byId is Map) {
    for (final entry in byId.values) {
      if (entry is Map) {
        addWindow(entry['primary']);
        addWindow(entry['secondary']);
        addWindow(entry);
      }
    }
  }
  windows.sort((a, b) => (_duration(b)).compareTo(_duration(a)));
  final credits =
      rateLimits['rateLimitResetCredits'] ?? result['rateLimitResetCredits'];
  final available = credits is Map && credits['availableCount'] is num
      ? (credits['availableCount'] as num).toInt()
      : null;
  if (windows.isEmpty && available == null) return null;
  final weekly = windows.isEmpty
      ? const QuotaWindow()
      : _serverWindow(windows.first);
  return QuotaSnapshot(
    provider: QuotaProviderType.codex,
    groupName: 'Codex',
    updatedAt: DateTime.now(),
    weekly: weekly,
    resetCreditsAvailable: available,
  );
}

num _duration(Map value) =>
    value['windowDurationMins'] as num? ?? value['window_minutes'] as num? ?? 0;

QuotaWindow _serverWindow(Map value) {
  final used = value['usedPercent'] ?? value['used_percent'];
  return QuotaWindow(
    remainingPercent: used is num ? 100 - used.toDouble() : null,
    resetsAt: parseFlexibleTime(value['resetsAt'] ?? value['resets_at']),
  ).normalized();
}
