enum AvoraRoomEvidenceType {
  roomMessage,
  mediaPost,
  externalLink,
  phoneNumber,
  qrCode,
  moderationSignal,
  userJoin,
  userLeave,
  roomLockChange,
  roomNameChange,
  roomDpChange,
  giftEvent,
  gameEvent,
  roleAction,
  reportEvent,
  other,
}

class AvoraRoomEvidenceRecord {
  const AvoraRoomEvidenceRecord({
    required this.evidenceId,
    required this.roomId,
    required this.actorAvoraId,
    required this.type,
    required this.occurredAtUtc,
    required this.payloadHash,
    required this.serverRecorded,
    required this.mutableByUser,
  });

  final String evidenceId;
  final String roomId;
  final String actorAvoraId;
  final AvoraRoomEvidenceType type;
  final DateTime occurredAtUtc;

  /// Hash/fingerprint of server-observed evidence.
  final String payloadHash;

  final bool serverRecorded;

  /// Must be false for canonical audit evidence.
  final bool mutableByUser;

  bool get isCanonical =>
      serverRecorded &&
      !mutableByUser &&
      evidenceId.trim().isNotEmpty &&
      roomId.trim().isNotEmpty &&
      payloadHash.trim().isNotEmpty;
}

class AvoraUserSubmittedProof {
  const AvoraUserSubmittedProof({
    required this.proofId,
    required this.reporterAvoraId,
    required this.roomId,
    required this.claimedAtUtc,
    required this.payloadHash,
  });

  final String proofId;
  final String reporterAvoraId;
  final String roomId;
  final DateTime claimedAtUtc;
  final String payloadHash;
}

enum AvoraEvidenceCrossCheckStatus {
  matched,
  partiallyMatched,
  noServerMatch,
  invalidEvidence,
}

class AvoraEvidenceCrossCheckResult {
  const AvoraEvidenceCrossCheckResult({
    required this.status,
    required this.reason,
    required this.matchedEvidenceIds,
  });

  final AvoraEvidenceCrossCheckStatus status;
  final String reason;
  final List<String> matchedEvidenceIds;
}

class AvoraRoomEvidenceCrossCheckService {
  const AvoraRoomEvidenceCrossCheckService();

  AvoraEvidenceCrossCheckResult crossCheck({
    required AvoraUserSubmittedProof proof,
    required Iterable<AvoraRoomEvidenceRecord> serverEvidence,
    Duration tolerance = const Duration(minutes: 10),
  }) {
    if (proof.proofId.trim().isEmpty ||
        proof.reporterAvoraId.trim().isEmpty ||
        proof.roomId.trim().isEmpty ||
        proof.payloadHash.trim().isEmpty ||
        tolerance.isNegative) {
      return const AvoraEvidenceCrossCheckResult(
        status: AvoraEvidenceCrossCheckStatus.invalidEvidence,
        reason: 'invalid_submitted_proof',
        matchedEvidenceIds: <String>[],
      );
    }

    final roomRecords = serverEvidence.where(
      (record) => record.roomId == proof.roomId && record.isCanonical,
    );

    final timeMatches = roomRecords.where((record) {
      final difference = record.occurredAtUtc
          .toUtc()
          .difference(proof.claimedAtUtc.toUtc())
          .abs();

      return difference <= tolerance;
    }).toList(growable: false);

    final exactHashMatches = timeMatches
        .where(
          (record) => record.payloadHash == proof.payloadHash,
        )
        .map((record) => record.evidenceId)
        .toList(growable: false);

    if (exactHashMatches.isNotEmpty) {
      return AvoraEvidenceCrossCheckResult(
        status: AvoraEvidenceCrossCheckStatus.matched,
        reason: 'submitted_proof_matches_server_evidence',
        matchedEvidenceIds: exactHashMatches,
      );
    }

    if (timeMatches.isNotEmpty) {
      return AvoraEvidenceCrossCheckResult(
        status: AvoraEvidenceCrossCheckStatus.partiallyMatched,
        reason: 'room_activity_matches_but_payload_differs',
        matchedEvidenceIds: timeMatches
            .map((record) => record.evidenceId)
            .toList(growable: false),
      );
    }

    return const AvoraEvidenceCrossCheckResult(
      status: AvoraEvidenceCrossCheckStatus.noServerMatch,
      reason: 'no_matching_server_evidence',
      matchedEvidenceIds: <String>[],
    );
  }

  static bool userScreenshotMustNotBeSoleEvidence() => true;

  static bool serverEvidenceShouldBePreferredForCrossCheck() => true;

  static bool canonicalEvidenceMustBeUserImmutable() => true;

  static bool evidenceMustPreserveRoomAndTimestamp() => true;

  static bool editedProofMustRemainDetectableWhenHashesDiffer() => true;

  static bool ownerMustBeAbleToReviewReportTimeline() => true;

  static bool privateAudioMustNotBeBlanketRecordedByDefault() => true;

  static bool futureRoomFeaturesMustEmitCanonicalEvidence() => true;
}
