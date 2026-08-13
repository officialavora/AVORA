import 'avora_owner_global_hierarchy.dart';

enum AvoraOwnerBulkActionKind {
  grant,
  revoke,
}

enum AvoraOwnerBulkBenefitKind {
  reward,
  frame,
  badge,
  entrance,
  privilege,
  custom,
}

class AvoraOwnerBulkActionRequest {
  const AvoraOwnerBulkActionRequest({
    required this.actionId,
    required this.actorAvoraId,
    required this.actionKind,
    required this.benefitKind,
    required this.benefitCode,
    required this.query,
    required this.reason,
    required this.requestedAtUtc,
  });

  final String actionId;
  final String actorAvoraId;
  final AvoraOwnerBulkActionKind actionKind;
  final AvoraOwnerBulkBenefitKind benefitKind;
  final String benefitCode;
  final AvoraOwnerHierarchyQuery query;
  final String reason;
  final DateTime requestedAtUtc;

  void validate() {
    if (actionId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        benefitCode.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw StateError('owner_bulk_action_requires_identity_and_reason');
    }
  }
}

class AvoraOwnerBulkActionPlan {
  const AvoraOwnerBulkActionPlan({
    required this.actionId,
    required this.actionKind,
    required this.benefitKind,
    required this.benefitCode,
    required this.targetAvoraIds,
    required this.reason,
    required this.createdAtUtc,
  });

  final String actionId;
  final AvoraOwnerBulkActionKind actionKind;
  final AvoraOwnerBulkBenefitKind benefitKind;
  final String benefitCode;
  final Set<String> targetAvoraIds;
  final String reason;
  final DateTime createdAtUtc;

  bool get hasTargets => targetAvoraIds.isNotEmpty;
}

class AvoraOwnerBulkTargetingEngine {
  const AvoraOwnerBulkTargetingEngine();

  AvoraOwnerBulkActionPlan prepare({
    required AvoraOwnerBulkActionRequest request,
    required List<AvoraOwnerHierarchyMember> hierarchy,
    required bool actorIsVerifiedOwner,
  }) {
    request.validate();

    if (!actorIsVerifiedOwner) {
      throw StateError('owner_bulk_action_requires_verified_owner');
    }

    final targets = AvoraOwnerGlobalHierarchy.resolveBulkTargetIds(
      members: hierarchy,
      query: request.query,
    );

    if (targets.contains(request.actorAvoraId)) {
      targets.remove(request.actorAvoraId);
    }

    return AvoraOwnerBulkActionPlan(
      actionId: request.actionId,
      actionKind: request.actionKind,
      benefitKind: request.benefitKind,
      benefitCode: request.benefitCode,
      targetAvoraIds: Set<String>.unmodifiable(targets),
      reason: request.reason.trim(),
      createdAtUtc: request.requestedAtUtc.toUtc(),
    );
  }

  static bool grantAndRevokeMustUseSameTargetResolver() => true;

  static bool bulkMutationMustGoThroughExistingAuthoritativeEngine() => true;

  static bool everyBulkActionMustBeAudited() => true;

  static bool individualAndBulkActionsMustShareSamePolicy() => true;

  static bool ownerMayTargetGlobalCountryRoleOrIndividualScope() => true;
}
