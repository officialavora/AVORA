enum AvoraAccessEnforcementScope {
  account,
  device,
  network,
}

enum AvoraAccessSeverityClass {
  a,
  b,
  c,
}

enum AvoraAccessEnforcementCategory {
  behavior,
  spam,
  economicAbuse,
  chargeback,
  fraud,
  safety,
  legal,
  accountIntegrity,
  deviceIntegrity,
  networkRisk,
  other,
}

enum AvoraAccessEnforcementStatus {
  active,
  revoked,
  expired,
}

enum AvoraReinstatementCondition {
  cooldownCompleted,
  policyAcknowledged,
  identityReverified,
  deviceReverified,
  appealApproved,
  manualReviewApproved,

  /// Only actual recoverable economic liability.
  outstandingBalanceSettled,

  /// Optional future commercial restoration for
  /// eligible NON-safety restrictions only.
  commercialRestorationCompleted,
}

class AvoraAccessEnforcement {
  final String id;

  final AvoraAccessEnforcementScope scope;

  /// Account ID, internal device reference,
  /// or internal network-risk reference.
  /// Public UI must not expose sensitive device/IP details.
  final String targetReferenceId;

  final String? accountAvoraId;

  final AvoraAccessSeverityClass severity;

  final AvoraAccessEnforcementCategory category;

  final AvoraAccessEnforcementStatus status;

  final String reasonCode;

  /// Safe user-facing explanation.
  final String safeReasonText;

  final String caseReferenceId;

  final String issuedByAvoraId;

  final DateTime startsAt;

  /// Null = permanent until revoked.
  final DateTime? endsAt;

  final bool appealAllowed;

  /// Public badge applies only to finalized account enforcement.
  final bool publicAccountBanMarker;

  final bool finalDecision;

  const AvoraAccessEnforcement({
    required this.id,
    required this.scope,
    required this.targetReferenceId,
    required this.severity,
    required this.category,
    required this.status,
    required this.reasonCode,
    required this.safeReasonText,
    required this.caseReferenceId,
    required this.issuedByAvoraId,
    required this.startsAt,
    required this.appealAllowed,
    required this.publicAccountBanMarker,
    required this.finalDecision,
    this.accountAvoraId,
    this.endsAt,
  });

  bool get permanent => endsAt == null;

  bool isActiveAt(DateTime now) {
    if (status != AvoraAccessEnforcementStatus.active) {
      return false;
    }

    if (now.isBefore(startsAt)) {
      return false;
    }

    final end = endsAt;

    if (end != null && !now.isBefore(end)) {
      return false;
    }

    return true;
  }

  bool get canShowPublicBannedUser {
    return scope == AvoraAccessEnforcementScope.account &&
        finalDecision &&
        publicAccountBanMarker &&
        status == AvoraAccessEnforcementStatus.active;
  }
}

class AvoraReinstatementPolicy {
  final String id;

  final AvoraAccessSeverityClass severity;

  final Set<AvoraReinstatementCondition> requiredConditions;

  /// Actual recoverable economic debt/chargeback only.
  final int requiredOutstandingSettlementUnits;

  /// Optional and disabled by default.
  /// Never valid for serious safety/legal/fraud cases.
  final bool commercialRestorationEnabled;

  final int commercialRestorationUnits;

  final bool countryPolicyAllowsCommercialRestoration;

  const AvoraReinstatementPolicy({
    required this.id,
    required this.severity,
    required this.requiredConditions,
    this.requiredOutstandingSettlementUnits = 0,
    this.commercialRestorationEnabled = false,
    this.commercialRestorationUnits = 0,
    this.countryPolicyAllowsCommercialRestoration = false,
  })  : assert(requiredOutstandingSettlementUnits >= 0),
        assert(commercialRestorationUnits >= 0);
}

class AvoraReinstatementContext {
  final bool cooldownCompleted;
  final bool policyAcknowledged;
  final bool identityReverified;
  final bool deviceReverified;
  final bool appealApproved;
  final bool manualReviewApproved;

  final int settledOutstandingUnits;

  final bool commercialRestorationCompleted;

  const AvoraReinstatementContext({
    this.cooldownCompleted = false,
    this.policyAcknowledged = false,
    this.identityReverified = false,
    this.deviceReverified = false,
    this.appealApproved = false,
    this.manualReviewApproved = false,
    this.settledOutstandingUnits = 0,
    this.commercialRestorationCompleted = false,
  }) : assert(settledOutstandingUnits >= 0);
}

enum AvoraReinstatementDenyReason {
  none,
  enforcementInactive,
  conditionMissing,
  outstandingBalanceNotSettled,
  commercialRestorationNotAllowed,
  commercialRestorationIncomplete,
  severeCategoryCannotBePurchasedAway,
}

class AvoraReinstatementDecision {
  final bool allowed;
  final AvoraReinstatementDenyReason reason;

  final Set<AvoraReinstatementCondition> missingConditions;

  const AvoraReinstatementDecision({
    required this.allowed,
    required this.reason,
    required this.missingConditions,
  });
}

class AvoraLoginEnforcementPresentation {
  final String headline;

  final String safeReasonText;

  final String caseReferenceId;

  final bool permanent;

  final DateTime? expiresAt;

  final bool appealAllowed;

  const AvoraLoginEnforcementPresentation({
    required this.headline,
    required this.safeReasonText,
    required this.caseReferenceId,
    required this.permanent,
    required this.expiresAt,
    required this.appealAllowed,
  });
}

class AvoraAccessEnforcementPolicy {
  const AvoraAccessEnforcementPolicy._();

  static AvoraLoginEnforcementPresentation loginPresentation(
    AvoraAccessEnforcement enforcement,
  ) {
    final headline = switch (enforcement.scope) {
      AvoraAccessEnforcementScope.account => 'Account Banned',
      AvoraAccessEnforcementScope.device => 'Device Restricted',
      AvoraAccessEnforcementScope.network => 'Network Access Restricted',
    };

    return AvoraLoginEnforcementPresentation(
      headline: headline,
      safeReasonText: enforcement.safeReasonText,
      caseReferenceId: enforcement.caseReferenceId,
      permanent: enforcement.permanent,
      expiresAt: enforcement.endsAt,
      appealAllowed: enforcement.appealAllowed,
    );
  }

  static AvoraReinstatementDecision evaluateReinstatement({
    required AvoraAccessEnforcement enforcement,
    required AvoraReinstatementPolicy policy,
    required AvoraReinstatementContext context,
    required DateTime now,
  }) {
    if (!enforcement.isActiveAt(now)) {
      return const AvoraReinstatementDecision(
        allowed: false,
        reason: AvoraReinstatementDenyReason.enforcementInactive,
        missingConditions: {},
      );
    }

    final severeCategory =
        enforcement.category == AvoraAccessEnforcementCategory.safety ||
            enforcement.category == AvoraAccessEnforcementCategory.legal ||
            enforcement.category == AvoraAccessEnforcementCategory.fraud;

    if (severeCategory &&
        (policy.commercialRestorationEnabled ||
            policy.requiredConditions.contains(
              AvoraReinstatementCondition.commercialRestorationCompleted,
            ))) {
      return const AvoraReinstatementDecision(
        allowed: false,
        reason:
            AvoraReinstatementDenyReason.severeCategoryCannotBePurchasedAway,
        missingConditions: {},
      );
    }

    if (policy.requiredOutstandingSettlementUnits > 0 &&
        context.settledOutstandingUnits <
            policy.requiredOutstandingSettlementUnits) {
      return const AvoraReinstatementDecision(
        allowed: false,
        reason: AvoraReinstatementDenyReason.outstandingBalanceNotSettled,
        missingConditions: {
          AvoraReinstatementCondition.outstandingBalanceSettled,
        },
      );
    }

    if (policy.commercialRestorationEnabled) {
      if (!policy.countryPolicyAllowsCommercialRestoration) {
        return const AvoraReinstatementDecision(
          allowed: false,
          reason: AvoraReinstatementDenyReason.commercialRestorationNotAllowed,
          missingConditions: {},
        );
      }

      if (!context.commercialRestorationCompleted) {
        return const AvoraReinstatementDecision(
          allowed: false,
          reason: AvoraReinstatementDenyReason.commercialRestorationIncomplete,
          missingConditions: {
            AvoraReinstatementCondition.commercialRestorationCompleted,
          },
        );
      }
    }

    final missing = <AvoraReinstatementCondition>{};

    bool satisfied(AvoraReinstatementCondition condition) {
      return switch (condition) {
        AvoraReinstatementCondition.cooldownCompleted =>
          context.cooldownCompleted,
        AvoraReinstatementCondition.policyAcknowledged =>
          context.policyAcknowledged,
        AvoraReinstatementCondition.identityReverified =>
          context.identityReverified,
        AvoraReinstatementCondition.deviceReverified =>
          context.deviceReverified,
        AvoraReinstatementCondition.appealApproved => context.appealApproved,
        AvoraReinstatementCondition.manualReviewApproved =>
          context.manualReviewApproved,
        AvoraReinstatementCondition.outstandingBalanceSettled =>
          context.settledOutstandingUnits >=
              policy.requiredOutstandingSettlementUnits,
        AvoraReinstatementCondition.commercialRestorationCompleted =>
          context.commercialRestorationCompleted,
      };
    }

    for (final condition in policy.requiredConditions) {
      if (!satisfied(condition)) {
        missing.add(condition);
      }
    }

    if (missing.isNotEmpty) {
      return AvoraReinstatementDecision(
        allowed: false,
        reason: AvoraReinstatementDenyReason.conditionMissing,
        missingConditions: Set.unmodifiable(missing),
      );
    }

    return const AvoraReinstatementDecision(
      allowed: true,
      reason: AvoraReinstatementDenyReason.none,
      missingConditions: {},
    );
  }

  /// Spending/VIP status never overrides serious enforcement.
  static bool highRechargeAutomaticallyOverridesBan() {
    return false;
  }

  /// Shared/dynamic network evidence alone is insufficient
  /// for automatic permanent account bans.
  static bool ipMatchAloneJustifiesPermanentAccountBan() {
    return false;
  }

  /// Device/network details remain internal.
  static bool exposeRawIpOrDeviceFingerprintOnLogin() {
    return false;
  }
}
