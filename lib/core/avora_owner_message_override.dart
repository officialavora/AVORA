enum AvoraOwnerOverrideAction {
  readRoom,
  readInbox,
  sendRoom,
  sendInbox,
  removeMessage,
  restoreMessage,
  clearRoomHistory,
  blockUser,
  unblockUser,
  kickUser,
  unbanUser,
}

class AvoraOwnerOverrideRequest {
  const AvoraOwnerOverrideRequest({
    required this.actorAvoraId,
    required this.targetId,
    required this.action,
    required this.reason,
    required this.createdAtUtc,
  });

  final String actorAvoraId;
  final String targetId;
  final AvoraOwnerOverrideAction action;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraOwnerOverrideDecision {
  const AvoraOwnerOverrideDecision({
    required this.allowed,
    required this.auditRequired,
    required this.reason,
  });

  final bool allowed;
  final bool auditRequired;
  final String reason;
}

abstract class AvoraOwnerAuthorityRepository {
  Future<bool> isActiveOwner({
    required String avoraId,
  });
}

class AvoraOwnerMessageOverrideService {
  const AvoraOwnerMessageOverrideService({
    required AvoraOwnerAuthorityRepository repository,
  }) : _repository = repository;

  final AvoraOwnerAuthorityRepository _repository;

  Future<AvoraOwnerOverrideDecision> authorize(
    AvoraOwnerOverrideRequest request,
  ) async {
    if (request.actorAvoraId.trim().isEmpty ||
        request.targetId.trim().isEmpty ||
        request.reason.trim().isEmpty) {
      return const AvoraOwnerOverrideDecision(
        allowed: false,
        auditRequired: true,
        reason: 'invalid_override_request',
      );
    }

    final owner = await _repository.isActiveOwner(
      avoraId: request.actorAvoraId.trim(),
    );

    if (!owner) {
      return const AvoraOwnerOverrideDecision(
        allowed: false,
        auditRequired: true,
        reason: 'owner_authority_required',
      );
    }

    return const AvoraOwnerOverrideDecision(
      allowed: true,
      auditRequired: true,
      reason: 'owner_override_authorized',
    );
  }

  static bool ownerHasGlobalOperationalAuthority() => true;

  static bool ownerOverrideMustAlwaysBeAudited() => true;

  static bool ownerAuthorityMustBeServerVerified() => true;

  static bool nonOwnerMustNeverInheritOwnerOverride() => true;

  static bool ownerAuditMustNeverReduceOwnerAuthority() => true;
}
