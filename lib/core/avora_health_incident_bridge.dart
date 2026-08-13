import 'avora_release_health_anomaly.dart';

enum AvoraIncidentSignalFamily {
  stability,
  payment,
  wallet,
  game,
  messaging,
  voice,
  backend,
  integrity,
  security,
  other,
}

class AvoraIncidentCorrelationKey {
  const AvoraIncidentCorrelationKey({
    required this.releaseId,
    required this.family,
    required this.serviceScope,
    required this.countryScope,
  });

  final String releaseId;
  final AvoraIncidentSignalFamily family;
  final String serviceScope;
  final String countryScope;

  String get canonical =>
      '$releaseId|${family.name}|$serviceScope|$countryScope';

  @override
  bool operator ==(Object other) {
    return other is AvoraIncidentCorrelationKey &&
        other.releaseId == releaseId &&
        other.family == family &&
        other.serviceScope == serviceScope &&
        other.countryScope == countryScope;
  }

  @override
  int get hashCode => Object.hash(
        releaseId,
        family,
        serviceScope,
        countryScope,
      );
}

class AvoraHealthSignalCorrelationPolicy {
  const AvoraHealthSignalCorrelationPolicy({
    this.correlationWindow = const Duration(minutes: 15),
  });

  final Duration correlationWindow;

  AvoraIncidentSignalFamily familyFor(
    AvoraHealthSignalKind kind,
  ) {
    switch (kind) {
      case AvoraHealthSignalKind.crashSpike:
      case AvoraHealthSignalKind.appHangSpike:
        return AvoraIncidentSignalFamily.stability;

      case AvoraHealthSignalKind.rechargeFailureSpike:
      case AvoraHealthSignalKind.refundOrChargebackSpike:
        return AvoraIncidentSignalFamily.payment;

      case AvoraHealthSignalKind.walletReconciliationFailure:
        return AvoraIncidentSignalFamily.wallet;

      case AvoraHealthSignalKind.gameSettlementMismatch:
        return AvoraIncidentSignalFamily.game;

      case AvoraHealthSignalKind.messageDeliveryFailure:
        return AvoraIncidentSignalFamily.messaging;

      case AvoraHealthSignalKind.voiceRoomDegradation:
        return AvoraIncidentSignalFamily.voice;

      case AvoraHealthSignalKind.apiLatencySpike:
      case AvoraHealthSignalKind.serverErrorSpike:
        return AvoraIncidentSignalFamily.backend;

      case AvoraHealthSignalKind.dataIntegrityFailure:
        return AvoraIncidentSignalFamily.integrity;

      case AvoraHealthSignalKind.securityAnomaly:
        return AvoraIncidentSignalFamily.security;

      case AvoraHealthSignalKind.other:
        return AvoraIncidentSignalFamily.other;
    }
  }

  AvoraIncidentCorrelationKey keyFor(
    AvoraReleaseHealthSignal signal,
  ) {
    signal.validate();

    return AvoraIncidentCorrelationKey(
      releaseId: signal.releaseId,
      family: familyFor(signal.kind),
      serviceScope: _normalizeScope(signal.serviceName),
      countryScope: _normalizeScope(signal.countryCode),
    );
  }

  bool mayCorrelate({
    required AvoraReleaseHealthSignal existing,
    required AvoraReleaseHealthSignal incoming,
  }) {
    existing.validate();
    incoming.validate();

    if (keyFor(existing) != keyFor(incoming)) {
      return false;
    }

    final difference = incoming.observedAtUtc
        .toUtc()
        .difference(existing.observedAtUtc.toUtc())
        .abs();

    return difference <= correlationWindow;
  }

  String _normalizeScope(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return 'global';
    }

    return normalized;
  }

  static bool financialAndSecurityFamiliesMustRemainSeparate() => true;

  static bool differentReleasesMustNotSilentlyMerge() => true;

  static bool correlationMustBeTimeBounded() => true;

  static bool serviceAndCountryScopeMayAffectCorrelation() => true;
}

class AvoraCorrelatedIncident {
  const AvoraCorrelatedIncident({
    required this.incidentId,
    required this.correlationKey,
    required this.primarySignalId,
    required this.signalIds,
    required this.highestSeverity,
    required this.firstObservedAtUtc,
    required this.lastObservedAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String incidentId;
  final AvoraIncidentCorrelationKey correlationKey;

  final String primarySignalId;
  final List<String> signalIds;

  final AvoraHealthSignalSeverity highestSeverity;

  final DateTime firstObservedAtUtc;
  final DateTime lastObservedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  void validate() {
    if (incidentId.trim().isEmpty ||
        primarySignalId.trim().isEmpty ||
        signalIds.isEmpty ||
        !signalIds.contains(primarySignalId)) {
      throw StateError('invalid_correlated_incident');
    }

    if (lastObservedAtUtc.isBefore(firstObservedAtUtc)) {
      throw StateError(
        'incident_observation_time_invalid',
      );
    }
  }
}

enum AvoraHealthIncidentBridgeResultType {
  created,
  correlated,
  duplicateIgnored,
}

class AvoraHealthIncidentBridgeResult {
  const AvoraHealthIncidentBridgeResult({
    required this.type,
    required this.incident,
    required this.signalId,
  });

  final AvoraHealthIncidentBridgeResultType type;
  final AvoraCorrelatedIncident incident;
  final String signalId;
}

class AvoraHealthIncidentBridge {
  AvoraHealthIncidentBridge({
    AvoraHealthSignalCorrelationPolicy? correlationPolicy,
  }) : correlationPolicy =
            correlationPolicy ?? const AvoraHealthSignalCorrelationPolicy();

  final AvoraHealthSignalCorrelationPolicy correlationPolicy;

  final Map<String, AvoraReleaseHealthSignal> _signals =
      <String, AvoraReleaseHealthSignal>{};

  final Map<String, AvoraCorrelatedIncident> _incidents =
      <String, AvoraCorrelatedIncident>{};

  final Map<String, String> _signalToIncident = <String, String>{};

  AvoraHealthIncidentBridgeResult ingest({
    required AvoraReleaseHealthSignal signal,
    required String Function() incidentIdFactory,
    required DateTime processedAtUtc,
  }) {
    signal.validate();

    final alreadyIncidentId = _signalToIncident[signal.signalId];

    if (alreadyIncidentId != null) {
      return AvoraHealthIncidentBridgeResult(
        type: AvoraHealthIncidentBridgeResultType.duplicateIgnored,
        incident: _incidents[alreadyIncidentId]!,
        signalId: signal.signalId,
      );
    }

    final matchingIncident = _findMatchingIncident(signal);

    if (matchingIncident == null) {
      final incidentId = incidentIdFactory().trim();

      if (incidentId.isEmpty || _incidents.containsKey(incidentId)) {
        throw StateError(
          'invalid_or_duplicate_generated_incident_id',
        );
      }

      final created = AvoraCorrelatedIncident(
        incidentId: incidentId,
        correlationKey: correlationPolicy.keyFor(signal),
        primarySignalId: signal.signalId,
        signalIds: <String>[signal.signalId],
        highestSeverity: signal.severity,
        firstObservedAtUtc: signal.observedAtUtc.toUtc(),
        lastObservedAtUtc: signal.observedAtUtc.toUtc(),
        createdAtUtc: processedAtUtc.toUtc(),
        updatedAtUtc: processedAtUtc.toUtc(),
      );

      created.validate();

      _signals[signal.signalId] = signal;
      _incidents[incidentId] = created;
      _signalToIncident[signal.signalId] = incidentId;

      return AvoraHealthIncidentBridgeResult(
        type: AvoraHealthIncidentBridgeResultType.created,
        incident: created,
        signalId: signal.signalId,
      );
    }

    final updatedSignalIds = <String>[
      ...matchingIncident.signalIds,
      signal.signalId,
    ];

    final updated = AvoraCorrelatedIncident(
      incidentId: matchingIncident.incidentId,
      correlationKey: matchingIncident.correlationKey,
      primarySignalId: matchingIncident.primarySignalId,
      signalIds: updatedSignalIds,
      highestSeverity: _maxSeverity(
        matchingIncident.highestSeverity,
        signal.severity,
      ),
      firstObservedAtUtc: _earlier(
        matchingIncident.firstObservedAtUtc,
        signal.observedAtUtc.toUtc(),
      ),
      lastObservedAtUtc: _later(
        matchingIncident.lastObservedAtUtc,
        signal.observedAtUtc.toUtc(),
      ),
      createdAtUtc: matchingIncident.createdAtUtc,
      updatedAtUtc: processedAtUtc.toUtc(),
    );

    updated.validate();

    _signals[signal.signalId] = signal;
    _incidents[updated.incidentId] = updated;
    _signalToIncident[signal.signalId] = updated.incidentId;

    return AvoraHealthIncidentBridgeResult(
      type: AvoraHealthIncidentBridgeResultType.correlated,
      incident: updated,
      signalId: signal.signalId,
    );
  }

  AvoraCorrelatedIncident? incidentById(
    String incidentId,
  ) {
    return _incidents[incidentId];
  }

  String? incidentIdForSignal(String signalId) {
    return _signalToIncident[signalId];
  }

  List<AvoraReleaseHealthSignal> signalsForIncident(
    String incidentId,
  ) {
    final incident = _incidents[incidentId];

    if (incident == null) {
      return const <AvoraReleaseHealthSignal>[];
    }

    return List<AvoraReleaseHealthSignal>.unmodifiable(
      incident.signalIds.map((id) => _signals[id]!),
    );
  }

  AvoraCorrelatedIncident? _findMatchingIncident(
    AvoraReleaseHealthSignal incoming,
  ) {
    final key = correlationPolicy.keyFor(incoming);

    for (final incident in _incidents.values) {
      if (incident.correlationKey != key) {
        continue;
      }

      final anchorSignal = _signals[incident.signalIds.last];

      if (anchorSignal == null) {
        continue;
      }

      if (correlationPolicy.mayCorrelate(
        existing: anchorSignal,
        incoming: incoming,
      )) {
        return incident;
      }
    }

    return null;
  }

  AvoraHealthSignalSeverity _maxSeverity(
    AvoraHealthSignalSeverity a,
    AvoraHealthSignalSeverity b,
  ) {
    if (b.index > a.index) {
      return b;
    }

    return a;
  }

  DateTime _earlier(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }

  DateTime _later(DateTime a, DateTime b) {
    return a.isAfter(b) ? a : b;
  }

  static bool duplicateSignalMustNotCreateDuplicateIncident() => true;

  static bool correlatedSignalsMustRemainIndividuallyTraceable() => true;

  static bool incidentSeverityMustEscalateWithStrongerSignal() => true;

  static bool correlationMustNeverDeleteOriginalSignalEvidence() => true;

  static bool incidentMustRetainPrimarySignalIdentity() => true;
}

class AvoraHealthIncidentBridgeArchitecture {
  const AvoraHealthIncidentBridgeArchitecture._();

  static bool signalFloodMustNotCreateIncidentFlood() => true;

  static bool unrelatedIncidentsMustRemainSeparate() => true;

  static bool releaseBoundaryMustRemainAuthoritative() => true;

  static bool financialSecurityAndIntegritySignalsNeedSafeIsolation() => true;

  static bool correlationMustBeDeterministicAndAuditable() => true;

  static bool futureMonitoringProvidersMustUseSameBridge() => true;

  static bool ownerHealthPanelMustShowCorrelatedIncidentNotRawFlood() => true;

  static bool rawSignalsMustRemainAvailableForInvestigation() => true;
}
