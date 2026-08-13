import 'avora_hierarchical_qualification.dart';
import 'avora_reward_eligibility.dart';
import 'avora_universal_cycle_settlement.dart';

enum AvoraHierarchicalSettlementAdapterDenyReason {
  none,
  qualificationIneligible,
  invalidCycle,
  policySnapshotMismatch,
  invalidReward,
  invalidDestination,
  beneficiaryNotRewardEligible,
}

class AvoraHierarchicalSettlementAdapterDecision {
  const AvoraHierarchicalSettlementAdapterDecision({
    required this.allowed,
    required this.reason,
    this.subject,
  });

  final bool allowed;
  final AvoraHierarchicalSettlementAdapterDenyReason reason;
  final AvoraUniversalSettlementSubject? subject;
}

class AvoraHierarchicalSettlementAdapter {
  const AvoraHierarchicalSettlementAdapter._();

  static AvoraHierarchicalSettlementAdapterDecision prepareSubject({
    required AvoraHierarchicalQualificationResult qualification,
    required AvoraUniversalCycleSnapshot cycle,
    required String subjectId,
    required String beneficiaryAvoraId,
    required AvoraRewardEligibilityProfile beneficiaryEligibility,
    required int eligibleMetricUnits,
    required String rewardValueType,
    required int rewardUnits,
    required String destinationKey,
    required String settlementAdapterKey,
  }) {
    if (!qualification.eligible) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason: AvoraHierarchicalSettlementAdapterDenyReason
            .qualificationIneligible,
      );
    }

    if (!cycle.valid) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason: AvoraHierarchicalSettlementAdapterDenyReason.invalidCycle,
      );
    }

    if (cycle.policyVersion != qualification.policySnapshotKey) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason:
            AvoraHierarchicalSettlementAdapterDenyReason.policySnapshotMismatch,
      );
    }

    if (!beneficiaryEligibility.eligibleForRewards) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason: AvoraHierarchicalSettlementAdapterDenyReason
            .beneficiaryNotRewardEligible,
      );
    }

    if (subjectId.trim().isEmpty ||
        beneficiaryAvoraId.trim().isEmpty ||
        eligibleMetricUnits < 0 ||
        rewardUnits <= 0 ||
        rewardValueType.trim().isEmpty) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason: AvoraHierarchicalSettlementAdapterDenyReason.invalidReward,
      );
    }

    if (destinationKey.trim().isEmpty || settlementAdapterKey.trim().isEmpty) {
      return const AvoraHierarchicalSettlementAdapterDecision(
        allowed: false,
        reason: AvoraHierarchicalSettlementAdapterDenyReason.invalidDestination,
      );
    }

    return AvoraHierarchicalSettlementAdapterDecision(
      allowed: true,
      reason: AvoraHierarchicalSettlementAdapterDenyReason.none,
      subject: AvoraUniversalSettlementSubject(
        subjectId: subjectId.trim(),
        beneficiaryAvoraId: beneficiaryAvoraId.trim(),
        beneficiaryEligibility: beneficiaryEligibility,
        eligibleMetricUnits: eligibleMetricUnits,
        rewardValueType: rewardValueType.trim(),
        rewardUnits: rewardUnits,
        destinationKey: destinationKey.trim(),
        settlementAdapterKey: settlementAdapterKey.trim(),
      ),
    );
  }

  static bool ineligibleQualificationCanCreateSettlementSubject() => false;

  static bool policySnapshotMustMatchCycle() => true;

  static bool verifiedRewardEligibilityMustRemainAuthoritative() => true;

  static bool adapterDirectlyCreditsCoinsOrSalary() => false;

  static bool universalSettlementRemainsAuthoritative() => true;

  static bool clientCanForceQualificationSettlement() => false;
}
