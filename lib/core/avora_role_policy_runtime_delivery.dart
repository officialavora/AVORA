import 'avora_role_policy_delivery.dart';

/// Runtime orchestration boundary between role/capability activation and the
/// existing authoritative role-policy delivery engine.
///
/// This layer does not mutate access profiles, display policy UI, send the
/// actual notification, or record acknowledgement itself. Those existing
/// systems remain authoritative.
class AvoraRolePolicyRuntimeDelivery {
  const AvoraRolePolicyRuntimeDelivery._();

  static AvoraRolePolicyDeliveryInstruction onRoleActivated({
    required String immutableAvoraId,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return _prepare(
      immutableAvoraId: immutableAvoraId,
      trigger: AvoraRolePolicyDeliveryTrigger.roleActivated,
      assignment: assignment,
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static AvoraRolePolicyDeliveryInstruction onCapabilityActivated({
    required String immutableAvoraId,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return _prepare(
      immutableAvoraId: immutableAvoraId,
      trigger: AvoraRolePolicyDeliveryTrigger.capabilityActivated,
      assignment: assignment,
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static AvoraRolePolicyDeliveryInstruction onPolicyVersionChanged({
    required String immutableAvoraId,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return _prepare(
      immutableAvoraId: immutableAvoraId,
      trigger: AvoraRolePolicyDeliveryTrigger.policyVersionChanged,
      assignment: assignment,
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static AvoraRolePolicyDeliveryInstruction onMandatoryPolicyUpdated({
    required String immutableAvoraId,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return _prepare(
      immutableAvoraId: immutableAvoraId,
      trigger: AvoraRolePolicyDeliveryTrigger.mandatoryPolicyUpdated,
      assignment: assignment,
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static AvoraRolePolicyDeliveryInstruction onManualRefresh({
    required String immutableAvoraId,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return _prepare(
      immutableAvoraId: immutableAvoraId,
      trigger: AvoraRolePolicyDeliveryTrigger.manualRefresh,
      assignment: assignment,
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static AvoraRolePolicyDeliveryInstruction _prepare({
    required String immutableAvoraId,
    required AvoraRolePolicyDeliveryTrigger trigger,
    required AvoraActivePolicyAssignment assignment,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    return AvoraRolePolicyVisibilityEngine.prepareDelivery(
      immutableAvoraId: immutableAvoraId,
      trigger: trigger,
      assignments: [assignment],
      policies: policies,
      nowUtc: nowUtc,
    );
  }

  static bool mutatesAccessProfileInPlace() => false;

  static bool existingDeliverySystemsRemainAuthoritative() =>
      AvoraRolePolicyVisibilityEngine
          .existingPolicyCenterRemainsAuthoritative() &&
      AvoraRolePolicyVisibilityEngine
          .existingSystemNotificationRemainsAuthoritative() &&
      AvoraRolePolicyVisibilityEngine
          .existingPolicyAcknowledgementRemainsAuthoritative();
}
