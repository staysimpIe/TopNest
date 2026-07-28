enum QuotaProviderType { codex, antigravity }

class QuotaWindow {
  const QuotaWindow({this.remainingPercent, this.resetsAt});

  final double? remainingPercent;
  final DateTime? resetsAt;

  bool get hasData => remainingPercent != null || resetsAt != null;

  QuotaWindow normalized() => QuotaWindow(
    remainingPercent: remainingPercent?.clamp(0, 100).toDouble(),
    resetsAt: resetsAt,
  );
}

class QuotaSnapshot {
  const QuotaSnapshot({
    required this.provider,
    required this.groupName,
    required this.updatedAt,
    this.fiveHour = const QuotaWindow(),
    this.weekly = const QuotaWindow(),
    this.resetCreditsAvailable,
    this.stale = false,
    this.error,
  });

  final QuotaProviderType provider;
  final String groupName;
  final DateTime updatedAt;
  final QuotaWindow fiveHour;
  final QuotaWindow weekly;
  final int? resetCreditsAvailable;
  final bool stale;
  final String? error;

  bool get hasData => fiveHour.hasData || weekly.hasData;

  factory QuotaSnapshot.unavailable(
    QuotaProviderType provider,
    String groupName,
    String error,
  ) => QuotaSnapshot(
    provider: provider,
    groupName: groupName,
    updatedAt: DateTime.now(),
    error: error,
  );

  QuotaSnapshot markStale(String message) => QuotaSnapshot(
    provider: provider,
    groupName: groupName,
    updatedAt: updatedAt,
    fiveHour: fiveHour,
    weekly: weekly,
    resetCreditsAvailable: resetCreditsAvailable,
    stale: true,
    error: message,
  );
}

DateTime? parseFlexibleTime(Object? value) {
  if (value is num) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds.round(),
      isUtc: true,
    ).toLocal();
  }
  if (value is String) {
    final numeric = num.tryParse(value);
    if (numeric != null) return parseFlexibleTime(numeric);
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
