import 'avora_backup_restore_contract.dart';
import 'avora_emergency_containment.dart';
import 'avora_incident_diagnostics.dart';

enum AvoraIncidentResponseAction {
  reportAccepted,
  investigationStarted,
  containmentApplied,
  recoveryStarted,
  restoreValidated,
  rollbackRequested,
  recoveryVerified,
  resolved,
  closed,
}

class AvoraIncidentResponseEvent {
  const AvoraIncidentResponseEvent({
    required this.eventId,
    required this.incidentId,
    required this.action,
    required this.actorId,
    required this.createdAtUtc,
    required this.details,
  });

  final String eventId;
  final String incidentId;
  final AvoraIncidentResponseAction action;
  final String actorId;
  final DateTime createdAtUtc;
  final String details;

  void validate() {
    if (eventId.trim().isEmpty ||
        incidentId.trim().isEmpty ||
        actorId.trim().isEmpty ||
        details.trim().isEmpty) {
      throw ArgumentError('invalid_incident_response_event');
    }
  }
}

class AvoraIncidentResponseLedger {
  final Map<String, AvoraIncidentResponseEvent> _events =
      <String, AvoraIncidentResponseEvent>{};

  void append(AvoraIncidentResponseEvent event) {
    event.validate();

    if (_events.containsKey(event.eventId)) {
      throw StateError('duplicate_incident_response_event');
    }

    _events[event.eventId] = event;
  }

  List<AvoraIncidentResponseEvent> forIncident(
    String incidentId,
  ) {
    final result = _events.values
        .where((event) => event.incidentId == incidentId)
        .toList(growable: false)
      ..sort(
        (a, b) => a.createdAtUtc.compareTo(b.createdAtUtc),
      );

    return List<AvoraIncidentResponseEvent>.unmodifiable(
      result,
    );
  }

  bool hasAction(
    String incidentId,
    AvoraIncidentResponseAction action,
  ) {
    return _events.values.any(
      (event) => event.incidentId == incidentId && event.action == action,
    );
  }

  static bool incidentEventsMustRemainImmutable() => true;

  static bool everyCriticalRecoveryActionMustBeTraceable() => true;
}

class AvoraIncidentRecoveryVerification {
  const AvoraIncidentRecoveryVerification({
    required this.verificationId,
    required this.incidentId,
    required this.financialStateVerified,
    required this.dataIntegrityVerified,
    required this.securityStateVerified,
    required this.featureHealthVerified,
    required this.verifiedBy,
    required this.verifiedAtUtc,
    required this.notes,
  });

  final String verificationId;
  final String incidentId;

  final bool financialStateVerified;
  final bool dataIntegrityVerified;
  final bool securityStateVerified;
  final bool featureHealthVerified;

  final String verifiedBy;
  final DateTime verifiedAtUtc;
  final String notes;

  bool get passed =>
      financialStateVerified &&
      dataIntegrityVerified &&
      securityStateVerified &&
      featureHealthVerified;

  void validate() {
    if (verificationId.trim().isEmpty ||
        incidentId.trim().isEmpty ||
        verifiedBy.trim().isEmpty ||
        notes.trim().isEmpty) {
      throw ArgumentError('invalid_recovery_verification');
    }
  }
}

class AvoraIncidentLifecycleRecord {
  const AvoraIncidentLifecycleRecord({
    required this.incidentId,
    required this.status,
    required this.severity,
    required this.updatedAtUtc,
    required this.updatedBy,
    required this.reason,
  });

  final String incidentId;
  final AvoraIncidentStatus status;
  final AvoraIncidentSeverity severity;
  final DateTime updatedAtUtc;
  final String updatedBy;
  final String reason;

  void validate() {
    if (incidentId.trim().isEmpty ||
        updatedBy.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_incident_lifecycle_record');
    }
  }
}

class AvoraIncidentLifecycleRegistry {
  final Map<String, AvoraIncidentLifecycleRecord> _active =
      <String, AvoraIncidentLifecycleRecord>{};

  AvoraIncidentLifecycleRecord? active(String incidentId) =>
      _active[incidentId];

  void createFromReport(
    AvoraOwnerIncidentReport report, {
    required String actorId,
  }) {
    report.validate();

    if (_active.containsKey(report.incidentId)) {
      throw StateError('incident_already_exists');
    }

    final record = AvoraIncidentLifecycleRecord(
      incidentId: report.incidentId,
      status: AvoraIncidentStatus.reported,
      severity: report.severity,
      updatedAtUtc: report.createdAtUtc.toUtc(),
      updatedBy: actorId,
      reason: 'incident_report_accepted',
    );

    record.validate();
    _active[report.incidentId] = record;
  }

  void transition({
    required String incidentId,
    required AvoraIncidentStatus nextStatus,
    required String actorId,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    final current = _active[incidentId];

    if (current == null) {
      throw StateError('incident_not_found');
    }

    if (!_transitionAllowed(
      current.status,
      nextStatus,
    )) {
      throw StateError(
        'invalid_incident_transition:${current.status.name}->${nextStatus.name}',
      );
    }

    final updated = AvoraIncidentLifecycleRecord(
      incidentId: incidentId,
      status: nextStatus,
      severity: current.severity,
      updatedAtUtc: changedAtUtc.toUtc(),
      updatedBy: actorId,
      reason: reason,
    );

    updated.validate();
    _active[incidentId] = updated;
  }

  bool _transitionAllowed(
    AvoraIncidentStatus current,
    AvoraIncidentStatus next,
  ) {
    switch (current) {
      case AvoraIncidentStatus.reported:
        return next == AvoraIncidentStatus.investigating;

      case AvoraIncidentStatus.investigating:
        return next == AvoraIncidentStatus.contained ||
            next == AvoraIncidentStatus.recovering;

      case AvoraIncidentStatus.contained:
        return next == AvoraIncidentStatus.recovering;

      case AvoraIncidentStatus.recovering:
        return next == AvoraIncidentStatus.resolved;

      case AvoraIncidentStatus.resolved:
        return next == AvoraIncidentStatus.closed;

      case AvoraIncidentStatus.closed:
        return false;
    }
  }

  static bool lifecycleMustPreventSkippingCriticalStages() => true;

  static bool closedIncidentMustNotReopenSilently() => true;
}

class AvoraIncidentResponseOrchestrator {
  AvoraIncidentResponseOrchestrator({
    required AvoraIncidentLifecycleRegistry lifecycleRegistry,
    required AvoraIncidentResponseLedger responseLedger,
  })  : _lifecycleRegistry = lifecycleRegistry,
        _responseLedger = responseLedger;

  final AvoraIncidentLifecycleRegistry _lifecycleRegistry;
  final AvoraIncidentResponseLedger _responseLedger;

  void acceptReport({
    required AvoraOwnerIncidentReport report,
    required String actorId,
    required String eventId,
  }) {
    _lifecycleRegistry.createFromReport(
      report,
      actorId: actorId,
    );

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: report.incidentId,
        action: AvoraIncidentResponseAction.reportAccepted,
        actorId: actorId,
        createdAtUtc: report.createdAtUtc.toUtc(),
        details: 'owner_incident_report_accepted',
      ),
    );
  }

  void startInvestigation({
    required String incidentId,
    required String actorId,
    required String eventId,
    required DateTime atUtc,
  }) {
    _lifecycleRegistry.transition(
      incidentId: incidentId,
      nextStatus: AvoraIncidentStatus.investigating,
      actorId: actorId,
      reason: 'investigation_started',
      changedAtUtc: atUtc,
    );

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.investigationStarted,
        actorId: actorId,
        createdAtUtc: atUtc.toUtc(),
        details: 'incident_investigation_started',
      ),
    );
  }

  void recordContainment({
    required String incidentId,
    required AvoraContainmentRule rule,
    required String actorId,
    required String eventId,
    required DateTime atUtc,
  }) {
    if (rule.incidentId != incidentId) {
      throw StateError('containment_incident_mismatch');
    }

    _lifecycleRegistry.transition(
      incidentId: incidentId,
      nextStatus: AvoraIncidentStatus.contained,
      actorId: actorId,
      reason: 'incident_containment_applied',
      changedAtUtc: atUtc,
    );

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.containmentApplied,
        actorId: actorId,
        createdAtUtc: atUtc.toUtc(),
        details: 'containment_rule:${rule.ruleId}',
      ),
    );
  }

  void startRecovery({
    required String incidentId,
    required String actorId,
    required String eventId,
    required DateTime atUtc,
  }) {
    final current = _lifecycleRegistry.active(incidentId);

    if (current == null) {
      throw StateError('incident_not_found');
    }

    if (current.severity == AvoraIncidentSeverity.critical &&
        !_responseLedger.hasAction(
          incidentId,
          AvoraIncidentResponseAction.containmentApplied,
        )) {
      throw StateError(
        'critical_incident_requires_containment_before_recovery',
      );
    }

    _lifecycleRegistry.transition(
      incidentId: incidentId,
      nextStatus: AvoraIncidentStatus.recovering,
      actorId: actorId,
      reason: 'incident_recovery_started',
      changedAtUtc: atUtc,
    );

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.recoveryStarted,
        actorId: actorId,
        createdAtUtc: atUtc.toUtc(),
        details: 'recovery_started',
      ),
    );
  }

  void recordRestoreValidation({
    required String incidentId,
    required AvoraRestoreRequest request,
    required AvoraBackupSnapshot backup,
    required String actorId,
    required String eventId,
    required DateTime atUtc,
  }) {
    if (request.incidentId != incidentId) {
      throw StateError('restore_incident_mismatch');
    }

    if (request.backupId != backup.backupId) {
      throw StateError('restore_backup_mismatch');
    }

    if (!backup.usableForRestore) {
      throw StateError('restore_backup_not_verified');
    }

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.restoreValidated,
        actorId: actorId,
        createdAtUtc: atUtc.toUtc(),
        details: 'verified_backup:${backup.backupId}:${backup.releaseId}',
      ),
    );
  }

  void recordRollbackRequest({
    required String incidentId,
    required AvoraRollbackRequest rollback,
    required String actorId,
    required String eventId,
  }) {
    rollback.validate();

    if (rollback.incidentId != incidentId) {
      throw StateError('rollback_incident_mismatch');
    }

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.rollbackRequested,
        actorId: actorId,
        createdAtUtc: rollback.requestedAtUtc.toUtc(),
        details: 'rollback:${rollback.fromReleaseId}->${rollback.toReleaseId}',
      ),
    );
  }

  void verifyRecovery({
    required AvoraIncidentRecoveryVerification verification,
    required String actorId,
    required String eventId,
  }) {
    verification.validate();

    final current = _lifecycleRegistry.active(verification.incidentId);

    if (current == null) {
      throw StateError('incident_not_found');
    }

    if (current.status != AvoraIncidentStatus.recovering) {
      throw StateError('incident_not_in_recovery');
    }

    if (!verification.passed) {
      throw StateError('recovery_verification_failed');
    }

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: verification.incidentId,
        action: AvoraIncidentResponseAction.recoveryVerified,
        actorId: actorId,
        createdAtUtc: verification.verifiedAtUtc.toUtc(),
        details: verification.notes,
      ),
    );

    _lifecycleRegistry.transition(
      incidentId: verification.incidentId,
      nextStatus: AvoraIncidentStatus.resolved,
      actorId: actorId,
      reason: 'recovery_verified',
      changedAtUtc: verification.verifiedAtUtc,
    );
  }

  void close({
    required String incidentId,
    required String actorId,
    required String eventId,
    required DateTime atUtc,
  }) {
    if (!_responseLedger.hasAction(
      incidentId,
      AvoraIncidentResponseAction.recoveryVerified,
    )) {
      throw StateError(
        'incident_cannot_close_without_recovery_verification',
      );
    }

    _lifecycleRegistry.transition(
      incidentId: incidentId,
      nextStatus: AvoraIncidentStatus.closed,
      actorId: actorId,
      reason: 'incident_closed_after_verified_recovery',
      changedAtUtc: atUtc,
    );

    _responseLedger.append(
      AvoraIncidentResponseEvent(
        eventId: eventId,
        incidentId: incidentId,
        action: AvoraIncidentResponseAction.closed,
        actorId: actorId,
        createdAtUtc: atUtc.toUtc(),
        details: 'incident_closed',
      ),
    );
  }

  static bool criticalIncidentMustContainBeforeRecovering() => true;

  static bool restoreAndRollbackMustRemainIncidentLinked() => true;

  static bool recoveryMustBeVerifiedBeforeIncidentClosure() => true;

  static bool financialAndDataIntegrityChecksMustBePartOfVerification() => true;

  static bool incidentHistoryMustSurviveRecovery() => true;

  static bool ownerMustSeeHumanReadableIncidentStatus() => true;
}

class AvoraIncidentResponseArchitecture {
  const AvoraIncidentResponseArchitecture._();

  static bool incidentResponseMustBeStateDrivenNotAdHoc() => true;

  static bool emergencyFixMustNotDestroyEvidenceTrail() => true;

  static bool criticalRepairMustHaveContainmentAndVerification() => true;

  static bool rollbackAndRestoreAreRecoveryOptionsNotAutomaticFirstSteps() =>
      true;

  static bool failedVerificationMustKeepIncidentOpen() => true;

  static bool futureRecoveryActionsMustFitSameIncidentTimeline() => true;

  static bool finalOwnerRecoveryKitMustExplainThisLifecycleSimply() => true;
}
