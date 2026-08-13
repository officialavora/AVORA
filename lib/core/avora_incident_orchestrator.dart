import 'avora_incident_recovery.dart';

class AvoraIncidentEventFact {
  final String eventId;

  final String subjectId;

  final AvoraRecoveryDomain domain;

  final String sourceType;

  final DateTime occurredAt;

  final int invalidUnits;

  final String? countryCode;
  final String? regionCode;
  final String? roomId;
  final String? featureKey;

  final String? softwareVersion;
  final String? policyVersion;

  final Set<String> detectionTags;

  const AvoraIncidentEventFact({
    required this.eventId,
    required this.subjectId,
    required this.domain,
    required this.sourceType,
    required this.occurredAt,
    required this.invalidUnits,
    this.countryCode,
    this.regionCode,
    this.roomId,
    this.featureKey,
    this.softwareVersion,
    this.policyVersion,
    this.detectionTags = const {},
  }) : assert(invalidUnits >= 0);
}

class AvoraIncidentMatchRule {
  final String id;

  final Set<AvoraRecoveryDomain> domains;

  final Set<String> sourceTypes;

  final Set<String> requiredTags;

  final Set<String> softwareVersions;

  final Set<String> policyVersions;

  const AvoraIncidentMatchRule({
    required this.id,
    this.domains = const {},
    this.sourceTypes = const {},
    this.requiredTags = const {},
    this.softwareVersions = const {},
    this.policyVersions = const {},
  });

  bool matches(AvoraIncidentEventFact fact) {
    if (domains.isNotEmpty && !domains.contains(fact.domain)) {
      return false;
    }

    if (sourceTypes.isNotEmpty && !sourceTypes.contains(fact.sourceType)) {
      return false;
    }

    if (requiredTags.isNotEmpty &&
        !fact.detectionTags.containsAll(requiredTags)) {
      return false;
    }

    if (softwareVersions.isNotEmpty) {
      final value = fact.softwareVersion;

      if (value == null || !softwareVersions.contains(value)) {
        return false;
      }
    }

    if (policyVersions.isNotEmpty) {
      final value = fact.policyVersion;

      if (value == null || !policyVersions.contains(value)) {
        return false;
      }
    }

    return true;
  }
}

class AvoraIncidentBlastRadius {
  final String incidentId;

  final int affectedEvents;

  final int affectedSubjects;

  final int totalInvalidUnits;

  final Set<String> subjectIds;

  final Set<String> countryCodes;

  final Map<AvoraRecoveryDomain, int> domainEventCounts;

  final List<AvoraIncidentEventFact> matchedEvents;

  const AvoraIncidentBlastRadius({
    required this.incidentId,
    required this.affectedEvents,
    required this.affectedSubjects,
    required this.totalInvalidUnits,
    required this.subjectIds,
    required this.countryCodes,
    required this.domainEventCounts,
    required this.matchedEvents,
  });
}

class AvoraRecoveryBatch {
  final int batchNumber;

  final List<AvoraRecoveryAction> actions;

  const AvoraRecoveryBatch({
    required this.batchNumber,
    required this.actions,
  });
}

class AvoraOneClickRecoveryBundle {
  final String incidentId;

  final AvoraIncidentBlastRadius blastRadius;

  final AvoraRecoveryPlan recoveryPlan;

  final AvoraRecoveryExecutionPreview preview;

  /// Internal batches.
  /// Operator still sees one Restore action.
  final List<AvoraRecoveryBatch> pendingBatches;

  const AvoraOneClickRecoveryBundle({
    required this.incidentId,
    required this.blastRadius,
    required this.recoveryPlan,
    required this.preview,
    required this.pendingBatches,
  });

  int get pendingActions => preview.pendingActions;

  bool get nothingToRepair => pendingActions == 0;
}

class AvoraIncidentOrchestrator {
  const AvoraIncidentOrchestrator._();

  static bool _scopeMatches({
    required AvoraIncident incident,
    required AvoraIncidentEventFact fact,
  }) {
    final value = incident.scopeValue;

    switch (incident.scopeType) {
      case AvoraIncidentScopeType.global:
        return true;

      case AvoraIncidentScopeType.country:
        if (value == null || fact.countryCode == null) {
          return false;
        }

        return value.trim().toUpperCase() ==
            fact.countryCode!.trim().toUpperCase();

      case AvoraIncidentScopeType.region:
        if (value == null || fact.regionCode == null) {
          return false;
        }

        return value.trim().toUpperCase() ==
            fact.regionCode!.trim().toUpperCase();

      case AvoraIncidentScopeType.feature:
        return value != null &&
            fact.featureKey != null &&
            value == fact.featureKey;

      case AvoraIncidentScopeType.user:
        return value != null && fact.subjectId == value;

      case AvoraIncidentScopeType.room:
        return value != null && fact.roomId == value;

      case AvoraIncidentScopeType.custom:
        if (value == null) {
          return false;
        }

        return fact.detectionTags.contains(value);
    }
  }

  static AvoraIncidentBlastRadius scanBlastRadius({
    required AvoraIncident incident,
    required AvoraIncidentMatchRule rule,
    required List<AvoraIncidentEventFact> eventFacts,
  }) {
    if (rule.id != incident.detectionRuleId) {
      return AvoraIncidentBlastRadius(
        incidentId: incident.id,
        affectedEvents: 0,
        affectedSubjects: 0,
        totalInvalidUnits: 0,
        subjectIds: const {},
        countryCodes: const {},
        domainEventCounts: const {},
        matchedEvents: const [],
      );
    }

    final matched = eventFacts.where((fact) {
      if (!incident.containsTime(fact.occurredAt)) {
        return false;
      }

      if (!_scopeMatches(
        incident: incident,
        fact: fact,
      )) {
        return false;
      }

      return rule.matches(fact);
    }).toList(growable: false);

    final subjects = matched.map((fact) => fact.subjectId).toSet();

    final countries =
        matched.map((fact) => fact.countryCode).whereType<String>().toSet();

    final domainCounts = <AvoraRecoveryDomain, int>{};

    for (final fact in matched) {
      domainCounts.update(
        fact.domain,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final totalInvalidUnits = matched.fold<int>(
      0,
      (sum, fact) => sum + fact.invalidUnits,
    );

    return AvoraIncidentBlastRadius(
      incidentId: incident.id,
      affectedEvents: matched.length,
      affectedSubjects: subjects.length,
      totalInvalidUnits: totalInvalidUnits,
      subjectIds: Set.unmodifiable(subjects),
      countryCodes: Set.unmodifiable(countries),
      domainEventCounts: Map.unmodifiable(domainCounts),
      matchedEvents: List.unmodifiable(matched),
    );
  }

  static List<AvoraRecoveryBatch> buildPendingBatches({
    required AvoraRecoveryPlan plan,
    required List<AvoraRecoveryExecutionRecord> existingExecutions,
    int batchSize = 500,
  }) {
    if (batchSize <= 0) {
      throw ArgumentError.value(
        batchSize,
        'batchSize',
        'must be greater than zero',
      );
    }

    final pending = AvoraIncidentRecoveryEngine.pendingActions(
      plan: plan,
      existingExecutions: existingExecutions,
    );

    final batches = <AvoraRecoveryBatch>[];

    for (var start = 0; start < pending.length; start += batchSize) {
      final end = (start + batchSize) > pending.length
          ? pending.length
          : start + batchSize;

      batches.add(
        AvoraRecoveryBatch(
          batchNumber: batches.length + 1,
          actions: List.unmodifiable(
            pending.sublist(start, end),
          ),
        ),
      );
    }

    return List.unmodifiable(batches);
  }

  static AvoraOneClickRecoveryBundle prepareOneClickRecovery({
    required AvoraIncident incident,
    required AvoraIncidentMatchRule rule,
    required List<AvoraIncidentEventFact> eventFacts,

    /// These are authoritative recomputed corrections.
    /// They come from valid server history, not blind subtraction.
    required List<AvoraAuthoritativeStateCorrection> authoritativeCorrections,
    required List<AvoraRecoveryExecutionRecord> existingExecutions,
    required DateTime generatedAt,
    int batchSize = 500,
  }) {
    final blastRadius = scanBlastRadius(
      incident: incident,
      rule: rule,
      eventFacts: eventFacts,
    );

    final matchedEventIds =
        blastRadius.matchedEvents.map((event) => event.eventId).toSet();

    final relevantCorrections = authoritativeCorrections.where((correction) {
      if (correction.incidentId != incident.id) {
        return false;
      }

      if (correction.sourceEventIds.isEmpty) {
        return blastRadius.subjectIds.contains(
          correction.subjectId,
        );
      }

      return correction.sourceEventIds.any(
        matchedEventIds.contains,
      );
    }).toList(growable: false);

    final plan = AvoraIncidentRecoveryEngine.buildPlan(
      incidentId: incident.id,
      generatedAt: generatedAt,
      corrections: relevantCorrections,
    );

    final preview = AvoraIncidentRecoveryEngine.preview(
      plan: plan,
      existingExecutions: existingExecutions,
    );

    final batches = buildPendingBatches(
      plan: plan,
      existingExecutions: existingExecutions,
      batchSize: batchSize,
    );

    return AvoraOneClickRecoveryBundle(
      incidentId: incident.id,
      blastRadius: blastRadius,
      recoveryPlan: plan,
      preview: preview,
      pendingBatches: batches,
    );
  }

  /// Operator must never need to select every affected ID manually.
  static bool requiresManualPerIdSelection() {
    return false;
  }

  /// Successful batch actions remain applied.
  /// A retry only receives still-pending action keys.
  static bool supportsSafeResume() {
    return true;
  }

  /// One operator action can orchestrate many internal batches.
  static bool supportsOneClickBulkExecution() {
    return true;
  }
}
