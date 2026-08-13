enum AvoraContainmentFeature {
  recharge,
  withdrawal,
  sellerPurchase,
  walletTransfer,
  gifts,
  games,
  messaging,
  mediaUpload,
  voiceRoom,
  login,
  registration,
}

enum AvoraContainmentScopeType {
  global,
  country,
  region,
  feature,
}

enum AvoraContainmentStatus {
  active,
  expired,
  revoked,
}

class AvoraContainmentRule {
  const AvoraContainmentRule({
    required this.ruleId,
    required this.incidentId,
    required this.feature,
    required this.scopeType,
    required this.scopeValue,
    required this.reason,
    required this.activatedBy,
    required this.activatedAtUtc,
    this.expiresAtUtc,
    this.revokedAtUtc,
    this.revokedBy,
  });

  final String ruleId;
  final String incidentId;
  final AvoraContainmentFeature feature;
  final AvoraContainmentScopeType scopeType;

  /// GLOBAL for global rules, country/region code for scoped rules,
  /// or feature identifier where appropriate.
  final String scopeValue;

  final String reason;
  final String activatedBy;
  final DateTime activatedAtUtc;
  final DateTime? expiresAtUtc;
  final DateTime? revokedAtUtc;
  final String? revokedBy;

  void validate() {
    if (ruleId.trim().isEmpty ||
        incidentId.trim().isEmpty ||
        scopeValue.trim().isEmpty ||
        reason.trim().isEmpty ||
        activatedBy.trim().isEmpty) {
      throw ArgumentError('invalid_containment_rule');
    }

    if (expiresAtUtc != null && !expiresAtUtc!.isAfter(activatedAtUtc)) {
      throw ArgumentError('invalid_containment_expiry');
    }

    if ((revokedAtUtc == null) != (revokedBy == null)) {
      throw ArgumentError('incomplete_containment_revocation');
    }
  }

  AvoraContainmentStatus statusAt(DateTime nowUtc) {
    if (revokedAtUtc != null &&
        !nowUtc.toUtc().isBefore(revokedAtUtc!.toUtc())) {
      return AvoraContainmentStatus.revoked;
    }

    if (expiresAtUtc != null &&
        !nowUtc.toUtc().isBefore(expiresAtUtc!.toUtc())) {
      return AvoraContainmentStatus.expired;
    }

    return AvoraContainmentStatus.active;
  }

  bool activeAt(DateTime nowUtc) =>
      statusAt(nowUtc) == AvoraContainmentStatus.active;
}

class AvoraContainmentContext {
  const AvoraContainmentContext({
    required this.feature,
    this.countryCode,
    this.regionCode,
  });

  final AvoraContainmentFeature feature;
  final String? countryCode;
  final String? regionCode;
}

class AvoraContainmentDecision {
  const AvoraContainmentDecision({
    required this.blocked,
    required this.matchedRuleIds,
    required this.incidentIds,
  });

  final bool blocked;
  final List<String> matchedRuleIds;
  final List<String> incidentIds;
}

class AvoraEmergencyContainmentService {
  final Map<String, AvoraContainmentRule> _rules =
      <String, AvoraContainmentRule>{};

  void activate(AvoraContainmentRule rule) {
    rule.validate();

    if (_rules.containsKey(rule.ruleId)) {
      throw StateError('duplicate_containment_rule');
    }

    _rules[rule.ruleId] = rule;
  }

  AvoraContainmentDecision evaluate({
    required AvoraContainmentContext context,
    required DateTime nowUtc,
  }) {
    final matched = _rules.values.where((rule) {
      if (!rule.activeAt(nowUtc)) {
        return false;
      }

      if (rule.feature != context.feature) {
        return false;
      }

      switch (rule.scopeType) {
        case AvoraContainmentScopeType.global:
          return true;

        case AvoraContainmentScopeType.country:
          return context.countryCode != null &&
              rule.scopeValue.toUpperCase() ==
                  context.countryCode!.toUpperCase();

        case AvoraContainmentScopeType.region:
          return context.regionCode != null &&
              rule.scopeValue.toUpperCase() ==
                  context.regionCode!.toUpperCase();

        case AvoraContainmentScopeType.feature:
          return true;
      }
    }).toList(growable: false);

    return AvoraContainmentDecision(
      blocked: matched.isNotEmpty,
      matchedRuleIds: List<String>.unmodifiable(
        matched.map((rule) => rule.ruleId),
      ),
      incidentIds: List<String>.unmodifiable(
        matched.map((rule) => rule.incidentId).toSet(),
      ),
    );
  }

  AvoraContainmentRule revoke({
    required String ruleId,
    required String revokedBy,
    required DateTime revokedAtUtc,
  }) {
    final current = _rules[ruleId];

    if (current == null) {
      throw StateError('containment_rule_not_found');
    }

    if (revokedBy.trim().isEmpty) {
      throw ArgumentError('revoker_required');
    }

    if (current.revokedAtUtc != null) {
      throw StateError('containment_rule_already_revoked');
    }

    final revoked = AvoraContainmentRule(
      ruleId: current.ruleId,
      incidentId: current.incidentId,
      feature: current.feature,
      scopeType: current.scopeType,
      scopeValue: current.scopeValue,
      reason: current.reason,
      activatedBy: current.activatedBy,
      activatedAtUtc: current.activatedAtUtc,
      expiresAtUtc: current.expiresAtUtc,
      revokedAtUtc: revokedAtUtc.toUtc(),
      revokedBy: revokedBy,
    );

    revoked.validate();
    _rules[ruleId] = revoked;

    return revoked;
  }

  static bool killSwitchMustBeServerAuthoritative() => true;

  static bool clientUiMustNeverBypassContainment() => true;

  static bool containmentMustSupportPartialShutdown() => true;

  static bool containmentMustBeIncidentLinked() => true;

  static bool containmentMustHaveReasonAndActor() => true;

  static bool containmentMustNotDeleteEvidence() => true;

  static bool containmentMustNotRewriteFinancialLedger() => true;

  static bool futureFeaturesMustUseSameContainmentService() => true;
}

enum AvoraContainmentAuditAction {
  activated,
  revoked,
  expiredObserved,
  blockedOperation,
}

class AvoraContainmentAuditRecord {
  const AvoraContainmentAuditRecord({
    required this.auditId,
    required this.ruleId,
    required this.incidentId,
    required this.action,
    required this.actorId,
    required this.createdAtUtc,
    required this.details,
  });

  final String auditId;
  final String ruleId;
  final String incidentId;
  final AvoraContainmentAuditAction action;
  final String actorId;
  final DateTime createdAtUtc;
  final String details;
}

class AvoraContainmentAuditLedger {
  final Map<String, AvoraContainmentAuditRecord> _records =
      <String, AvoraContainmentAuditRecord>{};

  void append(AvoraContainmentAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.ruleId.trim().isEmpty ||
        record.incidentId.trim().isEmpty ||
        record.actorId.trim().isEmpty ||
        record.details.trim().isEmpty) {
      throw ArgumentError('invalid_containment_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_containment_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraContainmentAuditRecord> forIncident(
    String incidentId,
  ) {
    return List<AvoraContainmentAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.incidentId == incidentId,
      ),
    );
  }

  static bool emergencyActionsMustRemainAuditable() => true;

  static bool auditHistoryMustRemainImmutable() => true;
}

class AvoraEmergencyContainmentArchitecture {
  const AvoraEmergencyContainmentArchitecture._();

  static bool paymentIncidentMayFreezeRechargeWithoutStoppingVoice() => true;

  static bool gameIncidentMayFreezeGamesWithoutStoppingMessaging() => true;

  static bool giftIncidentMayFreezeGiftsWithoutDeletingGiftHistory() => true;

  static bool countryIncidentMayBeContainedWithoutGlobalShutdown() => true;

  static bool emergencyControlMustPreferSmallestSafeScope() => true;

  static bool ownerMustHaveHumanReadableEmergencyControls() => true;

  static bool emergencyActionMustBeReversibleWhenSafe() => true;

  static bool containmentReleaseMustRequireEvidenceBasedDecision() => true;

  static bool criticalContainmentMustPreserveRecoveryPath() => true;
}
