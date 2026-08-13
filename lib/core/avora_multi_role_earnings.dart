enum AvoraEarningSourceType {
  hostPerformance,
  agencyOwnerPerformance,
  bdPerformance,
  managerPerformance,
  superAdminPerformance,
  adminPerformance,
  countryManagerPerformance,
  sellerCommission,
  merchantCommission,
  csHeadPerformance,
  csAgentPerformance,
  eventOrganizerPerformance,
  creatorPerformance,
  talentPerformance,
  staffCommission,

  /// Future post/capability without redesigning the earning engine.
  customAssignment,
  other,
}

enum AvoraEarningStatus {
  pending,
  qualified,
  approved,
  settled,
  reversed,
  rejected,
}

class AvoraEarningComponent {
  const AvoraEarningComponent({
    required this.componentId,
    required this.beneficiaryAvoraId,
    required this.sourceType,
    required this.assignmentId,
    required this.compensationRuleId,
    required this.periodKey,
    required this.activityBasisId,
    required this.amountMinor,
    required this.currencyCode,
    this.requiredTargetValue = 0,
    this.achievedValue = 0,
    required this.qualified,
    required this.status,
    required this.createdAt,
    required this.policyVersion,
    required this.referenceId,
  });

  final String componentId;

  /// Immutable AVORA ID receiving this earning component.
  final String beneficiaryAvoraId;

  /// Host, Agency Owner, BD etc. are calculated independently.
  final AvoraEarningSourceType sourceType;

  /// Exact active role/capability assignment that earned this amount.
  final String assignmentId;

  /// Server compensation rule used for calculation.
  final String compensationRuleId;

  /// Example: monthly/weekly settlement period identifier.
  final String periodKey;

  /// Identifies the work/activity basis used by this component.
  final String activityBasisId;

  /// Fiat value in smallest currency unit, never floating point.
  final int amountMinor;
  final String currencyCode;

  final int requiredTargetValue;
  final int achievedValue;

  final bool qualified;
  final AvoraEarningStatus status;

  final DateTime createdAt;
  final String policyVersion;
  final String referenceId;

  bool get targetSatisfied =>
      requiredTargetValue <= 0 || achievedValue >= requiredTargetValue;

  /// Prevents the exact same compensation component from being
  /// credited twice.
  String get deduplicationKey => '$beneficiaryAvoraId|'
      '${sourceType.name}|'
      '$assignmentId|'
      '$compensationRuleId|'
      '$periodKey|'
      '$activityBasisId';
}

class AvoraEarningDecision {
  const AvoraEarningDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraMultiRoleEarningsEngine {
  static AvoraEarningDecision validateNewComponent({
    required AvoraEarningComponent candidate,
    required Iterable<AvoraEarningComponent> existing,
  }) {
    if (candidate.beneficiaryAvoraId.trim().isEmpty ||
        candidate.assignmentId.trim().isEmpty ||
        candidate.compensationRuleId.trim().isEmpty ||
        candidate.periodKey.trim().isEmpty ||
        candidate.activityBasisId.trim().isEmpty ||
        candidate.currencyCode.trim().isEmpty ||
        candidate.policyVersion.trim().isEmpty ||
        candidate.referenceId.trim().isEmpty) {
      return const AvoraEarningDecision(
        allowed: false,
        reason: 'missingRequiredMetadata',
      );
    }

    if (candidate.amountMinor <= 0) {
      return const AvoraEarningDecision(
        allowed: false,
        reason: 'invalidAmount',
      );
    }

    if (!candidate.qualified) {
      return const AvoraEarningDecision(
        allowed: false,
        reason: 'earningNotQualified',
      );
    }

    if (!candidate.targetSatisfied) {
      return const AvoraEarningDecision(
        allowed: false,
        reason: 'targetNotSatisfied',
      );
    }

    if (candidate.status == AvoraEarningStatus.reversed ||
        candidate.status == AvoraEarningStatus.rejected) {
      return const AvoraEarningDecision(
        allowed: false,
        reason: 'invalidEarningStatus',
      );
    }

    for (final current in existing) {
      if (current.componentId == candidate.componentId) {
        return const AvoraEarningDecision(
          allowed: false,
          reason: 'duplicateComponentId',
        );
      }

      if (current.deduplicationKey == candidate.deduplicationKey &&
          current.status != AvoraEarningStatus.reversed &&
          current.status != AvoraEarningStatus.rejected) {
        return const AvoraEarningDecision(
          allowed: false,
          reason: 'duplicateCompensationComponent',
        );
      }
    }

    return const AvoraEarningDecision(
      allowed: true,
      reason: 'independentlyQualifiedEarning',
    );
  }

  /// Different legitimate roles may stack for the same AVORA ID
  /// when each uses its own assignment/rule/work basis.
  static bool canStack({
    required AvoraEarningComponent first,
    required AvoraEarningComponent second,
  }) {
    if (first.beneficiaryAvoraId != second.beneficiaryAvoraId) {
      return false;
    }

    if (!first.qualified ||
        !second.qualified ||
        !first.targetSatisfied ||
        !second.targetSatisfied) {
      return false;
    }

    return first.deduplicationKey != second.deduplicationKey;
  }

  static int approvedUnsettledTotalMinor({
    required Iterable<AvoraEarningComponent> components,
    required String beneficiaryAvoraId,
    required String currencyCode,
  }) {
    var total = 0;

    for (final component in components) {
      if (component.beneficiaryAvoraId != beneficiaryAvoraId) continue;
      if (component.currencyCode != currencyCode) continue;
      if (component.status != AvoraEarningStatus.approved) continue;
      if (!component.qualified || !component.targetSatisfied) continue;

      total += component.amountMinor;
    }

    return total;
  }

  static int historicalSettledTotalMinor({
    required Iterable<AvoraEarningComponent> components,
    required String beneficiaryAvoraId,
    required String currencyCode,
  }) {
    var total = 0;

    for (final component in components) {
      if (component.beneficiaryAvoraId != beneficiaryAvoraId) continue;
      if (component.currencyCode != currencyCode) continue;
      if (component.status != AvoraEarningStatus.settled) continue;

      total += component.amountMinor;
    }

    return total;
  }

  /// One role title alone never creates salary.
  static bool roleTitleAloneCreatesEarning() => false;

  /// Mobile/client cannot credit its own salary or commission.
  static bool clientCanSelfCreditEarnings() => false;

  /// Same immutable AVORA ID may legitimately earn from
  /// multiple independently-qualified assignments.
  static bool multiRoleEarningSupported() => true;
}
