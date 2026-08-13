import 'avora_authenticated_identity.dart';

/// Authoritative membership source used before message persistence access.
///
/// Implementations may later read Firestore/server membership records.
/// Client-provided membership must never become authoritative.
abstract class AvoraMessageAuthorizationRepository {
  Future<bool> isRoomMember({
    required String roomId,
    required String avoraId,
  });

  Future<bool> isInboxParticipant({
    required String conversationId,
    required String avoraId,
  });
}

class AvoraMessageAccessDecision {
  const AvoraMessageAccessDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraMessageAccessService {
  const AvoraMessageAccessService({
    required AvoraAuthenticatedIdentityResolver identityResolver,
    required AvoraMessageAuthorizationRepository repository,
  })  : _identityResolver = identityResolver,
        _repository = repository;

  final AvoraAuthenticatedIdentityResolver _identityResolver;
  final AvoraMessageAuthorizationRepository _repository;

  Future<AvoraMessageAccessDecision> authorizeRoom({
    required String firebaseUid,
    required String roomId,
  }) async {
    final identity = await _identityResolver.resolve(
      firebaseUid: firebaseUid,
    );

    if (identity == null || !identity.isUsable) {
      return const AvoraMessageAccessDecision(
        allowed: false,
        reason: 'identity_binding_required',
      );
    }

    final member = await _repository.isRoomMember(
      roomId: roomId,
      avoraId: identity.avoraId,
    );

    return AvoraMessageAccessDecision(
      allowed: member,
      reason: member ? 'room_member' : 'room_membership_required',
    );
  }

  Future<AvoraMessageAccessDecision> authorizeInbox({
    required String firebaseUid,
    required String conversationId,
  }) async {
    final identity = await _identityResolver.resolve(
      firebaseUid: firebaseUid,
    );

    if (identity == null || !identity.isUsable) {
      return const AvoraMessageAccessDecision(
        allowed: false,
        reason: 'identity_binding_required',
      );
    }

    final participant = await _repository.isInboxParticipant(
      conversationId: conversationId,
      avoraId: identity.avoraId,
    );

    return AvoraMessageAccessDecision(
      allowed: participant,
      reason:
          participant ? 'inbox_participant' : 'inbox_participation_required',
    );
  }

  static bool membershipMustBeAuthoritative() => true;

  static bool clientClaimsMustNeverGrantAccess() => true;

  static bool ownerOverrideMustBeExplicitAndAudited() => true;
}
