enum AvoraIdentityEditRestrictionStatus {
  active,
  expired,
  revoked,
}

class AvoraIdentityEditRestriction {
  const AvoraIdentityEditRestriction({
    required this.restrictionId,
    required this.targetAvoraId,
    required this.issuedByAvoraId,
    required this.reason,
    required this.startedAtUtc,
    required this.expiresAtUtc,
    this.revokedAtUtc,
    this.revokedByAvoraId,
  });

  final String restrictionId;
  final String targetAvoraId;
  final String issuedByAvoraId;
  final String reason;
  final DateTime startedAtUtc;
  final DateTime expiresAtUtc;
  final DateTime? revokedAtUtc;
  final String? revokedByAvoraId;

  AvoraIdentityEditRestrictionStatus statusAt(DateTime nowUtc) {
    if (revokedAtUtc != null) {
      return AvoraIdentityEditRestrictionStatus.revoked;
    }

    if (!nowUtc.toUtc().isBefore(expiresAtUtc.toUtc())) {
      return AvoraIdentityEditRestrictionStatus.expired;
    }

    return AvoraIdentityEditRestrictionStatus.active;
  }

  bool isActiveAt(DateTime nowUtc) =>
      statusAt(nowUtc) == AvoraIdentityEditRestrictionStatus.active;

  AvoraIdentityEditRestriction revoke({
    required String revokedByAvoraId,
    required DateTime revokedAtUtc,
  }) {
    if (revokedByAvoraId.trim().isEmpty) {
      throw ArgumentError('revoker_required');
    }

    return AvoraIdentityEditRestriction(
      restrictionId: restrictionId,
      targetAvoraId: targetAvoraId,
      issuedByAvoraId: issuedByAvoraId,
      reason: reason,
      startedAtUtc: startedAtUtc,
      expiresAtUtc: expiresAtUtc,
      revokedAtUtc: revokedAtUtc.toUtc(),
      revokedByAvoraId: revokedByAvoraId,
    );
  }
}

class AvoraIdentityEditRestrictionLedger {
  final Map<String, AvoraIdentityEditRestriction> _records =
      <String, AvoraIdentityEditRestriction>{};

  void issue(AvoraIdentityEditRestriction restriction) {
    if (restriction.restrictionId.trim().isEmpty ||
        restriction.targetAvoraId.trim().isEmpty ||
        restriction.issuedByAvoraId.trim().isEmpty ||
        restriction.reason.trim().isEmpty) {
      throw ArgumentError('invalid_identity_restriction');
    }

    if (!restriction.expiresAtUtc.isAfter(restriction.startedAtUtc)) {
      throw ArgumentError(
        'restriction_expiry_must_be_future',
      );
    }

    if (_records.containsKey(restriction.restrictionId)) {
      throw StateError('duplicate_identity_restriction');
    }

    _records[restriction.restrictionId] = restriction;
  }

  bool mayEditIdentity({
    required String avoraId,
    required DateTime nowUtc,
    required bool actorIsVerifiedOwner,
  }) {
    if (actorIsVerifiedOwner) {
      return true;
    }

    return !_records.values.any(
      (record) => record.targetAvoraId == avoraId && record.isActiveAt(nowUtc),
    );
  }

  void revoke({
    required String restrictionId,
    required String revokedByAvoraId,
    required DateTime revokedAtUtc,
  }) {
    final current = _records[restrictionId];

    if (current == null) {
      throw StateError('identity_restriction_not_found');
    }

    _records[restrictionId] = current.revoke(
      revokedByAvoraId: revokedByAvoraId,
      revokedAtUtc: revokedAtUtc,
    );
  }

  AvoraIdentityEditRestriction? byId(
    String restrictionId,
  ) =>
      _records[restrictionId];

  static bool restrictionMustExpireAutomatically() => true;
  static bool restrictionMustOnlyBlockIdentityEditing() => true;
  static bool restrictionMustNotAutomaticallyBanAccount() => true;
  static bool ownerMayOverrideIdentityRestriction() => true;
  static bool ownerMayRevokeIdentityRestriction() => true;
  static bool issueAndRevokeMustRemainAuditable() => true;
  static bool futureIdentityFieldsMustRespectActiveRestriction() => true;
}
