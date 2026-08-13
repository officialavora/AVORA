import 'avora_owner_room_inspection.dart';

enum AvoraOwnerInspectionSessionStatus {
  active,
  completed,
}

class AvoraOwnerInspectionSession {
  const AvoraOwnerInspectionSession({
    required this.sessionId,
    required this.ownerAvoraId,
    required this.roomId,
    required this.countryScope,
    required this.reason,
    required this.startedAtUtc,
    required this.status,
    this.completedAtUtc,
  });

  final String sessionId;
  final String ownerAvoraId;
  final String roomId;
  final String countryScope;
  final AvoraOwnerInspectionReason reason;
  final DateTime startedAtUtc;
  final AvoraOwnerInspectionSessionStatus status;
  final DateTime? completedAtUtc;

  AvoraOwnerInspectionSession complete({
    required DateTime completedAtUtc,
  }) {
    if (status == AvoraOwnerInspectionSessionStatus.completed) {
      throw StateError('inspection_already_completed');
    }

    final completed = completedAtUtc.toUtc();

    if (completed.isBefore(startedAtUtc.toUtc())) {
      throw ArgumentError(
        'inspection_completion_before_start',
      );
    }

    return AvoraOwnerInspectionSession(
      sessionId: sessionId,
      ownerAvoraId: ownerAvoraId,
      roomId: roomId,
      countryScope: countryScope,
      reason: reason,
      startedAtUtc: startedAtUtc.toUtc(),
      status: AvoraOwnerInspectionSessionStatus.completed,
      completedAtUtc: completed,
    );
  }
}

class AvoraOwnerInspectionAuditLedger {
  final Map<String, AvoraOwnerInspectionSession> _sessions =
      <String, AvoraOwnerInspectionSession>{};

  AvoraOwnerInspectionSession start({
    required String sessionId,
    required AvoraOwnerRoomInspectionRequest request,
    required String countryScope,
  }) {
    final decision = AvoraOwnerRoomInspectionPolicy.evaluate(
      request,
    );

    if (!decision.allowed) {
      throw StateError('owner_inspection_not_authorized');
    }

    if (sessionId.trim().isEmpty || countryScope.trim().isEmpty) {
      throw ArgumentError(
        'inspection_session_metadata_required',
      );
    }

    if (_sessions.containsKey(sessionId)) {
      throw StateError('duplicate_inspection_session');
    }

    final session = AvoraOwnerInspectionSession(
      sessionId: sessionId,
      ownerAvoraId: request.ownerAvoraId,
      roomId: request.roomId,
      countryScope: countryScope,
      reason: request.reason,
      startedAtUtc: request.createdAtUtc.toUtc(),
      status: AvoraOwnerInspectionSessionStatus.active,
    );

    _sessions[sessionId] = session;
    return session;
  }

  AvoraOwnerInspectionSession complete({
    required String sessionId,
    required DateTime completedAtUtc,
  }) {
    final current = _sessions[sessionId];

    if (current == null) {
      throw StateError('inspection_session_not_found');
    }

    final completed = current.complete(
      completedAtUtc: completedAtUtc,
    );

    _sessions[sessionId] = completed;
    return completed;
  }

  AvoraOwnerInspectionSession? byId(
    String sessionId,
  ) =>
      _sessions[sessionId];

  List<AvoraOwnerInspectionSession> get allForOwner =>
      List<AvoraOwnerInspectionSession>.unmodifiable(
        _sessions.values,
      );

  List<AvoraOwnerInspectionSession> byRoom(
    String roomId,
  ) {
    return List<AvoraOwnerInspectionSession>.unmodifiable(
      _sessions.values.where(
        (session) => session.roomId == roomId,
      ),
    );
  }

  List<AvoraOwnerInspectionSession> byCountry(
    String countryScope,
  ) {
    return List<AvoraOwnerInspectionSession>.unmodifiable(
      _sessions.values.where(
        (session) => session.countryScope == countryScope,
      ),
    );
  }

  static bool everyInspectionMustCreateSessionAudit() => true;

  static bool inspectionHistoryMustRemainAvailableToOwner() => true;

  static bool roomAndCountryScopeMustBeRecorded() => true;

  static bool inspectionStartAndEndMustBeRecorded() => true;

  static bool auditEvidenceMustNotBeSilentlyDeleted() => true;

  static bool plaintextPasswordMustNeverEnterAudit() => true;

  static bool futureInspectionTypesMustUseSameLedger() => true;
}

class AvoraOwnerInspectionScopeGuard {
  const AvoraOwnerInspectionScopeGuard._();

  static bool mayUseInspectionMode({
    required bool actorIsVerifiedOwner,
    required String actorRole,
  }) {
    if (!actorIsVerifiedOwner) {
      return false;
    }

    return actorRole.trim().toLowerCase() == 'owner';
  }

  static bool mayDelegateInspectionMode({
    required String targetRole,
  }) {
    // Intentionally non-delegable.
    return false;
  }

  static bool ownerInspectionIsGlobalAcrossCountries() => true;

  static bool managerCannotInheritOwnerInspection() => true;

  static bool superAdminCannotInheritOwnerInspection() => true;

  static bool adminCannotInheritOwnerInspection() => true;

  static bool bdCannotInheritOwnerInspection() => true;

  static bool merchantCannotInheritOwnerInspection() => true;

  static bool sellerCannotInheritOwnerInspection() => true;

  static bool agencyCannotInheritOwnerInspection() => true;

  static bool futureRolesCannotAutoInheritOwnerInspection() => true;
}
