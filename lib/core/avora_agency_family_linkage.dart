enum AvoraCommunityEntityKind {
  agency,
  family,
}

enum AvoraCommunityAdminKind {
  agencyAdmin,
  familyAdmin,
}

enum AvoraCommunityRemovalTargetKind {
  regularMember,
  protectedMember,
  host,
}

enum AvoraAgencyFamilyDenyReason {
  none,
  invalidActivation,
  agencyNotApprovedOrActive,
  invalidFamilyId,
  conflictingExistingLink,
}

enum AvoraCommunityRemovalDenyReason {
  none,
  invalidRequest,
  inactiveAdminAssignment,
  wrongAdminScope,
  agencyAdminCannotRemoveHost,
  familyAdminCannotRemoveProtectedTarget,
  insufficientAuthority,
}

class AvoraAgencyActivationFact {
  const AvoraAgencyActivationFact({
    required this.agencyId,
    required this.ownerAvoraId,
    required this.countryCode,
    required this.approved,
    required this.active,
    required this.activatedAtUtc,
    required this.policyVersion,
  });

  final String agencyId;
  final String ownerAvoraId;
  final String countryCode;

  final bool approved;
  final bool active;

  final DateTime activatedAtUtc;
  final String policyVersion;

  bool get valid =>
      agencyId.trim().isNotEmpty &&
      ownerAvoraId.trim().isNotEmpty &&
      countryCode.trim().isNotEmpty &&
      activatedAtUtc.isUtc &&
      policyVersion.trim().isNotEmpty;
}

class AvoraAgencyFamilyLink {
  const AvoraAgencyFamilyLink({
    required this.agencyId,
    required this.familyId,
    required this.ownerAvoraId,
    required this.countryCode,
    required this.createdAtUtc,
    required this.policyVersion,
    required this.idempotencyKey,
  });

  final String agencyId;
  final String familyId;

  /// Same authoritative AVORA ID owns both at initial provisioning.
  final String ownerAvoraId;

  final String countryCode;
  final DateTime createdAtUtc;
  final String policyVersion;

  /// Stable across retries. It is intentionally not tied to policy version.
  final String idempotencyKey;

  bool get valid =>
      agencyId.trim().isNotEmpty &&
      familyId.trim().isNotEmpty &&
      ownerAvoraId.trim().isNotEmpty &&
      countryCode.trim().isNotEmpty &&
      createdAtUtc.isUtc &&
      policyVersion.trim().isNotEmpty &&
      idempotencyKey.trim().isNotEmpty;
}

class AvoraAgencyFamilyProvisionPlan {
  const AvoraAgencyFamilyProvisionPlan({
    required this.allowed,
    required this.reason,
    required this.createFamilyRequired,
    required this.existingLinkReused,
    this.link,
  });

  final bool allowed;
  final AvoraAgencyFamilyDenyReason reason;

  /// Backend should create the Family only when true.
  final bool createFamilyRequired;

  /// True when an activation retry finds the already-created valid link.
  final bool existingLinkReused;

  final AvoraAgencyFamilyLink? link;
}

class AvoraAgencyFamilyProvisionEngine {
  const AvoraAgencyFamilyProvisionEngine._();

  static AvoraAgencyFamilyProvisionPlan planForActivatedAgency({
    required AvoraAgencyActivationFact activation,
    required String generatedFamilyId,
    required DateTime serverNowUtc,
    AvoraAgencyFamilyLink? existingLink,
  }) {
    if (!activation.valid || !serverNowUtc.isUtc) {
      return const AvoraAgencyFamilyProvisionPlan(
        allowed: false,
        reason: AvoraAgencyFamilyDenyReason.invalidActivation,
        createFamilyRequired: false,
        existingLinkReused: false,
      );
    }

    if (!activation.approved || !activation.active) {
      return const AvoraAgencyFamilyProvisionPlan(
        allowed: false,
        reason: AvoraAgencyFamilyDenyReason.agencyNotApprovedOrActive,
        createFamilyRequired: false,
        existingLinkReused: false,
      );
    }

    if (existingLink != null) {
      final sameAuthoritativeLink = existingLink.valid &&
          existingLink.agencyId == activation.agencyId &&
          existingLink.ownerAvoraId == activation.ownerAvoraId &&
          existingLink.countryCode.toUpperCase() ==
              activation.countryCode.toUpperCase();

      if (!sameAuthoritativeLink) {
        return const AvoraAgencyFamilyProvisionPlan(
          allowed: false,
          reason: AvoraAgencyFamilyDenyReason.conflictingExistingLink,
          createFamilyRequired: false,
          existingLinkReused: false,
        );
      }

      return AvoraAgencyFamilyProvisionPlan(
        allowed: true,
        reason: AvoraAgencyFamilyDenyReason.none,
        createFamilyRequired: false,
        existingLinkReused: true,
        link: existingLink,
      );
    }

    if (generatedFamilyId.trim().isEmpty) {
      return const AvoraAgencyFamilyProvisionPlan(
        allowed: false,
        reason: AvoraAgencyFamilyDenyReason.invalidFamilyId,
        createFamilyRequired: false,
        existingLinkReused: false,
      );
    }

    final link = AvoraAgencyFamilyLink(
      agencyId: activation.agencyId.trim(),
      familyId: generatedFamilyId.trim(),
      ownerAvoraId: activation.ownerAvoraId.trim(),
      countryCode: activation.countryCode.trim().toUpperCase(),
      createdAtUtc: serverNowUtc,
      policyVersion: activation.policyVersion.trim(),
      idempotencyKey: 'agency-family:auto:${activation.agencyId.trim()}',
    );

    return AvoraAgencyFamilyProvisionPlan(
      allowed: true,
      reason: AvoraAgencyFamilyDenyReason.none,
      createFamilyRequired: true,
      existingLinkReused: false,
      link: link,
    );
  }

  static bool familyAutoCreationIsServerAuthoritative() => true;

  static bool clientCanDirectlyCreateLinkedFamily() => false;

  static bool familyCreationMustBeIdempotent() => true;

  static bool agencyAndFamilyRemainSeparateEntities() => true;

  static bool retryCanCreateDuplicateFamily() => false;
}

class AvoraCommunityAdminAssignment {
  const AvoraCommunityAdminAssignment({
    required this.assignmentId,
    required this.kind,
    required this.actorAvoraId,
    required this.entityKind,
    required this.entityId,
    required this.grantedByAvoraId,
    required this.policyVersion,
    required this.startsAtUtc,
    this.endsAtUtc,
  });

  final String assignmentId;
  final AvoraCommunityAdminKind kind;
  final String actorAvoraId;

  /// Agency Admin and Family Admin are scope-bound capabilities.
  final AvoraCommunityEntityKind entityKind;
  final String entityId;

  final String grantedByAvoraId;
  final String policyVersion;

  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;

  bool isActiveAt(DateTime serverNowUtc) {
    if (!serverNowUtc.isUtc ||
        !startsAtUtc.isUtc ||
        serverNowUtc.isBefore(startsAtUtc)) {
      return false;
    }

    final end = endsAtUtc;
    if (end != null) {
      if (!end.isUtc || !serverNowUtc.isBefore(end)) {
        return false;
      }
    }

    return true;
  }

  bool get scopeMatchesKind {
    switch (kind) {
      case AvoraCommunityAdminKind.agencyAdmin:
        return entityKind == AvoraCommunityEntityKind.agency;
      case AvoraCommunityAdminKind.familyAdmin:
        return entityKind == AvoraCommunityEntityKind.family;
    }
  }
}

class AvoraCommunityRemovalRequest {
  const AvoraCommunityRemovalRequest({
    required this.entityKind,
    required this.entityId,
    required this.targetAvoraId,
    required this.targetKind,
    required this.reasonText,
    required this.policyPowerSnapshot,
    required this.idempotencyKey,
    required this.requestedAtUtc,
  });

  final AvoraCommunityEntityKind entityKind;
  final String entityId;

  final String targetAvoraId;
  final AvoraCommunityRemovalTargetKind targetKind;

  final String reasonText;

  /// Immutable permission/power snapshot used for this decision.
  final String policyPowerSnapshot;

  final String idempotencyKey;
  final DateTime requestedAtUtc;

  bool get valid =>
      entityId.trim().isNotEmpty &&
      targetAvoraId.trim().isNotEmpty &&
      reasonText.trim().isNotEmpty &&
      policyPowerSnapshot.trim().isNotEmpty &&
      idempotencyKey.trim().isNotEmpty &&
      requestedAtUtc.isUtc;
}

class AvoraCommunityRemovalAuthority {
  const AvoraCommunityRemovalAuthority({
    required this.actorAvoraId,
    required this.isEntityOwner,
    required this.hasExplicitHigherRemovalPower,
    this.adminAssignment,
  });

  final String actorAvoraId;

  /// Agency Owner / Family Owner.
  final bool isEntityOwner;

  /// Owner/Manager/etc. only when backend policy explicitly grants this
  /// protected removal power for the relevant scope.
  final bool hasExplicitHigherRemovalPower;

  final AvoraCommunityAdminAssignment? adminAssignment;
}

class AvoraCommunityRemovalAuditEvent {
  const AvoraCommunityRemovalAuditEvent({
    required this.auditId,
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.entityKind,
    required this.entityId,
    required this.targetKind,
    required this.allowed,
    required this.decisionReason,
    required this.reasonText,
    required this.policyPowerSnapshot,
    required this.occurredAtUtc,
    required this.idempotencyKey,
  });

  final String auditId;

  final String actorAvoraId;
  final String targetAvoraId;

  final AvoraCommunityEntityKind entityKind;
  final String entityId;
  final AvoraCommunityRemovalTargetKind targetKind;

  final bool allowed;
  final AvoraCommunityRemovalDenyReason decisionReason;

  final String reasonText;
  final String policyPowerSnapshot;

  final DateTime occurredAtUtc;
  final String idempotencyKey;
}

class AvoraCommunityRemovalDecision {
  const AvoraCommunityRemovalDecision({
    required this.allowed,
    required this.reason,
    required this.auditEvent,
  });

  final bool allowed;
  final AvoraCommunityRemovalDenyReason reason;
  final AvoraCommunityRemovalAuditEvent auditEvent;
}

class AvoraCommunityRemovalGuard {
  const AvoraCommunityRemovalGuard._();

  static AvoraCommunityRemovalDecision evaluate({
    required AvoraCommunityRemovalAuthority authority,
    required AvoraCommunityRemovalRequest request,
    required DateTime serverNowUtc,
  }) {
    AvoraCommunityRemovalDecision build(
      bool allowed,
      AvoraCommunityRemovalDenyReason reason,
    ) {
      return AvoraCommunityRemovalDecision(
        allowed: allowed,
        reason: reason,
        auditEvent: AvoraCommunityRemovalAuditEvent(
          auditId: 'community-removal:${request.idempotencyKey}',
          actorAvoraId: authority.actorAvoraId.trim(),
          targetAvoraId: request.targetAvoraId.trim(),
          entityKind: request.entityKind,
          entityId: request.entityId.trim(),
          targetKind: request.targetKind,
          allowed: allowed,
          decisionReason: reason,
          reasonText: request.reasonText.trim(),
          policyPowerSnapshot: request.policyPowerSnapshot.trim(),
          occurredAtUtc: serverNowUtc,
          idempotencyKey: request.idempotencyKey.trim(),
        ),
      );
    }

    if (!request.valid ||
        !serverNowUtc.isUtc ||
        authority.actorAvoraId.trim().isEmpty) {
      return build(
        false,
        AvoraCommunityRemovalDenyReason.invalidRequest,
      );
    }

    /// Entity Owner or explicitly higher scoped power may perform protected
    /// removal. Title alone is never enough.
    if (authority.isEntityOwner || authority.hasExplicitHigherRemovalPower) {
      return build(
        true,
        AvoraCommunityRemovalDenyReason.none,
      );
    }

    final assignment = authority.adminAssignment;

    if (assignment == null ||
        !assignment.scopeMatchesKind ||
        !assignment.isActiveAt(serverNowUtc)) {
      return build(
        false,
        assignment == null || !assignment.isActiveAt(serverNowUtc)
            ? AvoraCommunityRemovalDenyReason.inactiveAdminAssignment
            : AvoraCommunityRemovalDenyReason.wrongAdminScope,
      );
    }

    if (assignment.actorAvoraId != authority.actorAvoraId ||
        assignment.entityKind != request.entityKind ||
        assignment.entityId != request.entityId) {
      return build(
        false,
        AvoraCommunityRemovalDenyReason.wrongAdminScope,
      );
    }

    if (assignment.kind == AvoraCommunityAdminKind.agencyAdmin &&
        request.targetKind == AvoraCommunityRemovalTargetKind.host) {
      return build(
        false,
        AvoraCommunityRemovalDenyReason.agencyAdminCannotRemoveHost,
      );
    }

    if (assignment.kind == AvoraCommunityAdminKind.familyAdmin &&
        (request.targetKind == AvoraCommunityRemovalTargetKind.host ||
            request.targetKind ==
                AvoraCommunityRemovalTargetKind.protectedMember)) {
      return build(
        false,
        AvoraCommunityRemovalDenyReason.familyAdminCannotRemoveProtectedTarget,
      );
    }

    /// Scoped Admin may handle routine, non-protected membership operations.
    return build(
      true,
      AvoraCommunityRemovalDenyReason.none,
    );
  }

  static bool agencyAdminCanRemoveHost() => false;

  static bool familyAdminCanRemoveProtectedMemberOrHost() => false;

  static bool adminTitleAloneGrantsRemovalAuthority() => false;

  static bool protectedRemovalRequiresOwnerOrExplicitHigherPower() => true;

  static bool everyRemovalDecisionRequiresAudit() => true;

  static bool clientCanMutateMembershipDirectly() => false;

  static bool backendRemainsAuthoritative() => true;
}
