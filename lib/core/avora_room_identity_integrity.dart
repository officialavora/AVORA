enum AvoraRoomIdentityIntegrityIssue {
  none,

  /// UI failed to render the immutable AVORA ID.
  missingRenderedAvoraId,

  /// Rendered immutable ID differs from server authority.
  renderedAvoraIdMismatch,

  /// Participant session is bound to the wrong user ID.
  invalidSessionBinding,

  /// Device/client integrity suggests deliberate tampering.
  suspectedClientTampering,
}

enum AvoraRoomIdentityIntegrityAction {
  allow,

  /// Re-fetch authoritative participant identity
  /// and force UI to render it again.
  forceIdentityRefresh,

  /// Temporarily limit risky room actions while identity
  /// integrity is being restored/reviewed.
  restrictAndReview,

  /// Authorized room staff may remove the participant.
  adminKickEligible,
}

class AvoraRoomParticipantIdentitySnapshot {
  final String participantSessionId;

  /// Immutable original AVORA ID from server.
  final String authoritativeAvoraId;

  /// AVORA ID rendered by the room UI.
  ///
  /// This is separate from vanity UID/display name.
  final String? renderedAvoraId;

  /// User ID bound to the authenticated room session.
  final String sessionBoundAvoraId;

  /// Result of client/device integrity checks.
  final bool clientIntegrityValid;

  final int priorIntegrityFailures;

  const AvoraRoomParticipantIdentitySnapshot({
    required this.participantSessionId,
    required this.authoritativeAvoraId,
    required this.renderedAvoraId,
    required this.sessionBoundAvoraId,
    required this.clientIntegrityValid,
    this.priorIntegrityFailures = 0,
  }) : assert(priorIntegrityFailures >= 0);
}

class AvoraRoomIdentityIntegrityDecision {
  final AvoraRoomIdentityIntegrityIssue issue;

  final AvoraRoomIdentityIntegrityAction action;

  /// Admin actions always target this server-authoritative ID,
  /// never a rendered label or vanity UID.
  final String authoritativeTargetAvoraId;

  final String participantSessionId;

  final bool adminCanModerate;

  final bool requiresHumanReview;

  const AvoraRoomIdentityIntegrityDecision({
    required this.issue,
    required this.action,
    required this.authoritativeTargetAvoraId,
    required this.participantSessionId,
    required this.adminCanModerate,
    this.requiresHumanReview = false,
  });
}

class AvoraRoomIdentityIntegrityEngine {
  const AvoraRoomIdentityIntegrityEngine._();

  static AvoraRoomIdentityIntegrityDecision evaluate({
    required AvoraRoomParticipantIdentitySnapshot participant,
  }) {
    final authoritative = participant.authoritativeAvoraId.trim();

    final rendered = participant.renderedAvoraId?.trim();

    final sessionBound = participant.sessionBoundAvoraId.trim();

    AvoraRoomIdentityIntegrityDecision decision({
      required AvoraRoomIdentityIntegrityIssue issue,
      required AvoraRoomIdentityIntegrityAction action,
      bool review = false,
    }) {
      return AvoraRoomIdentityIntegrityDecision(
        issue: issue,
        action: action,
        authoritativeTargetAvoraId: authoritative,
        participantSessionId: participant.participantSessionId,
        adminCanModerate: authoritative.isNotEmpty,
        requiresHumanReview: review,
      );
    }

    if (sessionBound != authoritative) {
      return decision(
        issue: AvoraRoomIdentityIntegrityIssue.invalidSessionBinding,
        action: AvoraRoomIdentityIntegrityAction.adminKickEligible,
        review: true,
      );
    }

    if (!participant.clientIntegrityValid) {
      return decision(
        issue: AvoraRoomIdentityIntegrityIssue.suspectedClientTampering,
        action: AvoraRoomIdentityIntegrityAction.restrictAndReview,
        review: true,
      );
    }

    if (rendered == null || rendered.isEmpty) {
      if (participant.priorIntegrityFailures >= 2) {
        return decision(
          issue: AvoraRoomIdentityIntegrityIssue.missingRenderedAvoraId,
          action: AvoraRoomIdentityIntegrityAction.adminKickEligible,
          review: true,
        );
      }

      return decision(
        issue: AvoraRoomIdentityIntegrityIssue.missingRenderedAvoraId,
        action: AvoraRoomIdentityIntegrityAction.forceIdentityRefresh,
      );
    }

    if (rendered != authoritative) {
      if (participant.priorIntegrityFailures >= 1) {
        return decision(
          issue: AvoraRoomIdentityIntegrityIssue.renderedAvoraIdMismatch,
          action: AvoraRoomIdentityIntegrityAction.restrictAndReview,
          review: true,
        );
      }

      return decision(
        issue: AvoraRoomIdentityIntegrityIssue.renderedAvoraIdMismatch,
        action: AvoraRoomIdentityIntegrityAction.forceIdentityRefresh,
      );
    }

    return decision(
      issue: AvoraRoomIdentityIntegrityIssue.none,
      action: AvoraRoomIdentityIntegrityAction.allow,
    );
  }
}
