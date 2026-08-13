enum AvoraHealthSignalKind {
  crashSpike,
  appHangSpike,
  rechargeFailureSpike,
  refundOrChargebackSpike,
  walletReconciliationFailure,
  gameSettlementMismatch,
  messageDeliveryFailure,
  voiceRoomDegradation,
  apiLatencySpike,
  serverErrorSpike,
  dataIntegrityFailure,
  securityAnomaly,
  other,
}

enum AvoraHealthSignalSeverity {
  info,
  caution,
  high,
  critical,
}

class AvoraReleaseHealthSignal {
  const AvoraReleaseHealthSignal({
    required this.signalId,
    required this.kind,
    required this.severity,
    required this.releaseId,
    required this.appVersion,
    required this.buildNumber,
    required this.observedAtUtc,
    required this.metricName,
    required this.observedValue,
    required this.expectedValue,
    required this.correlationId,
    required this.details,
    this.countryCode,
    this.serviceName,
  });

  final String signalId;
  final AvoraHealthSignalKind kind;
  final AvoraHealthSignalSeverity severity;

  final String releaseId;
  final String appVersion;
  final String buildNumber;

  final DateTime observedAtUtc;

  final String metricName;
  final double observedValue;
  final double expectedValue;

  final String correlationId;
  final String details;

  final String? countryCode;
  final String? serviceName;

  void validate() {
    if (signalId.trim().isEmpty ||
        releaseId.trim().isEmpty ||
        appVersion.trim().isEmpty ||
        buildNumber.trim().isEmpty ||
        metricName.trim().isEmpty ||
        correlationId.trim().isEmpty ||
        details.trim().isEmpty) {
      throw ArgumentError('invalid_release_health_signal');
    }
  }
}

class AvoraReleaseHealthSignalRegistry {
  final Map<String, AvoraReleaseHealthSignal> _signals =
      <String, AvoraReleaseHealthSignal>{};

  void append(AvoraReleaseHealthSignal signal) {
    signal.validate();

    if (_signals.containsKey(signal.signalId)) {
      throw StateError('duplicate_release_health_signal');
    }

    _signals[signal.signalId] = signal;
  }

  AvoraReleaseHealthSignal? byId(String signalId) {
    return _signals[signalId];
  }

  List<AvoraReleaseHealthSignal> forRelease(
    String releaseId,
  ) {
    return List<AvoraReleaseHealthSignal>.unmodifiable(
      _signals.values.where(
        (signal) => signal.releaseId == releaseId,
      ),
    );
  }

  List<AvoraReleaseHealthSignal> byKind(
    AvoraHealthSignalKind kind,
  ) {
    return List<AvoraReleaseHealthSignal>.unmodifiable(
      _signals.values.where(
        (signal) => signal.kind == kind,
      ),
    );
  }

  static bool healthSignalsMustRemainTraceable() => true;

  static bool healthSignalsMustRemainReleaseAware() => true;

  static bool duplicateSignalsMustNotBeSilentlyAdded() => true;
}

class AvoraIncidentCandidate {
  const AvoraIncidentCandidate({
    required this.candidateId,
    required this.primarySignalId,
    required this.relatedSignalIds,
    required this.severity,
    required this.title,
    required this.reason,
    required this.releaseId,
    required this.createdAtUtc,
    required this.requiresHumanReview,
    required this.requiresImmediateContainment,
  });

  final String candidateId;
  final String primarySignalId;
  final List<String> relatedSignalIds;

  final AvoraHealthSignalSeverity severity;
  final String title;
  final String reason;
  final String releaseId;
  final DateTime createdAtUtc;

  final bool requiresHumanReview;
  final bool requiresImmediateContainment;

  void validate() {
    if (candidateId.trim().isEmpty ||
        primarySignalId.trim().isEmpty ||
        title.trim().isEmpty ||
        reason.trim().isEmpty ||
        releaseId.trim().isEmpty) {
      throw ArgumentError('invalid_incident_candidate');
    }

    if (!relatedSignalIds.contains(primarySignalId)) {
      throw StateError(
        'candidate_must_include_primary_signal',
      );
    }
  }
}

class AvoraHealthSignalIncidentPolicy {
  const AvoraHealthSignalIncidentPolicy();

  AvoraIncidentCandidate buildCandidate({
    required AvoraReleaseHealthSignal signal,
    required String candidateId,
  }) {
    signal.validate();

    final immediateContainment =
        signal.severity == AvoraHealthSignalSeverity.critical &&
            _financialOrSecurityCritical(signal.kind);

    return AvoraIncidentCandidate(
      candidateId: candidateId,
      primarySignalId: signal.signalId,
      relatedSignalIds: <String>[signal.signalId],
      severity: signal.severity,
      title: _titleFor(signal.kind),
      reason: signal.details,
      releaseId: signal.releaseId,
      createdAtUtc: signal.observedAtUtc.toUtc(),
      requiresHumanReview: signal.severity != AvoraHealthSignalSeverity.info,
      requiresImmediateContainment: immediateContainment,
    );
  }

  bool _financialOrSecurityCritical(
    AvoraHealthSignalKind kind,
  ) {
    switch (kind) {
      case AvoraHealthSignalKind.rechargeFailureSpike:
      case AvoraHealthSignalKind.refundOrChargebackSpike:
      case AvoraHealthSignalKind.walletReconciliationFailure:
      case AvoraHealthSignalKind.gameSettlementMismatch:
      case AvoraHealthSignalKind.dataIntegrityFailure:
      case AvoraHealthSignalKind.securityAnomaly:
        return true;

      default:
        return false;
    }
  }

  String _titleFor(AvoraHealthSignalKind kind) {
    switch (kind) {
      case AvoraHealthSignalKind.crashSpike:
        return 'Crash spike detected';

      case AvoraHealthSignalKind.appHangSpike:
        return 'App hang spike detected';

      case AvoraHealthSignalKind.rechargeFailureSpike:
        return 'Recharge failure anomaly';

      case AvoraHealthSignalKind.refundOrChargebackSpike:
        return 'Refund or chargeback anomaly';

      case AvoraHealthSignalKind.walletReconciliationFailure:
        return 'Wallet reconciliation failure';

      case AvoraHealthSignalKind.gameSettlementMismatch:
        return 'Game settlement mismatch';

      case AvoraHealthSignalKind.messageDeliveryFailure:
        return 'Message delivery degradation';

      case AvoraHealthSignalKind.voiceRoomDegradation:
        return 'Voice room degradation';

      case AvoraHealthSignalKind.apiLatencySpike:
        return 'API latency spike';

      case AvoraHealthSignalKind.serverErrorSpike:
        return 'Server error spike';

      case AvoraHealthSignalKind.dataIntegrityFailure:
        return 'Data integrity failure';

      case AvoraHealthSignalKind.securityAnomaly:
        return 'Security anomaly';

      case AvoraHealthSignalKind.other:
        return 'Health anomaly detected';
    }
  }

  static bool healthSignalMayCreateIncidentCandidate() => true;

  static bool criticalFinancialAnomalyMayRequireImmediateContainment() => true;

  static bool criticalSecurityAnomalyMayRequireImmediateContainment() => true;

  static bool oneSignalMustNotAutomaticallyPunishUserAccount() => true;

  static bool anomalyDetectionMustRemainSeparateFromPunishment() => true;

  static bool humanReviewMustRemainAvailable() => true;
}

class AvoraHealthThresholdPolicy {
  const AvoraHealthThresholdPolicy({
    required this.policyVersion,
    required this.crashRateWarning,
    required this.crashRateCritical,
    required this.rechargeFailureWarning,
    required this.rechargeFailureCritical,
    required this.refundRateWarning,
    required this.refundRateCritical,
  });

  final String policyVersion;

  final double crashRateWarning;
  final double crashRateCritical;

  final double rechargeFailureWarning;
  final double rechargeFailureCritical;

  final double refundRateWarning;
  final double refundRateCritical;

  void validate() {
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError(
        'health_threshold_policy_version_required',
      );
    }

    final values = <double>[
      crashRateWarning,
      crashRateCritical,
      rechargeFailureWarning,
      rechargeFailureCritical,
      refundRateWarning,
      refundRateCritical,
    ];

    if (values.any((value) => value < 0)) {
      throw ArgumentError('health_threshold_must_not_be_negative');
    }

    if (crashRateCritical < crashRateWarning ||
        rechargeFailureCritical < rechargeFailureWarning ||
        refundRateCritical < refundRateWarning) {
      throw StateError(
        'critical_threshold_must_not_be_below_warning',
      );
    }
  }
}

class AvoraHealthMetricEvaluator {
  const AvoraHealthMetricEvaluator();

  AvoraHealthSignalSeverity evaluate({
    required double observedValue,
    required double warningThreshold,
    required double criticalThreshold,
  }) {
    if (observedValue < 0 ||
        warningThreshold < 0 ||
        criticalThreshold < warningThreshold) {
      throw ArgumentError('invalid_health_metric_threshold');
    }

    if (observedValue >= criticalThreshold) {
      return AvoraHealthSignalSeverity.critical;
    }

    if (observedValue >= warningThreshold) {
      return AvoraHealthSignalSeverity.high;
    }

    return AvoraHealthSignalSeverity.info;
  }

  static bool thresholdsMustBePolicyDriven() => true;

  static bool thresholdsMustBeVersioned() => true;

  static bool healthMetricsMustNotBeHardcodedIntoClientUi() => true;

  static bool futureMetricsMustFitSameEvaluationModel() => true;
}

class AvoraReleaseHealthArchitecture {
  const AvoraReleaseHealthArchitecture._();

  static bool crashSpikeMustBeDetectable() => true;

  static bool rechargeFailureSpikeMustBeDetectable() => true;

  static bool abnormalRefundRateMustBeDetectable() => true;

  static bool walletReconciliationFailureMustBeDetectable() => true;

  static bool gameSettlementMismatchMustBeDetectable() => true;

  static bool voiceAndApiDegradationMustBeDetectable() => true;

  static bool dataIntegrityAndSecurityAnomaliesMustBeDetectable() => true;

  static bool automaticDetectionMustNotDestroyEvidence() => true;

  static bool automaticDetectionMustFeedIncidentPipeline() => true;

  static bool ownerMustEventuallySeeHealthStatusInOnePanel() => true;

  static bool futureObservabilityProvidersMustUseSameSignalContract() => true;
}
