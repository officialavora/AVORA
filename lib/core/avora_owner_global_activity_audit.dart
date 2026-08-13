enum AvoraOwnerActivityKind {
  economy,
  roleGrant,
  roleRevoke,
  mute,
  unmute,
  kick,
  ban,
  unban,
  block,
  unblock,
  roomEdit,
  transfer,
  rewardGrant,
  rewardRevoke,
  other,
}

class AvoraOwnerActivityRecord {
  const AvoraOwnerActivityRecord({
    required this.recordId,
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.kind,
    required this.countryCode,
    required this.createdAtUtc,
    this.roomId,
    this.parentAvoraId,
    this.amountMinor = 0,
    this.reason,
  });

  final String recordId;
  final String actorAvoraId;
  final String targetAvoraId;
  final AvoraOwnerActivityKind kind;
  final String countryCode;
  final DateTime createdAtUtc;

  final String? roomId;
  final String? parentAvoraId;

  /// For economic activity only.
  final int amountMinor;

  final String? reason;

  void validate() {
    if (recordId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        targetAvoraId.trim().isEmpty) {
      throw StateError('owner_activity_requires_ids');
    }

    if (amountMinor < 0) {
      throw StateError('owner_activity_amount_cannot_be_negative');
    }
  }
}

class AvoraOwnerTurnoverSummary {
  const AvoraOwnerTurnoverSummary({
    required this.totalMinor,
    required this.byCountry,
    required this.byParent,
  });

  final int totalMinor;
  final Map<String, int> byCountry;
  final Map<String, int> byParent;
}

class AvoraOwnerGlobalActivityAudit {
  const AvoraOwnerGlobalActivityAudit._();

  static AvoraOwnerTurnoverSummary summarizeTurnover(
    List<AvoraOwnerActivityRecord> records,
  ) {
    var total = 0;
    final byCountry = <String, int>{};
    final byParent = <String, int>{};

    for (final record in records) {
      record.validate();

      if (record.kind != AvoraOwnerActivityKind.economy ||
          record.amountMinor <= 0) {
        continue;
      }

      total += record.amountMinor;

      final country = record.countryCode.trim().toUpperCase();

      byCountry.update(
        country,
        (value) => value + record.amountMinor,
        ifAbsent: () => record.amountMinor,
      );

      final parent = record.parentAvoraId?.trim();
      if (parent != null && parent.isNotEmpty) {
        byParent.update(
          parent,
          (value) => value + record.amountMinor,
          ifAbsent: () => record.amountMinor,
        );
      }
    }

    return AvoraOwnerTurnoverSummary(
      totalMinor: total,
      byCountry: Map.unmodifiable(byCountry),
      byParent: Map.unmodifiable(byParent),
    );
  }

  static List<AvoraOwnerActivityRecord> roomHistory({
    required String roomId,
    required List<AvoraOwnerActivityRecord> records,
  }) {
    final result = records
        .where((record) => record.roomId == roomId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));

    return List.unmodifiable(result);
  }

  static bool ownerMustSeeGlobalTurnover() => true;

  static bool moderationHistoryMustBeUnified() => true;

  static bool everySensitiveActionMustRemainAudited() => true;

  static bool hierarchyAttributionMustRemainVisible() => true;
}
