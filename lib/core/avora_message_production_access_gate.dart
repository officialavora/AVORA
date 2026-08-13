import 'avora_authenticated_identity.dart';
import 'avora_message_authorization_repository.dart';
import 'avora_owner_message_override.dart';

enum AvoraMessageAccessTarget {
  room,
  inbox,
}

class AvoraMessageProductionAccessRequest {
  const AvoraMessageProductionAccessRequest({
    required this.firebaseUid,
    required this.targetType,
    required this.targetId,
    required this.ownerOverrideRequested,
  });

  final String firebaseUid;
  final AvoraMessageAccessTarget targetType;
  final String targetId;
  final bool ownerOverrideRequested;
}

class AvoraMessageProductionAccessResult {
  const AvoraMessageProductionAccessResult({
    required this.allowed,
    required this.reason,
    required this.ownerOverrideUsed,
    required this.auditRequired,
  });

  final bool allowed;
  final String reason;
  final bool ownerOverrideUsed;
  final bool auditRequired;
}

class AvoraMessageProductionAccessGate {
  const AvoraMessageProductionAccessGate({
    required AvoraAuthenticatedIdentityResolver identityResolver,
    required AvoraMessageAuthorizationRepository authorizationRepository,
    required AvoraOwnerMessageOverrideService ownerOverrideService,
  })  : _identityResolver = identityResolver,
        _authorizationRepository = authorizationRepository,
        _ownerOverrideService = ownerOverrideService;

  final AvoraAuthenticatedIdentityResolver _identityResolver;
  final AvoraMessageAuthorizationRepository _authorizationRepository;
  final AvoraOwnerMessageOverrideService _ownerOverrideService;

  Future<AvoraMessageProductionAccessResult> authorize(
    AvoraMessageProductionAccessRequest request,
  ) async {
    final identity = await _identityResolver.resolve(
      firebaseUid: request.firebaseUid,
    );

    if (identity == null || !identity.isUsable) {
      return const AvoraMessageProductionAccessResult(
        allowed: false,
        reason: 'identity_binding_required',
        ownerOverrideUsed: false,
        auditRequired: false,
      );
    }

    final normalAccess = switch (request.targetType) {
      AvoraMessageAccessTarget.room =>
        await _authorizationRepository.isRoomMember(
          roomId: request.targetId,
          avoraId: identity.avoraId,
        ),
      AvoraMessageAccessTarget.inbox =>
        await _authorizationRepository.isInboxParticipant(
          conversationId: request.targetId,
          avoraId: identity.avoraId,
        ),
    };

    if (normalAccess) {
      return const AvoraMessageProductionAccessResult(
        allowed: true,
        reason: 'authorized_member',
        ownerOverrideUsed: false,
        auditRequired: false,
      );
    }

    if (!request.ownerOverrideRequested) {
      return const AvoraMessageProductionAccessResult(
        allowed: false,
        reason: 'membership_required',
        ownerOverrideUsed: false,
        auditRequired: false,
      );
    }

    final override = await _ownerOverrideService.authorize(
      AvoraOwnerOverrideRequest(
        actorAvoraId: identity.avoraId,
        targetId: request.targetId,
        action: request.targetType == AvoraMessageAccessTarget.room
            ? AvoraOwnerOverrideAction.readRoom
            : AvoraOwnerOverrideAction.readInbox,
        reason: 'owner production access',
        createdAtUtc: DateTime.now().toUtc(),
      ),
    );

    return AvoraMessageProductionAccessResult(
      allowed: override.allowed,
      reason: override.reason,
      ownerOverrideUsed: override.allowed,
      auditRequired: override.auditRequired,
    );
  }

  static bool normalUsersRequireMembership() => true;

  static bool ownerOverrideMustBeExplicit() => true;

  static bool ownerOverrideMustRequireAudit() => true;

  static bool missingIdentityMustFailClosed() => true;
}
