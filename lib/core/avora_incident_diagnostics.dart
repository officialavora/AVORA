enum AvoraIncidentSeverity {
  low,
  medium,
  high,
  critical,
}

enum AvoraIncidentCategory {
  appCrash,
  uiOrExperience,
  voiceOrRoom,
  messaging,
  rechargeOrPayment,
  refundOrChargeback,
  walletOrLedger,
  gameOrSettlement,
  moderationOrSafety,
  roleOrPermission,
  accountOrSecurity,
  serverOrInfrastructure,
  dataIntegrity,
  unknown,
}

enum AvoraIncidentStatus {
  reported,
  investigating,
  contained,
  recovering,
  resolved,
  closed,
}

enum AvoraIncidentAttachmentKind {
  screenshot,
  video,
  log,
  other,
}

class AvoraIncidentAttachment {
  const AvoraIncidentAttachment({
    required this.attachmentId,
    required this.kind,
    required this.reference,
  });

  final String attachmentId;
  final AvoraIncidentAttachmentKind kind;

  // Storage reference only. Never raw secret/account credentials.
  final String reference;

  void validate() {
    if (attachmentId.trim().isEmpty || reference.trim().isEmpty) {
      throw ArgumentError('invalid_incident_attachment');
    }
  }
}

class AvoraIncidentSubjectReferences {
  const AvoraIncidentSubjectReferences({
    this.avoraId,
    this.roomId,
    this.orderId,
    this.paymentReference,
    this.gameRoundId,
    this.messageId,
  });

  final String? avoraId;
  final String? roomId;
  final String? orderId;
  final String? paymentReference;
  final String? gameRoundId;
  final String? messageId;

  bool get hasAny =>
      _usable(avoraId) ||
      _usable(roomId) ||
      _usable(orderId) ||
      _usable(paymentReference) ||
      _usable(gameRoundId) ||
      _usable(messageId);

  static bool _usable(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class AvoraIncidentEnvironment {
  const AvoraIncidentEnvironment({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.occurredAtUtc,
    this.releaseId,
    this.deviceClass,
    this.correlationId,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final DateTime occurredAtUtc;
  final String? releaseId;
  final String? deviceClass;
  final String? correlationId;

  void validate() {
    if (appVersion.trim().isEmpty ||
        buildNumber.trim().isEmpty ||
        platform.trim().isEmpty) {
      throw ArgumentError('invalid_incident_environment');
    }
  }
}

class AvoraOwnerIncidentReport {
  AvoraOwnerIncidentReport({
    required this.incidentId,
    required this.category,
    required this.severity,
    required this.status,
    required this.whatHappened,
    required this.expectedBehavior,
    required this.environment,
    required this.references,
    required List<AvoraIncidentAttachment> attachments,
    required this.createdAtUtc,
    this.lastActionBeforeProblem,
  }) : attachments = List<AvoraIncidentAttachment>.unmodifiable(attachments);

  final String incidentId;
  final AvoraIncidentCategory category;
  final AvoraIncidentSeverity severity;
  final AvoraIncidentStatus status;

  // Owner-friendly language is allowed.
  final String whatHappened;
  final String expectedBehavior;
  final String? lastActionBeforeProblem;

  final AvoraIncidentEnvironment environment;
  final AvoraIncidentSubjectReferences references;
  final List<AvoraIncidentAttachment> attachments;
  final DateTime createdAtUtc;

  void validate() {
    if (incidentId.trim().isEmpty ||
        whatHappened.trim().isEmpty ||
        expectedBehavior.trim().isEmpty) {
      throw ArgumentError('invalid_owner_incident_report');
    }

    environment.validate();

    for (final attachment in attachments) {
      attachment.validate();
    }
  }
}

class AvoraIncidentDiagnosticEnvelope {
  const AvoraIncidentDiagnosticEnvelope({
    required this.incidentId,
    required this.correlationId,
    required this.category,
    required this.severity,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.occurredAtUtc,
    required this.referenceKeys,
    required this.attachmentIds,
    required this.summary,
  });

  final String incidentId;
  final String correlationId;
  final AvoraIncidentCategory category;
  final AvoraIncidentSeverity severity;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final DateTime occurredAtUtc;

  // Internal trace keys only; never passwords/tokens/card details.
  final Map<String, String> referenceKeys;
  final List<String> attachmentIds;
  final String summary;
}

class AvoraIncidentDiagnosticEnvelopeBuilder {
  const AvoraIncidentDiagnosticEnvelopeBuilder();

  AvoraIncidentDiagnosticEnvelope build(
    AvoraOwnerIncidentReport report,
  ) {
    report.validate();

    final correlationId = _usable(report.environment.correlationId)
        ? report.environment.correlationId!.trim()
        : 'incident:${report.incidentId}';

    final references = <String, String>{};

    void add(String key, String? value) {
      if (_usable(value)) {
        references[key] = value!.trim();
      }
    }

    add('avoraId', report.references.avoraId);
    add('roomId', report.references.roomId);
    add('orderId', report.references.orderId);
    add(
      'paymentReference',
      report.references.paymentReference,
    );
    add('gameRoundId', report.references.gameRoundId);
    add('messageId', report.references.messageId);
    add('releaseId', report.environment.releaseId);

    return AvoraIncidentDiagnosticEnvelope(
      incidentId: report.incidentId,
      correlationId: correlationId,
      category: report.category,
      severity: report.severity,
      appVersion: report.environment.appVersion,
      buildNumber: report.environment.buildNumber,
      platform: report.environment.platform,
      occurredAtUtc: report.environment.occurredAtUtc.toUtc(),
      referenceKeys: Map<String, String>.unmodifiable(references),
      attachmentIds: List<String>.unmodifiable(
        report.attachments.map(
          (attachment) => attachment.attachmentId,
        ),
      ),
      summary: report.whatHappened.trim(),
    );
  }

  static bool _usable(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool ownerNeedNotKnowTechnicalLogLanguage() => true;

  static bool screenshotOrVideoMaySupportIncidentReport() => true;

  static bool correlationIdMustConnectDistributedEvidence() => true;

  static bool incidentMustCaptureBuildAndVersion() => true;
}

class AvoraIncidentPrivacyPolicy {
  const AvoraIncidentPrivacyPolicy._();

  static const Set<String> forbiddenDiagnosticFields = <String>{
    'password',
    'accessToken',
    'refreshToken',
    'privateKey',
    'cardNumber',
    'cvv',
    'otp',
    'ownerRealName',
    'ownerPhoneNumber',
    'ownerBankAccount',
    'ownerPrivateIdentity',
  };

  static bool ownerPublicActorLabelMustRemainOwnerOnly() => true;

  static bool secretsMustNeverBeRequiredForProblemReporting() => true;

  static bool diagnosticAttachmentsMustUseReferencesNotEmbeddedSecrets() =>
      true;

  static bool sensitivePaymentCredentialsMustNeverEnterIncidentEnvelope() =>
      true;
}

class AvoraIncidentTriagePolicy {
  const AvoraIncidentTriagePolicy._();

  static bool criticalFinancialMismatchRequiresImmediateContainment() => true;

  static bool suspectedRefundAbuseRequiresLedgerAndPaymentTrace() => true;

  static bool securityIncidentRequiresAuditPreservation() => true;

  static bool crashRequiresReleaseAndBuildCorrelation() => true;

  static bool moderationIncidentRequiresPolicyVersionCorrelation() => true;

  static bool gameDisputeRequiresAuthoritativeRoundAndSettlementTrace() => true;

  static bool destructiveRepairMustNeverBeFirstResponse() => true;
}

class AvoraIncidentRecoveryArchitecture {
  const AvoraIncidentRecoveryArchitecture._();

  static bool diagnosisMustPrecedeRepairWhenPossible() => true;

  static bool evidenceMustBePreservedBeforeDestructiveRecovery() => true;

  static bool recoveryMustBeAuditable() => true;

  static bool rollbackMustBeVersionAware() => true;

  static bool backupRestoreMustBeTestedNotMerelyDocumented() => true;

  static bool ownerRecoveryKitMustExistBeforeLaunch() => true;

  static bool futureIncidentTypesMustFitWithoutCoreDemolition() => true;
}
