import '../models/quota.dart';

abstract interface class QuotaProvider {
  QuotaProviderType get type;
  Future<Map<String, QuotaSnapshot>> fetch();
}
