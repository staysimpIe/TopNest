import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/quota.dart';
import '../providers/quota_provider.dart';

class QuotaController extends ChangeNotifier {
  QuotaController(this.providers);

  final List<QuotaProvider> providers;
  final Map<String, QuotaSnapshot> _snapshots = {};
  Timer? _refreshTimer;
  bool _refreshing = false;

  Map<String, QuotaSnapshot> get snapshots => Map.unmodifiable(_snapshots);
  bool get refreshing => _refreshing;
  DateTime? get lastUpdated => _snapshots.values.isEmpty
      ? null
      : _snapshots.values
            .map((value) => value.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

  void start(Duration interval) {
    _refreshTimer?.cancel();
    unawaited(refresh());
    _refreshTimer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    final results = await Future.wait(
      providers.map((provider) async {
        try {
          return await provider.fetch();
        } catch (error) {
          return <String, QuotaSnapshot>{
            '__error__': _providerError(provider, error),
          };
        }
      }),
    );
    for (final result in results) {
      if (result.containsKey('__error__')) {
        final failure = result['__error__']!;
        final names = failure.provider == QuotaProviderType.codex
            ? const ['Codex']
            : const ['Gemini', 'Claude & GPT'];
        for (final name in names) {
          final old = _snapshots[name];
          _snapshots[name] =
              old?.markStale(failure.error!) ??
              QuotaSnapshot.unavailable(failure.provider, name, failure.error!);
        }
      } else {
        _snapshots.addAll(result);
      }
    }
    _refreshing = false;
    notifyListeners();
  }

  QuotaSnapshot _providerError(QuotaProvider provider, Object error) {
    return QuotaSnapshot.unavailable(
      provider.type,
      '__error__',
      _cleanError(error),
    );
  }

  String _cleanError(Object error) {
    var text = error.toString().replaceFirst(RegExp(r'^Bad state: '), '');
    text = text.replaceAll(
      RegExp(
        r'(token|authorization|csrf)[=: ]+[A-Za-z0-9._\-]{12,}',
        caseSensitive: false,
      ),
      r'$1=***',
    );
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
