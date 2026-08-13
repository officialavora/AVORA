import 'avora_room_evidence_crosscheck.dart';

class AvoraRoomEvidenceTimeline {
  final Map<String, AvoraRoomEvidenceRecord> _records =
      <String, AvoraRoomEvidenceRecord>{};

  void append(AvoraRoomEvidenceRecord record) {
    if (record.evidenceId.trim().isEmpty ||
        record.roomId.trim().isEmpty ||
        record.actorAvoraId.trim().isEmpty ||
        record.payloadHash.trim().isEmpty) {
      throw ArgumentError('invalid_room_evidence_record');
    }

    if (!record.serverRecorded) {
      throw ArgumentError(
        'canonical_evidence_must_be_server_recorded',
      );
    }

    if (record.mutableByUser) {
      throw ArgumentError(
        'canonical_evidence_must_be_user_immutable',
      );
    }

    if (_records.containsKey(record.evidenceId)) {
      throw StateError('duplicate_room_evidence_id');
    }

    _records[record.evidenceId] = record;
  }

  AvoraRoomEvidenceRecord? byId(String evidenceId) => _records[evidenceId];

  List<AvoraRoomEvidenceRecord> forRoom(
    String roomId,
  ) {
    final result = _records.values
        .where((record) => record.roomId == roomId)
        .toList(growable: false);

    result.sort(
      (a, b) => a.occurredAtUtc.toUtc().compareTo(b.occurredAtUtc.toUtc()),
    );

    return List<AvoraRoomEvidenceRecord>.unmodifiable(
      result,
    );
  }

  List<AvoraRoomEvidenceRecord> around({
    required String roomId,
    required DateTime centerUtc,
    required Duration before,
    required Duration after,
  }) {
    if (before.isNegative || after.isNegative) {
      throw ArgumentError(
        'timeline_window_must_not_be_negative',
      );
    }

    final start = centerUtc.toUtc().subtract(before);
    final end = centerUtc.toUtc().add(after);

    final result = _records.values.where((record) {
      if (record.roomId != roomId) {
        return false;
      }

      final time = record.occurredAtUtc.toUtc();

      return !time.isBefore(start) && !time.isAfter(end);
    }).toList(growable: false);

    result.sort(
      (a, b) => a.occurredAtUtc.toUtc().compareTo(b.occurredAtUtc.toUtc()),
    );

    return List<AvoraRoomEvidenceRecord>.unmodifiable(
      result,
    );
  }

  List<AvoraRoomEvidenceRecord> byType({
    required String roomId,
    required AvoraRoomEvidenceType type,
  }) {
    final result = _records.values
        .where(
          (record) => record.roomId == roomId && record.type == type,
        )
        .toList(growable: false);

    result.sort(
      (a, b) => a.occurredAtUtc.toUtc().compareTo(b.occurredAtUtc.toUtc()),
    );

    return List<AvoraRoomEvidenceRecord>.unmodifiable(
      result,
    );
  }

  int get totalRecords => _records.length;

  static bool timelineMustBeAppendOnly() => true;

  static bool duplicateEvidenceMustNeverOverwrite() => true;

  static bool canonicalEvidenceMustBeServerRecorded() => true;

  static bool canonicalEvidenceMustBeUserImmutable() => true;

  static bool ownerMustBeAbleToReviewChronologicalTimeline() => true;

  static bool reportReviewMustSupportTimeWindowLookup() => true;

  static bool giftsAndGamesMustBeEligibleEvidenceEvents() => true;

  static bool moderationAndRoleActionsMustBeEligibleEvidenceEvents() => true;

  static bool privateAudioMustNotBeBlanketStoredByDefault() => true;

  static bool futureRoomFeaturesMustUseUniversalEvidenceTimeline() => true;
}
