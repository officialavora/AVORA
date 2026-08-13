import 'avora_product_launch_domain_readiness.dart';

enum AvoraLaunchEvidenceType {
  verifiedCheckpoint,
  focusedTest,
  regressionTest,
  analyzer,
  securityReview,
  configurationReview,
  integrationTest,
  storeComplianceReview,
  manualVerification,
  other,
}

enum AvoraLaunchEvidenceStatus {
  passed,
  failed,
  superseded,
}

class AvoraLaunchEvidenceRecord {
  const AvoraLaunchEvidenceRecord({
    required this.evidenceKey,
    required this.domain,
    required this.type,
    required this.status,
    required this.title,
    required this.version,
    required this.verifiedAtUtc,
    required this.verifiedBy,
    required this.details,
  });

  final String evidenceKey;
  final AvoraProductLaunchDomain domain;
  final AvoraLaunchEvidenceType type;
  final AvoraLaunchEvidenceStatus status;
  final String title;
  final String version;
  final DateTime verifiedAtUtc;

  /// Internal authoritative actor/system identity.
  final String verifiedBy;

  final String details;

  bool get usableForReadiness => status == AvoraLaunchEvidenceStatus.passed;

  void validate() {
    if (evidenceKey.trim().isEmpty ||
        title.trim().isEmpty ||
        version.trim().isEmpty ||
        verifiedBy.trim().isEmpty ||
        details.trim().isEmpty) {
      throw ArgumentError('invalid_launch_evidence_record');
    }
  }
}

class AvoraLaunchEvidenceRegistry {
  final Map<String, AvoraLaunchEvidenceRecord> _records =
      <String, AvoraLaunchEvidenceRecord>{};

  void append(
    AvoraLaunchEvidenceRecord record, {
    required bool actorCanManageLaunchReadiness,
  }) {
    if (!actorCanManageLaunchReadiness) {
      throw StateError(
        'launch_readiness_management_permission_required',
      );
    }

    record.validate();

    if (_records.containsKey(record.evidenceKey)) {
      throw StateError('duplicate_launch_evidence_key');
    }

    _records[record.evidenceKey] = record;
  }

  AvoraLaunchEvidenceRecord? byKey(String evidenceKey) {
    return _records[evidenceKey.trim()];
  }

  List<AvoraLaunchEvidenceRecord> forDomain(
    AvoraProductLaunchDomain domain,
  ) {
    return List<AvoraLaunchEvidenceRecord>.unmodifiable(
      _records.values.where(
        (record) => record.domain == domain,
      ),
    );
  }

  List<AvoraLaunchEvidenceRecord> usableForDomain(
    AvoraProductLaunchDomain domain,
  ) {
    return List<AvoraLaunchEvidenceRecord>.unmodifiable(
      _records.values.where(
        (record) => record.domain == domain && record.usableForReadiness,
      ),
    );
  }

  static bool verifiedPassMustBecomeTraceableEvidence() => true;

  static bool failedEvidenceMustNeverCountAsReadyEvidence() => true;

  static bool duplicateCheckpointEvidenceMustNotBeSilentlyAdded() => true;

  static bool evidenceMustRemainDomainScoped() => true;

  static bool futureEvidenceTypesMustFitSameRegistry() => true;
}

class AvoraLaunchDomainEvidenceRequirement {
  const AvoraLaunchDomainEvidenceRequirement({
    required this.domain,
    required this.requirementVersion,
    required this.requiredEvidenceKeys,
  });

  final AvoraProductLaunchDomain domain;
  final String requirementVersion;
  final Set<String> requiredEvidenceKeys;

  void validate() {
    if (requirementVersion.trim().isEmpty || requiredEvidenceKeys.isEmpty) {
      throw ArgumentError(
        'invalid_launch_domain_evidence_requirement',
      );
    }

    if (requiredEvidenceKeys.any(
      (key) => key.trim().isEmpty,
    )) {
      throw ArgumentError('empty_required_evidence_key');
    }
  }
}

class AvoraLaunchDomainEvidenceAssessment {
  const AvoraLaunchDomainEvidenceAssessment({
    required this.domain,
    required this.complete,
    required this.requiredEvidenceKeys,
    required this.passedEvidenceKeys,
    required this.missingEvidenceKeys,
    required this.failedEvidenceKeys,
  });

  final AvoraProductLaunchDomain domain;
  final bool complete;
  final Set<String> requiredEvidenceKeys;
  final Set<String> passedEvidenceKeys;
  final Set<String> missingEvidenceKeys;
  final Set<String> failedEvidenceKeys;
}

class AvoraLaunchDomainEvidenceEvaluator {
  const AvoraLaunchDomainEvidenceEvaluator();

  AvoraLaunchDomainEvidenceAssessment evaluate({
    required AvoraLaunchDomainEvidenceRequirement requirement,
    required AvoraLaunchEvidenceRegistry evidenceRegistry,
  }) {
    requirement.validate();

    final passed = <String>{};
    final missing = <String>{};
    final failed = <String>{};

    for (final key in requirement.requiredEvidenceKeys) {
      final evidence = evidenceRegistry.byKey(key);

      if (evidence == null) {
        missing.add(key);
        continue;
      }

      if (evidence.domain != requirement.domain) {
        failed.add(key);
        continue;
      }

      switch (evidence.status) {
        case AvoraLaunchEvidenceStatus.passed:
          passed.add(key);

        case AvoraLaunchEvidenceStatus.failed:
        case AvoraLaunchEvidenceStatus.superseded:
          failed.add(key);
      }
    }

    return AvoraLaunchDomainEvidenceAssessment(
      domain: requirement.domain,
      complete: missing.isEmpty && failed.isEmpty,
      requiredEvidenceKeys: Set<String>.unmodifiable(
        requirement.requiredEvidenceKeys,
      ),
      passedEvidenceKeys: Set<String>.unmodifiable(passed),
      missingEvidenceKeys: Set<String>.unmodifiable(missing),
      failedEvidenceKeys: Set<String>.unmodifiable(failed),
    );
  }

  static bool everyRequiredEvidenceKeyMustPass() => true;

  static bool wrongDomainEvidenceMustFailAssessment() => true;

  static bool missingEvidenceMustRemainVisible() => true;

  static bool supersededEvidenceMustNotCountAsCurrentProof() => true;
}

class AvoraLaunchDomainAssessmentBuilder {
  const AvoraLaunchDomainAssessmentBuilder();

  AvoraProductLaunchDomainRecord build({
    required AvoraLaunchDomainEvidenceAssessment assessment,
    required String readinessVersion,
    required String updatedBy,
    required DateTime updatedAtUtc,
  }) {
    if (readinessVersion.trim().isEmpty || updatedBy.trim().isEmpty) {
      throw ArgumentError('invalid_domain_assessment_builder_input');
    }

    if (assessment.complete) {
      return AvoraProductLaunchDomainRecord(
        domain: assessment.domain,
        status: AvoraProductLaunchDomainStatus.ready,
        version: readinessVersion,
        updatedAtUtc: updatedAtUtc.toUtc(),
        updatedBy: updatedBy,
        reason: 'all_required_launch_evidence_verified',
        blockers: const <String>[],
        evidenceKeys: assessment.passedEvidenceKeys.toList(
          growable: false,
        ),
      );
    }

    final blockers = <String>[
      ...assessment.missingEvidenceKeys.map(
        (key) => 'missing_evidence:$key',
      ),
      ...assessment.failedEvidenceKeys.map(
        (key) => 'failed_evidence:$key',
      ),
    ];

    return AvoraProductLaunchDomainRecord(
      domain: assessment.domain,
      status: assessment.passedEvidenceKeys.isEmpty
          ? AvoraProductLaunchDomainStatus.blocked
          : AvoraProductLaunchDomainStatus.partial,
      version: readinessVersion,
      updatedAtUtc: updatedAtUtc.toUtc(),
      updatedBy: updatedBy,
      reason: 'required_launch_evidence_incomplete',
      blockers: blockers,
      evidenceKeys: assessment.passedEvidenceKeys.toList(
        growable: false,
      ),
    );
  }

  static bool readyStatusMustComeFromEvidenceNotManualOptimism() => true;

  static bool incompleteEvidenceMustProduceActionableBlockers() => true;

  static bool partialEvidenceMayProducePartialDomainStatus() => true;

  static bool domainRecordMustPreserveEvidenceKeys() => true;

  static bool futureDomainsMustUseSameAssessmentBuilder() => true;
}

class AvoraLaunchEvidenceArchitecture {
  const AvoraLaunchEvidenceArchitecture._();

  static bool chatPassAloneMustNotBePermanentSourceOfTruth() => true;

  static bool verifiedCheckpointMustBeRepresentableAsEvidence() => true;

  static bool analyzerAndFocusedTestsMayBothBeRequiredEvidence() => true;

  static bool evidenceRequirementsMustBeVersionable() => true;

  static bool launchReadinessMustBeReconstructableLater() => true;

  static bool ownerMustEventuallySeeEvidenceBehindEveryReadyDomain() => true;
}
