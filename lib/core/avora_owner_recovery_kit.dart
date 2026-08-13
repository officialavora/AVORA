import 'avora_incident_diagnostics.dart';
import 'avora_incident_response_orchestrator.dart';

class AvoraOwnerRecoveryKitSummary {
  const AvoraOwnerRecoveryKitSummary({
    required this.incidentId,
    required this.category,
    required this.severity,
    required this.status,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.occurredAtUtc,
    required this.summary,
    required this.referenceKeys,
    required this.attachmentIds,
  });

  final String incidentId;
  final AvoraIncidentCategory category;
  final AvoraIncidentSeverity severity;
  final AvoraIncidentStatus status;

  final String appVersion;
  final String buildNumber;
  final String platform;
  final DateTime occurredAtUtc;

  final String summary;

  final Map<String, String> referenceKeys;
  final List<String> attachmentIds;
}

class AvoraOwnerRecoveryTimelineItem {
  const AvoraOwnerRecoveryTimelineItem({
    required this.eventId,
    required this.action,
    required this.createdAtUtc,
    required this.details,
  });

  final String eventId;
  final AvoraIncidentResponseAction action;
  final DateTime createdAtUtc;
  final String details;
}

class AvoraOwnerRecoverySupportBundle {
  const AvoraOwnerRecoverySupportBundle({
    required this.bundleId,
    required this.createdAtUtc,
    required this.createdBy,
    required this.summary,
    required this.timeline,
    required this.safeDiagnosticFields,
    required this.redactedFieldNames,
  });

  final String bundleId;
  final DateTime createdAtUtc;

  /// Internal actor identity only.
  final String createdBy;

  final AvoraOwnerRecoveryKitSummary summary;
  final List<AvoraOwnerRecoveryTimelineItem> timeline;

  /// Safe, non-secret support fields only.
  final Map<String, String> safeDiagnosticFields;

  /// Explicit record of fields intentionally excluded.
  final Set<String> redactedFieldNames;
}

class AvoraOwnerRecoveryBundleBuilder {
  const AvoraOwnerRecoveryBundleBuilder();

  AvoraOwnerRecoverySupportBundle build({
    required String bundleId,
    required AvoraOwnerIncidentReport report,
    required AvoraIncidentLifecycleRecord lifecycle,
    required List<AvoraIncidentResponseEvent> timeline,
    required String createdBy,
    required DateTime createdAtUtc,
  }) {
    report.validate();
    lifecycle.validate();

    if (bundleId.trim().isEmpty || createdBy.trim().isEmpty) {
      throw ArgumentError(
        'invalid_owner_recovery_bundle_identity',
      );
    }

    if (lifecycle.incidentId != report.incidentId) {
      throw StateError(
        'recovery_bundle_incident_mismatch',
      );
    }

    for (final event in timeline) {
      if (event.incidentId != report.incidentId) {
        throw StateError(
          'recovery_bundle_timeline_incident_mismatch',
        );
      }
    }

    final envelope = const AvoraIncidentDiagnosticEnvelopeBuilder().build(
      report,
    );

    final safeFields = <String, String>{
      'correlationId': envelope.correlationId,
      'appVersion': envelope.appVersion,
      'buildNumber': envelope.buildNumber,
      'platform': envelope.platform,
      ...envelope.referenceKeys,
    };

    final timelineItems = timeline
        .map(
          (event) => AvoraOwnerRecoveryTimelineItem(
            eventId: event.eventId,
            action: event.action,
            createdAtUtc: event.createdAtUtc.toUtc(),
            details: event.details,
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.createdAtUtc.compareTo(b.createdAtUtc),
      );

    return AvoraOwnerRecoverySupportBundle(
      bundleId: bundleId,
      createdAtUtc: createdAtUtc.toUtc(),
      createdBy: createdBy,
      summary: AvoraOwnerRecoveryKitSummary(
        incidentId: report.incidentId,
        category: report.category,
        severity: report.severity,
        status: lifecycle.status,
        appVersion: report.environment.appVersion,
        buildNumber: report.environment.buildNumber,
        platform: report.environment.platform,
        occurredAtUtc: report.environment.occurredAtUtc.toUtc(),
        summary: report.whatHappened.trim(),
        referenceKeys: Map<String, String>.unmodifiable(
          envelope.referenceKeys,
        ),
        attachmentIds: List<String>.unmodifiable(
          envelope.attachmentIds,
        ),
      ),
      timeline: List<AvoraOwnerRecoveryTimelineItem>.unmodifiable(
        timelineItems,
      ),
      safeDiagnosticFields: Map<String, String>.unmodifiable(safeFields),
      redactedFieldNames: Set<String>.unmodifiable(
        AvoraIncidentPrivacyPolicy.forbiddenDiagnosticFields,
      ),
    );
  }

  static bool ownerMayExportSupportBundleByIncidentId() => true;

  static bool bundleMustContainBuildAndVersionContext() => true;

  static bool bundleMustContainIncidentTimeline() => true;

  static bool bundleMustContainSafeReferenceKeys() => true;

  static bool bundleMustNeverRequireOwnerTechnicalVocabulary() => true;

  static bool bundleMustNeverContainForbiddenSecrets() => true;

  static bool futureSupportSystemsMustUseSameBundleContract() => true;
}

class AvoraOwnerRecoveryKitChecklist {
  const AvoraOwnerRecoveryKitChecklist({
    required this.sourceCodeBackupAvailable,
    required this.signingBackupAvailable,
    required this.releaseHistoryAvailable,
    required this.backupRestoreProcedureAvailable,
    required this.rollbackProcedureAvailable,
    required this.incidentReportingGuideAvailable,
    required this.paymentInvestigationGuideAvailable,
    required this.ledgerReconciliationGuideAvailable,
    required this.roleCompromiseGuideAvailable,
    required this.databaseRecoveryGuideAvailable,
    required this.buildAndSigningGuideAvailable,
  });

  final bool sourceCodeBackupAvailable;
  final bool signingBackupAvailable;
  final bool releaseHistoryAvailable;
  final bool backupRestoreProcedureAvailable;
  final bool rollbackProcedureAvailable;
  final bool incidentReportingGuideAvailable;
  final bool paymentInvestigationGuideAvailable;
  final bool ledgerReconciliationGuideAvailable;
  final bool roleCompromiseGuideAvailable;
  final bool databaseRecoveryGuideAvailable;
  final bool buildAndSigningGuideAvailable;

  bool get complete =>
      sourceCodeBackupAvailable &&
      signingBackupAvailable &&
      releaseHistoryAvailable &&
      backupRestoreProcedureAvailable &&
      rollbackProcedureAvailable &&
      incidentReportingGuideAvailable &&
      paymentInvestigationGuideAvailable &&
      ledgerReconciliationGuideAvailable &&
      roleCompromiseGuideAvailable &&
      databaseRecoveryGuideAvailable &&
      buildAndSigningGuideAvailable;
}

class AvoraOwnerRecoveryKitGate {
  const AvoraOwnerRecoveryKitGate();

  void assertLaunchReady(
    AvoraOwnerRecoveryKitChecklist checklist,
  ) {
    if (!checklist.complete) {
      throw StateError(
        'owner_recovery_kit_incomplete',
      );
    }
  }

  static bool recoveryKitMustExistBeforeLaunch() => true;

  static bool signingRecoveryMustBeIncluded() => true;

  static bool paymentAndLedgerRecoveryMustBeIncluded() => true;

  static bool databaseAndReleaseRecoveryMustBeIncluded() => true;

  static bool ownerInstructionsMustBeSimpleAndCopyPasteFriendly() => true;
}

class AvoraOwnerIncidentReportingTemplate {
  const AvoraOwnerIncidentReportingTemplate._();

  static const List<String> minimumOwnerInputs = <String>[
    'incidentId_or_new_report',
    'what_happened',
    'what_should_have_happened',
    'approximate_time',
  ];

  static const List<String> helpfulOptionalInputs = <String>[
    'screenshot_or_video',
    'avora_id',
    'room_id',
    'order_id',
    'payment_reference',
    'game_round_id',
    'message_id',
  ];

  static bool screenshotAndSimpleDescriptionAreEnoughToStart() => true;

  static bool ownerNeedNotKnowLogsDatabaseOrCode() => true;

  static bool missingOptionalReferenceMustNotBlockInitialReport() => true;
}

class AvoraOwnerRecoveryArchitecture {
  const AvoraOwnerRecoveryArchitecture._();

  static bool incidentIdMustBeEnoughToLocateSupportContext() => true;

  static bool supportBundleMustBeSafeToShareWithTrustedDeveloper() => true;

  static bool ownerPrivateIdentityMustRemainMasked() => true;

  static bool recoveryDocumentationMustSurviveChatChanges() => true;

  static bool recoveryKitMustBeVersionedWithProjectReleases() => true;

  static bool finalHandoverMustIncludeOperationalRecoveryMaterial() => true;
}
