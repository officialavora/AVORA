import 'avora_identity_impersonation_audit.dart';

enum AvoraIdentityRiskAction {
  none,
  warning,
  review,
  temporaryIdentityEditRestriction,
  securityEscalation,
}

class AvoraIdentityRiskDecision {
  const AvoraIdentityRiskDecision({
    required this.action,
    required this.attemptCount,
    required this.humanReviewRequired,
    required this.automaticPermanentBanAllowed,
  });

  final AvoraIdentityRiskAction action;
  final int attemptCount;
  final bool humanReviewRequired;
  final bool automaticPermanentBanAllowed;
}

class AvoraIdentityImpersonationRiskEngine {
  const AvoraIdentityImpersonationRiskEngine();

  AvoraIdentityRiskDecision evaluate({
    required String actorAvoraId,
    required Iterable<AvoraImpersonationAuditRecord> records,
  }) {
    final attempts =
        records.where((record) => record.actorAvoraId == actorAvoraId).length;

    if (attempts >= 6) {
      return AvoraIdentityRiskDecision(
        action: AvoraIdentityRiskAction.securityEscalation,
        attemptCount: attempts,
        humanReviewRequired: true,
        automaticPermanentBanAllowed: false,
      );
    }

    if (attempts >= 4) {
      return AvoraIdentityRiskDecision(
        action: AvoraIdentityRiskAction.temporaryIdentityEditRestriction,
        attemptCount: attempts,
        humanReviewRequired: true,
        automaticPermanentBanAllowed: false,
      );
    }

    if (attempts >= 2) {
      return AvoraIdentityRiskDecision(
        action: AvoraIdentityRiskAction.review,
        attemptCount: attempts,
        humanReviewRequired: true,
        automaticPermanentBanAllowed: false,
      );
    }

    if (attempts == 1) {
      return AvoraIdentityRiskDecision(
        action: AvoraIdentityRiskAction.warning,
        attemptCount: attempts,
        humanReviewRequired: false,
        automaticPermanentBanAllowed: false,
      );
    }

    return const AvoraIdentityRiskDecision(
      action: AvoraIdentityRiskAction.none,
      attemptCount: 0,
      humanReviewRequired: false,
      automaticPermanentBanAllowed: false,
    );
  }

  static bool singleSimilarityMustNotPermanentBan() => true;

  static bool repeatedAttemptsMayIncreaseRisk() => true;

  static bool identityRestrictionMustBeTemporaryByDefault() => true;

  static bool seriousRepeatedCasesMustReachHumanReview() => true;

  static bool permanentBanMustNotComeFromThisSignalAlone() => true;

  static bool ownerMustSeeRiskHistory() => true;

  static bool futureProtectedIdentityTypesMustUseSameRiskEngine() => true;
}
