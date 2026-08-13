enum AvoraRolePolicyAudience {
  host,
  agency,
  bd,
  admin,
  superAdmin,
  manager,
}

enum AvoraRolePolicyDeliveryTrigger {
  roleActivated,
  capabilityActivated,
  policyVersionChanged,
  mandatoryPolicyUpdated,
  manualRefresh,
}

class AvoraRolePolicyDocument {
  const AvoraRolePolicyDocument({
    required this.policyId,
    required this.audience,
    required this.policyVersion,
    required this.effectiveFromUtc,
    required this.countryCode,
    required this.scopeKey,
    required this.active,
    required this.acknowledgementRequired,
  });

  final String policyId;
  final AvoraRolePolicyAudience audience;
  final String policyVersion;
  final DateTime effectiveFromUtc;

  /// Empty means global/default policy.
  final String countryCode;

  /// Country/agency/team/etc. scope identifier.
  final String scopeKey;

  final bool active;
  final bool acknowledgementRequired;

  String get deduplicationKey =>
      '$policyId|$policyVersion|${audience.name}|$countryCode|$scopeKey';

  bool get valid =>
      policyId.trim().isNotEmpty &&
      policyVersion.trim().isNotEmpty &&
      effectiveFromUtc.isUtc;
}

class AvoraActivePolicyAssignment {
  const AvoraActivePolicyAssignment({
    required this.audience,
    required this.active,
    required this.countryCode,
    required this.scopeKey,
  });

  final AvoraRolePolicyAudience audience;
  final bool active;
  final String countryCode;
  final String scopeKey;
}

class AvoraRolePolicyDeliveryInstruction {
  const AvoraRolePolicyDeliveryInstruction({
    required this.immutableAvoraId,
    required this.trigger,
    required this.visiblePolicies,
    required this.openPolicyCenter,
    required this.sendSystemNotification,
    required this.requireAcknowledgement,
  });

  final String immutableAvoraId;
  final AvoraRolePolicyDeliveryTrigger trigger;
  final List<AvoraRolePolicyDocument> visiblePolicies;

  /// Existing Policy Center handles actual display.
  final bool openPolicyCenter;

  /// Existing system notification/broadcast engine handles actual delivery.
  final bool sendSystemNotification;

  /// Existing acknowledgement/read-receipt engine remains authoritative.
  final bool requireAcknowledgement;
}

class AvoraRolePolicyVisibilityEngine {
  const AvoraRolePolicyVisibilityEngine._();

  static List<AvoraRolePolicyAudience> visibleAudiencesFor(
    AvoraRolePolicyAudience audience,
  ) {
    switch (audience) {
      case AvoraRolePolicyAudience.host:
        return const [
          AvoraRolePolicyAudience.host,
        ];

      case AvoraRolePolicyAudience.agency:
        return const [
          AvoraRolePolicyAudience.agency,
          AvoraRolePolicyAudience.host,
        ];

      case AvoraRolePolicyAudience.bd:
        return const [
          AvoraRolePolicyAudience.bd,
          AvoraRolePolicyAudience.agency,
          AvoraRolePolicyAudience.host,
        ];

      case AvoraRolePolicyAudience.admin:
        return const [
          AvoraRolePolicyAudience.admin,
          AvoraRolePolicyAudience.bd,
          AvoraRolePolicyAudience.agency,
          AvoraRolePolicyAudience.host,
        ];

      case AvoraRolePolicyAudience.superAdmin:
        return const [
          AvoraRolePolicyAudience.superAdmin,
          AvoraRolePolicyAudience.admin,
          AvoraRolePolicyAudience.bd,
          AvoraRolePolicyAudience.agency,
          AvoraRolePolicyAudience.host,
        ];

      case AvoraRolePolicyAudience.manager:
        return const [
          AvoraRolePolicyAudience.manager,
          AvoraRolePolicyAudience.superAdmin,
          AvoraRolePolicyAudience.admin,
          AvoraRolePolicyAudience.bd,
          AvoraRolePolicyAudience.agency,
          AvoraRolePolicyAudience.host,
        ];
    }
  }

  static bool canViewAudience({
    required AvoraRolePolicyAudience viewer,
    required AvoraRolePolicyAudience policyAudience,
  }) {
    return visibleAudiencesFor(viewer).contains(policyAudience);
  }

  static List<AvoraRolePolicyDocument> resolveVisiblePolicies({
    required List<AvoraActivePolicyAssignment> assignments,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    final activeAssignments =
        assignments.where((assignment) => assignment.active).toList();

    final visibleAudienceSet = <AvoraRolePolicyAudience>{};

    for (final assignment in activeAssignments) {
      visibleAudienceSet.addAll(
        visibleAudiencesFor(assignment.audience),
      );
    }

    final resultByKey = <String, AvoraRolePolicyDocument>{};

    for (final policy in policies) {
      if (!policy.valid || !policy.active) continue;
      if (policy.effectiveFromUtc.isAfter(nowUtc)) continue;

      if (!visibleAudienceSet.contains(policy.audience)) continue;

      final scopeMatches = activeAssignments.any((assignment) {
        if (!visibleAudiencesFor(assignment.audience)
            .contains(policy.audience)) {
          return false;
        }

        final countryMatches = policy.countryCode.trim().isEmpty ||
            assignment.countryCode.trim().isEmpty ||
            policy.countryCode.trim() == assignment.countryCode.trim();

        final scopeMatches = policy.scopeKey.trim().isEmpty ||
            assignment.scopeKey.trim().isEmpty ||
            policy.scopeKey.trim() == assignment.scopeKey.trim();

        return countryMatches && scopeMatches;
      });

      if (!scopeMatches) continue;

      resultByKey[policy.deduplicationKey] = policy;
    }

    final result = resultByKey.values.toList()
      ..sort((a, b) {
        final audienceCompare = _authorityWeight(b.audience)
            .compareTo(_authorityWeight(a.audience));

        if (audienceCompare != 0) return audienceCompare;

        return b.effectiveFromUtc.compareTo(a.effectiveFromUtc);
      });

    return List.unmodifiable(result);
  }

  static AvoraRolePolicyDeliveryInstruction prepareDelivery({
    required String immutableAvoraId,
    required AvoraRolePolicyDeliveryTrigger trigger,
    required List<AvoraActivePolicyAssignment> assignments,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    final visible = resolveVisiblePolicies(
      assignments: assignments,
      policies: policies,
      nowUtc: nowUtc,
    );

    return AvoraRolePolicyDeliveryInstruction(
      immutableAvoraId: immutableAvoraId.trim(),
      trigger: trigger,
      visiblePolicies: visible,
      openPolicyCenter: visible.isNotEmpty,
      sendSystemNotification: visible.isNotEmpty,
      requireAcknowledgement:
          visible.any((policy) => policy.acknowledgementRequired),
    );
  }

  static int _authorityWeight(AvoraRolePolicyAudience audience) {
    switch (audience) {
      case AvoraRolePolicyAudience.host:
        return 100;
      case AvoraRolePolicyAudience.agency:
        return 200;
      case AvoraRolePolicyAudience.bd:
        return 300;
      case AvoraRolePolicyAudience.admin:
        return 400;
      case AvoraRolePolicyAudience.superAdmin:
        return 500;
      case AvoraRolePolicyAudience.manager:
        return 600;
    }
  }

  /// Role/capability activation should automatically prepare policy delivery.
  static bool activationTriggersPolicyDelivery() => true;

  /// Higher operational role may read applicable lower-role policies.
  static bool downwardPolicyVisibilitySupported() => true;

  /// Lower role cannot read higher-role policies merely because they exist.
  static bool upwardPolicyVisibilityAllowedByDefault() => false;

  /// Same ID may hold multiple roles; policies are unioned without duplicates.
  static bool multiRolePolicyUnionSupported() => true;

  /// Existing Policy Center remains authoritative for UI/read experience.
  static bool existingPolicyCenterRemainsAuthoritative() => true;

  /// Existing system notification/broadcast infrastructure performs delivery.
  static bool existingSystemNotificationRemainsAuthoritative() => true;

  /// Existing acknowledgement/read-receipt infrastructure remains authoritative.
  static bool existingPolicyAcknowledgementRemainsAuthoritative() => true;

  /// Policy visibility alone never grants backend permissions.
  static bool policyVisibilityGrantsBackendAuthority() => false;

  /// Historical policy snapshots must remain immutable.
  static bool historicalPolicyVersionCanBeSilentlyRewritten() => false;

  /// Future policy versions may trigger a fresh delivery/read requirement.
  static bool policyVersionChangeCanTriggerRedelivery() => true;
}
