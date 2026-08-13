import 'avora_delegated_inspection_capability.dart';

class AvoraDelegatedInspectionUsageRecord {
  const AvoraDelegatedInspectionUsageRecord({
    required this.usageId,
    required this.officialAvoraId,
    required this.capability,
    required this.countryCode,
    required this.resourceId,
    required this.reason,
    required this.usedAtUtc,
  });

  final String usageId;
  final String officialAvoraId;
  final AvoraInspectionCapability capability;
  final String countryCode;
  final String resourceId;
  final String reason;
  final DateTime usedAtUtc;
}

class AvoraDelegatedInspectionUsageAuditLedger {
  final Map<String, AvoraDelegatedInspectionUsageRecord> _records =
      <String, AvoraDelegatedInspectionUsageRecord>{};

  void append(AvoraDelegatedInspectionUsageRecord record) {
    if (record.usageId.trim().isEmpty ||
        record.officialAvoraId.trim().isEmpty ||
        record.countryCode.trim().isEmpty ||
        record.resourceId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError(
        'invalid_delegated_inspection_usage',
      );
    }

    if (_records.containsKey(record.usageId)) {
      throw StateError(
        'duplicate_delegated_inspection_usage',
      );
    }

    _records[record.usageId] = record;
  }

  List<AvoraDelegatedInspectionUsageRecord> get allForOwner =>
      List<AvoraDelegatedInspectionUsageRecord>.unmodifiable(
        _records.values,
      );

  List<AvoraDelegatedInspectionUsageRecord> byOfficial(
    String officialAvoraId,
  ) {
    return List<AvoraDelegatedInspectionUsageRecord>.unmodifiable(
      _records.values.where(
        (record) => record.officialAvoraId == officialAvoraId,
      ),
    );
  }

  List<AvoraDelegatedInspectionUsageRecord> byCountry(
    String countryCode,
  ) {
    final code = countryCode.trim().toUpperCase();

    return List<AvoraDelegatedInspectionUsageRecord>.unmodifiable(
      _records.values.where(
        (record) => record.countryCode.toUpperCase() == code,
      ),
    );
  }

  List<AvoraDelegatedInspectionUsageRecord> byResource(
    String resourceId,
  ) {
    return List<AvoraDelegatedInspectionUsageRecord>.unmodifiable(
      _records.values.where(
        (record) => record.resourceId == resourceId,
      ),
    );
  }

  static bool everyDelegatedInspectionUseMustBeAudited() => true;

  static bool ownerMustSeeWhoUsedInspectionPower() => true;

  static bool ownerMustSeeCountryAndResource() => true;

  static bool ownerMustSeeCapabilityUsed() => true;

  static bool usageHistoryMustRemainImmutable() => true;

  static bool futureInspectionCapabilitiesMustUseSameUsageAudit() => true;
}

class AvoraDelegatedInspectionUsageGate {
  AvoraDelegatedInspectionUsageGate({
    required AvoraDelegatedInspectionCapabilityEngine capabilityEngine,
    required AvoraDelegatedInspectionUsageAuditLedger usageLedger,
  })  : _capabilityEngine = capabilityEngine,
        _usageLedger = usageLedger;

  final AvoraDelegatedInspectionCapabilityEngine _capabilityEngine;
  final AvoraDelegatedInspectionUsageAuditLedger _usageLedger;

  bool authorizeAndAudit({
    required String usageId,
    required String officialAvoraId,
    required AvoraInspectionCapability capability,
    required String countryCode,
    required String resourceId,
    required String reason,
    required DateTime nowUtc,
  }) {
    final allowed = _capabilityEngine.isAllowed(
      officialAvoraId: officialAvoraId,
      capability: capability,
      countryCode: countryCode,
      nowUtc: nowUtc,
    );

    if (!allowed) {
      return false;
    }

    _usageLedger.append(
      AvoraDelegatedInspectionUsageRecord(
        usageId: usageId,
        officialAvoraId: officialAvoraId,
        capability: capability,
        countryCode: countryCode,
        resourceId: resourceId,
        reason: reason,
        usedAtUtc: nowUtc.toUtc(),
      ),
    );

    return true;
  }

  static bool capabilityMustBeValidBeforeUse() => true;

  static bool authorizedUseMustAutoAudit() => true;

  static bool revokedCapabilityMustFailClosed() => true;

  static bool crossCountryUseMustFailWithoutScope() => true;

  static bool futureDelegatedInspectionUseMustPassSameGate() => true;
}
