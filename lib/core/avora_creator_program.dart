enum AvoraCreatorProgramType {
  creator,
  celebrity,
  publicFigure,
  officialPartner,
}

enum AvoraCreatorStatus {
  pending,
  approved,
  suspended,
  expired,
  revoked,
  rejected,
}

enum AvoraCreatorBenefit {
  verifiedBadge,
  profileFrame,
  liveFrame,
  entryEffect,
  featuredLive,
  discoveryBoost,
  fanClub,
  creatorAnalytics,
  specialGiftCollection,
  eventPriority,
}

class AvoraCreatorScope {
  /// Null means globally valid program assignment.
  final String? countryCode;

  /// Optional campaign/event scope.
  final String? eventId;

  const AvoraCreatorScope({
    this.countryCode,
    this.eventId,
  });
}

class AvoraCreatorAssignment {
  final String id;

  final String userId;

  final AvoraCreatorProgramType programType;

  final AvoraCreatorStatus status;

  final AvoraCreatorScope scope;

  final List<AvoraCreatorBenefit> benefits;

  final DateTime startsAt;

  final DateTime? expiresAt;

  /// Staff/system actor that approved the assignment.
  final String approvedByUserId;

  final DateTime approvedAt;

  final String? verificationReference;

  final String? revokeReason;

  final String? revokedByUserId;

  final DateTime? revokedAt;

  const AvoraCreatorAssignment({
    required this.id,
    required this.userId,
    required this.programType,
    required this.status,
    required this.scope,
    required this.benefits,
    required this.startsAt,
    required this.approvedByUserId,
    required this.approvedAt,
    this.expiresAt,
    this.verificationReference,
    this.revokeReason,
    this.revokedByUserId,
    this.revokedAt,
  });

  bool isActiveAt(DateTime time) {
    if (status != AvoraCreatorStatus.approved) {
      return false;
    }

    if (time.isBefore(startsAt)) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && time.isAfter(expiry)) {
      return false;
    }

    return true;
  }

  bool hasBenefit({
    required AvoraCreatorBenefit benefit,
    required DateTime at,
  }) {
    return isActiveAt(at) && benefits.contains(benefit);
  }

  AvoraCreatorAssignment revoke({
    required String revokedByUserId,
    required DateTime revokedAt,
    required String reason,
  }) {
    return AvoraCreatorAssignment(
      id: id,
      userId: userId,
      programType: programType,
      status: AvoraCreatorStatus.revoked,
      scope: scope,
      benefits: benefits,
      startsAt: startsAt,
      expiresAt: expiresAt,
      approvedByUserId: approvedByUserId,
      approvedAt: approvedAt,
      verificationReference: verificationReference,
      revokeReason: reason,
      revokedByUserId: revokedByUserId,
      revokedAt: revokedAt,
    );
  }
}

class AvoraCreatorProgramPolicy {
  const AvoraCreatorProgramPolicy._();

  /// Ordinary identity verification alone must not
  /// automatically create Celebrity/Creator status.
  static bool canShowPublicBadge({
    required bool identityVerified,
    required bool creatorAuthenticityVerified,
    required AvoraCreatorAssignment assignment,
    required DateTime at,
  }) {
    return identityVerified &&
        creatorAuthenticityVerified &&
        assignment.isActiveAt(at) &&
        assignment.hasBenefit(
          benefit: AvoraCreatorBenefit.verifiedBadge,
          at: at,
        );
  }

  /// Creator/Celebrity benefits never bypass moderation.
  static bool bypassesSafetyModeration(
    AvoraCreatorAssignment assignment,
  ) {
    return false;
  }
}
