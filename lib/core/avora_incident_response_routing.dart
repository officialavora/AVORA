import 'avora_health_incident_bridge.dart';
import 'avora_release_health_anomaly.dart';

enum AvoraIncidentResponsePriority {
  observe,
  standard,
  urgent,
  critical,
}

enum AvoraIncidentResponseLane {
  reliability,
  payments,
  wallet,
  gameOperations,
  messagingOperations,
  voiceOperations,
  backendOperations,
  integrityReview,
  securityReview,
  generalOperations,
}

enum AvoraIncidentEscalationTarget {
  operations,
  engineering,
  finance,
  risk,
  security,
  owner,
}

class AvoraIncidentResponseRoute {
  const AvoraIncidentResponseRoute({
    required this.incidentId,
    required this.priority,
    required this.primaryLane,
    required this.escalationTargets,
    required this.requiresHumanReview,
    required this.requiresOwnerVisibility,
    required this.automaticDestructiveActionAllowed,
    required this.reasonCodes,
    required this.routedAtUtc,
  });

  final String incidentId;
  final AvoraIncidentResponsePriority priority;
  final AvoraIncidentResponseLane primaryLane;
  final Set<AvoraIncidentEscalationTarget> escalationTargets;

  final bool requiresHumanReview;
  final bool requiresOwnerVisibility;

  /// Health/anomaly routing may alert, freeze a workflow for review,
  /// or request intervention through a future controlled service.
  /// It must not directly ban accounts, delete evidence, alter ledgers,
  /// or silently rewrite authoritative state.
  final bool automaticDestructiveActionAllowed;

  final List<String> reasonCodes;
  final DateTime routedAtUtc;

  void validate() {
    if (incidentId.trim().isEmpty) {
      throw StateError('incident_route_requires_incident_id');
    }

    if (reasonCodes.isEmpty) {
      throw StateError('incident_route_requires_reason');
    }

    if (automaticDestructiveActionAllowed) {
      throw StateError(
        'health_incident_route_must_not_allow_destructive_action',
      );
    }

    if (priority == AvoraIncidentResponsePriority.critical &&
        !requiresHumanReview) {
      throw StateError(
        'critical_incident_requires_human_review',
      );
    }
  }
}

class AvoraIncidentResponseRouter {
  const AvoraIncidentResponseRouter();

  AvoraIncidentResponseRoute route({
    required AvoraCorrelatedIncident incident,
    required DateTime routedAtUtc,
  }) {
    incident.validate();

    final family = incident.correlationKey.family;
    final priority = _priorityFor(
      severity: incident.highestSeverity,
      signalCount: incident.signalIds.length,
    );

    final lane = _laneFor(family);

    final targets = <AvoraIncidentEscalationTarget>{
      AvoraIncidentEscalationTarget.operations,
    };

    final reasons = <String>[
      'family:${family.name}',
      'severity:${incident.highestSeverity.name}',
      'signals:${incident.signalIds.length}',
    ];

    switch (family) {
      case AvoraIncidentSignalFamily.stability:
        targets.add(AvoraIncidentEscalationTarget.engineering);
        break;

      case AvoraIncidentSignalFamily.payment:
        targets
          ..add(AvoraIncidentEscalationTarget.finance)
          ..add(AvoraIncidentEscalationTarget.risk);
        reasons.add('financial_incident');
        break;

      case AvoraIncidentSignalFamily.wallet:
        targets
          ..add(AvoraIncidentEscalationTarget.finance)
          ..add(AvoraIncidentEscalationTarget.risk)
          ..add(AvoraIncidentEscalationTarget.engineering);
        reasons.add('wallet_authoritative_state');
        break;

      case AvoraIncidentSignalFamily.game:
        targets.add(AvoraIncidentEscalationTarget.engineering);
        reasons.add('game_settlement_or_runtime');
        break;

      case AvoraIncidentSignalFamily.messaging:
      case AvoraIncidentSignalFamily.voice:
      case AvoraIncidentSignalFamily.backend:
        targets.add(AvoraIncidentEscalationTarget.engineering);
        break;

      case AvoraIncidentSignalFamily.integrity:
        targets
          ..add(AvoraIncidentEscalationTarget.engineering)
          ..add(AvoraIncidentEscalationTarget.risk);
        reasons.add('integrity_review_required');
        break;

      case AvoraIncidentSignalFamily.security:
        targets
          ..add(AvoraIncidentEscalationTarget.security)
          ..add(AvoraIncidentEscalationTarget.risk);
        reasons.add('security_review_required');
        break;

      case AvoraIncidentSignalFamily.other:
        break;
    }

    final sensitiveFamily = family == AvoraIncidentSignalFamily.payment ||
        family == AvoraIncidentSignalFamily.wallet ||
        family == AvoraIncidentSignalFamily.integrity ||
        family == AvoraIncidentSignalFamily.security;

    final requiresHumanReview =
        priority == AvoraIncidentResponsePriority.urgent ||
            priority == AvoraIncidentResponsePriority.critical ||
            sensitiveFamily;

    final requiresOwnerVisibility = priority ==
            AvoraIncidentResponsePriority.critical ||
        (sensitiveFamily && priority == AvoraIncidentResponsePriority.urgent);

    if (requiresOwnerVisibility) {
      targets.add(AvoraIncidentEscalationTarget.owner);
      reasons.add('owner_visibility_required');
    }

    final route = AvoraIncidentResponseRoute(
      incidentId: incident.incidentId,
      priority: priority,
      primaryLane: lane,
      escalationTargets:
          Set<AvoraIncidentEscalationTarget>.unmodifiable(targets),
      requiresHumanReview: requiresHumanReview,
      requiresOwnerVisibility: requiresOwnerVisibility,
      automaticDestructiveActionAllowed: false,
      reasonCodes: List<String>.unmodifiable(reasons),
      routedAtUtc: routedAtUtc.toUtc(),
    );

    route.validate();
    return route;
  }

  AvoraIncidentResponsePriority _priorityFor({
    required AvoraHealthSignalSeverity severity,
    required int signalCount,
  }) {
    switch (severity) {
      case AvoraHealthSignalSeverity.info:
        return signalCount >= 10
            ? AvoraIncidentResponsePriority.standard
            : AvoraIncidentResponsePriority.observe;

      case AvoraHealthSignalSeverity.caution:
        return signalCount >= 10
            ? AvoraIncidentResponsePriority.urgent
            : AvoraIncidentResponsePriority.standard;

      case AvoraHealthSignalSeverity.high:
        return signalCount >= 5
            ? AvoraIncidentResponsePriority.critical
            : AvoraIncidentResponsePriority.urgent;

      case AvoraHealthSignalSeverity.critical:
        return AvoraIncidentResponsePriority.critical;
    }
  }

  AvoraIncidentResponseLane _laneFor(
    AvoraIncidentSignalFamily family,
  ) {
    switch (family) {
      case AvoraIncidentSignalFamily.stability:
        return AvoraIncidentResponseLane.reliability;

      case AvoraIncidentSignalFamily.payment:
        return AvoraIncidentResponseLane.payments;

      case AvoraIncidentSignalFamily.wallet:
        return AvoraIncidentResponseLane.wallet;

      case AvoraIncidentSignalFamily.game:
        return AvoraIncidentResponseLane.gameOperations;

      case AvoraIncidentSignalFamily.messaging:
        return AvoraIncidentResponseLane.messagingOperations;

      case AvoraIncidentSignalFamily.voice:
        return AvoraIncidentResponseLane.voiceOperations;

      case AvoraIncidentSignalFamily.backend:
        return AvoraIncidentResponseLane.backendOperations;

      case AvoraIncidentSignalFamily.integrity:
        return AvoraIncidentResponseLane.integrityReview;

      case AvoraIncidentSignalFamily.security:
        return AvoraIncidentResponseLane.securityReview;

      case AvoraIncidentSignalFamily.other:
        return AvoraIncidentResponseLane.generalOperations;
    }
  }

  static bool criticalIncidentsMustRequireHumanReview() => true;

  static bool healthSignalsMustNotDirectlyBanUsers() => true;

  static bool healthSignalsMustNotRewriteLedger() => true;

  static bool healthSignalsMustNotDeleteEvidence() => true;

  static bool sensitiveFinancialIncidentsNeedDedicatedRouting() => true;

  static bool securityIncidentsNeedDedicatedRouting() => true;

  static bool ownerVisibilityMustBePolicyDriven() => true;
}

class AvoraIncidentResponseAuditRecord {
  const AvoraIncidentResponseAuditRecord({
    required this.auditId,
    required this.incidentId,
    required this.priority,
    required this.primaryLane,
    required this.targets,
    required this.reasonCodes,
    required this.createdAtUtc,
  });

  final String auditId;
  final String incidentId;
  final AvoraIncidentResponsePriority priority;
  final AvoraIncidentResponseLane primaryLane;
  final Set<AvoraIncidentEscalationTarget> targets;
  final List<String> reasonCodes;
  final DateTime createdAtUtc;

  void validate() {
    if (auditId.trim().isEmpty || incidentId.trim().isEmpty) {
      throw StateError('invalid_incident_response_audit_record');
    }

    if (reasonCodes.isEmpty) {
      throw StateError('incident_response_audit_requires_reason');
    }
  }
}

class AvoraIncidentResponseAuditLedger {
  final List<AvoraIncidentResponseAuditRecord> _records =
      <AvoraIncidentResponseAuditRecord>[];

  List<AvoraIncidentResponseAuditRecord> get records =>
      List<AvoraIncidentResponseAuditRecord>.unmodifiable(_records);

  void append({
    required String auditId,
    required AvoraIncidentResponseRoute route,
    required DateTime createdAtUtc,
  }) {
    route.validate();

    if (_records.any((record) => record.auditId == auditId)) {
      throw StateError('duplicate_incident_response_audit_id');
    }

    final record = AvoraIncidentResponseAuditRecord(
      auditId: auditId,
      incidentId: route.incidentId,
      priority: route.priority,
      primaryLane: route.primaryLane,
      targets: Set<AvoraIncidentEscalationTarget>.unmodifiable(
        route.escalationTargets,
      ),
      reasonCodes: List<String>.unmodifiable(route.reasonCodes),
      createdAtUtc: createdAtUtc.toUtc(),
    );

    record.validate();
    _records.add(record);
  }

  List<AvoraIncidentResponseAuditRecord> forIncident(
    String incidentId,
  ) {
    return List<AvoraIncidentResponseAuditRecord>.unmodifiable(
      _records.where(
        (record) => record.incidentId == incidentId,
      ),
    );
  }

  static bool routingHistoryMustRemainAuditable() => true;

  static bool reroutingMustAppendInsteadOfRewriteHistory() => true;
}

class AvoraIncidentResponseRoutingArchitecture {
  const AvoraIncidentResponseRoutingArchitecture._();

  static bool correlatedIncidentMustRouteThroughSinglePolicy() => true;

  static bool severityMustDriveResponseUrgency() => true;

  static bool signalVolumeMayRaiseUrgency() => true;

  static bool financialAndSecurityRoutingMustRemainSeparated() => true;

  static bool criticalCasesMustSurfaceToResponsibleHumans() => true;

  static bool automatedDetectionMustNotEqualAutomaticPunishment() => true;

  static bool futureIncidentDashboardMustUseSameRoutingContract() => true;

  static bool futureAlertProvidersMustUseSameRoutingContract() => true;
}
