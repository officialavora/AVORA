import 'avora_reward_eligibility.dart';
import 'avora_universal_cycle_settlement.dart';

enum AvoraOwnerPolicyRewardSourceKind {
  hostSalary,
  agencyCommission,
  bdCommission,
  csWeeklyReward,
  familyRankReward,
  agencyRankReward,
  managerReward,
  adminReward,
  superAdminReward,
  countryManagerReward,
  eventReward,
  creatorReward,
  talentReward,
  custom,
}

enum AvoraOwnerPolicySettlementAdapterDenyReason {
  none,
  sourceIneligible,
  invalidCycle,
  policySnapshotMismatch,
  beneficiaryNotRewardEligible,
  invalidIdentity,
  invalidReward,
  invalidDestination,
}

class AvoraOwnerPolicySettlementCandidate {
  const AvoraOwnerPolicySettlementCandidate({
    required this.sourceKind,
    required this.eligible,
    required this.subjectId,
    required this.beneficiaryAvoraId,
    required this.policySnapshotKey,
    required this.eligibleMetricUnits,
    required this.rewardValueType,
    required this.rewardUnits,
    required this.destinationKey,
    required this.settlementAdapterKey,
  });

  final AvoraOwnerPolicyRewardSourceKind sourceKind;

  /// Must come from an authoritative policy/qualification engine.
  final bool eligible;

  /// Can represent AVORA ID, Agency ID, Family ID, event ID, etc.
  final String subjectId;

  /// Immutable AVORA ID that ultimately receives the reward.
  final String beneficiaryAvoraId;

  /// Exact historical/running policy snapshot used for qualification.
  final String policySnapshotKey;

  /// Already-finalized eligible metric from the source policy engine.
  final int eligibleMetricUnits;

  /// Opaque downstream reward type, e.g. fiatMinor / coins / frame.
  final String rewardValueType;

  final int rewardUnits;

  /// Existing downstream destination understood by settlement infrastructure.
  final String destinationKey;

  /// Existing authoritative settlement adapter key.
  final String settlementAdapterKey;

  bool get structurallyValid =>
      subjectId.trim().isNotEmpty &&
      beneficiaryAvoraId.trim().isNotEmpty &&
      policySnapshotKey.trim().isNotEmpty &&
      eligibleMetricUnits >= 0 &&
      rewardValueType.trim().isNotEmpty &&
      rewardUnits >= 0 &&
      destinationKey.trim().isNotEmpty &&
      settlementAdapterKey.trim().isNotEmpty;
}

class AvoraOwnerPolicySettlementAdapterDecision {
  const AvoraOwnerPolicySettlementAdapterDecision({
    required this.allowed,
    required this.reason,
    required this.policySnapshotKey,
    this.subject,
  });

  final bool allowed;
  final AvoraOwnerPolicySettlementAdapterDenyReason reason;

  /// Retained for audit/debug handoff even though the actual cycle remains
  /// authoritative for final settlement history.
  final String policySnapshotKey;

  final AvoraUniversalSettlementSubject? subject;
}

class AvoraOwnerPolicySettlementAdapter {
  const AvoraOwnerPolicySettlementAdapter._();

  static AvoraOwnerPolicySettlementAdapterDecision createSubject({
    required AvoraOwnerPolicySettlementCandidate candidate,
    required AvoraUniversalCycleSnapshot cycle,
    required AvoraRewardEligibilityProfile beneficiaryEligibility,
  }) {
    AvoraOwnerPolicySettlementAdapterDecision deny(
      AvoraOwnerPolicySettlementAdapterDenyReason reason,
    ) {
      return AvoraOwnerPolicySettlementAdapterDecision(
        allowed: false,
        reason: reason,
        policySnapshotKey: candidate.policySnapshotKey,
      );
    }

    if (!candidate.eligible) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.sourceIneligible,
      );
    }

    if (!cycle.valid) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.invalidCycle,
      );
    }

    if (cycle.policyVersion != candidate.policySnapshotKey) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.policySnapshotMismatch,
      );
    }

    if (!beneficiaryEligibility.eligibleForRewards) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason
            .beneficiaryNotRewardEligible,
      );
    }

    if (candidate.subjectId.trim().isEmpty ||
        candidate.beneficiaryAvoraId.trim().isEmpty) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.invalidIdentity,
      );
    }

    if (candidate.eligibleMetricUnits < 0 ||
        candidate.rewardUnits < 0 ||
        candidate.rewardValueType.trim().isEmpty) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.invalidReward,
      );
    }

    if (candidate.destinationKey.trim().isEmpty ||
        candidate.settlementAdapterKey.trim().isEmpty) {
      return deny(
        AvoraOwnerPolicySettlementAdapterDenyReason.invalidDestination,
      );
    }

    return AvoraOwnerPolicySettlementAdapterDecision(
      allowed: true,
      reason: AvoraOwnerPolicySettlementAdapterDenyReason.none,
      policySnapshotKey: candidate.policySnapshotKey,
      subject: AvoraUniversalSettlementSubject(
        subjectId: candidate.subjectId.trim(),
        beneficiaryAvoraId: candidate.beneficiaryAvoraId.trim(),
        beneficiaryEligibility: beneficiaryEligibility,
        eligibleMetricUnits: candidate.eligibleMetricUnits,
        rewardValueType: candidate.rewardValueType.trim(),
        rewardUnits: candidate.rewardUnits,
        destinationKey: candidate.destinationKey.trim(),
        settlementAdapterKey: candidate.settlementAdapterKey.trim(),
      ),
    );
  }

  /// Host/Agency/BD/CS/Family/etc. source engine decides qualification.
  static bool adapterCanSelfQualifyReward() => false;

  /// Unverified/blocked/inactive beneficiary cannot bypass central gate.
  static bool verifiedRewardEligibilityRemainsAuthoritative() => true;

  /// Running/historical cycle must settle using the exact policy snapshot
  /// that produced the qualification result.
  static bool policySnapshotMustMatchCycle() => true;

  /// Mid-cycle policy edits cannot silently rewrite this candidate's history.
  static bool historicalCandidatePolicyCanBeSilentlyRewritten() => false;

  /// This adapter creates only a settlement subject; it never changes money,
  /// Coins, Diamonds, salary balance, or any wallet directly.
  static bool adapterDirectlyCreditsCoinsSalaryOrWallet() => false;

  /// Final credit remains in the existing Universal Auto Settlement path.
  static bool universalAutoSettlementRemainsAuthoritative() => true;

  /// Mobile/client cannot force an ineligible policy result into settlement.
  static bool clientCanForcePolicyRewardSettlement() => false;

  /// Different legitimate role earnings may each create independent subjects
  /// when each source independently qualifies.
  static bool independentlyQualifiedMultiRoleRewardsSupported() => true;
}
