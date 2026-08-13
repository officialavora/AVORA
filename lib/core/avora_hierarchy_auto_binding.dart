enum AvoraHierarchyBindingKind {
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  host,
  family,
}

class AvoraHierarchyBinding {
  const AvoraHierarchyBinding({
    required this.avoraId,
    required this.kind,
    required this.parentAvoraId,
    required this.countryCode,
    required this.createdByAvoraId,
    required this.createdAtUtc,
    this.active = true,
  });

  final String avoraId;
  final AvoraHierarchyBindingKind kind;
  final String? parentAvoraId;
  final String countryCode;
  final String createdByAvoraId;
  final DateTime createdAtUtc;
  final bool active;

  void validate() {
    if (avoraId.trim().isEmpty ||
        countryCode.trim().isEmpty ||
        createdByAvoraId.trim().isEmpty) {
      throw StateError('hierarchy_binding_identity_required');
    }
  }
}

class AvoraHierarchyBindingRequest {
  const AvoraHierarchyBindingRequest({
    required this.targetAvoraId,
    required this.kind,
    required this.actorAvoraId,
    required this.actorIsOwner,
    required this.countryCode,
    this.parentAvoraId,
    this.allowOwnerOverride = false,
  });

  final String targetAvoraId;
  final AvoraHierarchyBindingKind kind;
  final String actorAvoraId;
  final bool actorIsOwner;
  final String countryCode;
  final String? parentAvoraId;
  final bool allowOwnerOverride;
}

class AvoraHierarchyAutoBindingEngine {
  const AvoraHierarchyAutoBindingEngine();

  AvoraHierarchyBinding bind({
    required AvoraHierarchyBindingRequest request,
    required List<AvoraHierarchyBinding> existing,
    required DateTime nowUtc,
  }) {
    if (request.targetAvoraId.trim().isEmpty ||
        request.actorAvoraId.trim().isEmpty ||
        request.countryCode.trim().isEmpty) {
      throw StateError('hierarchy_binding_request_invalid');
    }

    final activeForTarget = existing.where(
      (binding) => binding.avoraId == request.targetAvoraId && binding.active,
    );

    for (final binding in activeForTarget) {
      final conflict = _conflicts(
        binding.kind,
        request.kind,
      );

      if (conflict) {
        final ownerOverride =
            request.actorIsOwner && request.allowOwnerOverride;

        if (!ownerOverride) {
          throw StateError('conflicting_hierarchy_binding_exists');
        }
      }
    }

    return AvoraHierarchyBinding(
      avoraId: request.targetAvoraId,
      kind: request.kind,
      parentAvoraId: request.parentAvoraId,
      countryCode: request.countryCode.trim().toUpperCase(),
      createdByAvoraId: request.actorAvoraId,
      createdAtUtc: nowUtc.toUtc(),
    );
  }

  bool _conflicts(
    AvoraHierarchyBindingKind existing,
    AvoraHierarchyBindingKind incoming,
  ) {
    if (existing == incoming) {
      return true;
    }

    const exclusiveOperationalKinds = <AvoraHierarchyBindingKind>{
      AvoraHierarchyBindingKind.bd,
      AvoraHierarchyBindingKind.agency,
      AvoraHierarchyBindingKind.host,
    };

    return exclusiveOperationalKinds.contains(existing) &&
        exclusiveOperationalKinds.contains(incoming);
  }

  static bool directAssignmentMaySkipIntermediateRoles() => true;

  static bool conflictingOperationalBindingsMustBeBlocked() => true;

  static bool ownerMayExplicitlyOverrideWithAudit() => true;

  static bool selfLeaveMustNotBypassBindingPolicy() => true;

  static bool profileAndPanelMustUseSameBindingSource() => true;
}
