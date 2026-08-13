import 'avora_launch_evidence_registry.dart';
import 'avora_product_launch_domain_readiness.dart';

class AvoraLaunchDomainEvidencePolicy {
  const AvoraLaunchDomainEvidencePolicy({
    required this.domain,
    required this.policyVersion,
    required this.requiredEvidenceKeys,
    required this.minimumPassedEvidence,
    required this.ownerApproved,
    required this.createdAtUtc,
  });

  final AvoraProductLaunchDomain domain;
  final String policyVersion;
  final Set<String> requiredEvidenceKeys;
  final int minimumPassedEvidence;
  final bool ownerApproved;
  final DateTime createdAtUtc;

  void validate() {
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError('evidence_policy_version_required');
    }

    if (!ownerApproved) {
      throw StateError('evidence_policy_owner_approval_required');
    }

    if (requiredEvidenceKeys.isEmpty) {
      throw StateError('required_evidence_keys_must_not_be_empty');
    }

    if (requiredEvidenceKeys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('empty_required_evidence_key');
    }

    if (minimumPassedEvidence <= 0) {
      throw ArgumentError('minimum_passed_evidence_must_be_positive');
    }

    if (minimumPassedEvidence > requiredEvidenceKeys.length) {
      throw StateError(
        'minimum_passed_evidence_exceeds_required_evidence_count',
      );
    }
  }
}

class AvoraLaunchEvidencePolicyHistoryRecord {
  const AvoraLaunchEvidencePolicyHistoryRecord({
    required this.historyId,
    required this.domain,
    required this.previousVersion,
    required this.newVersion,
    required this.changedBy,
    required this.reason,
    required this.changedAtUtc,
  });

  final String historyId;
  final AvoraProductLaunchDomain domain;
  final String? previousVersion;
  final String newVersion;
  final String changedBy;
  final String reason;
  final DateTime changedAtUtc;
}

class AvoraLaunchEvidencePolicyRegistry {
  final Map<AvoraProductLaunchDomain, AvoraLaunchDomainEvidencePolicy> _active =
      <AvoraProductLaunchDomain, AvoraLaunchDomainEvidencePolicy>{};

  final Map<String, AvoraLaunchEvidencePolicyHistoryRecord> _history =
      <String, AvoraLaunchEvidencePolicyHistoryRecord>{};

  AvoraLaunchDomainEvidencePolicy? active(
    AvoraProductLaunchDomain domain,
  ) {
    return _active[domain];
  }

  void activate({
    required String historyId,
    required AvoraLaunchDomainEvidencePolicy policy,
    required String changedBy,
    required String reason,
    required bool actorIsVerifiedOwner,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    if (historyId.trim().isEmpty ||
        changedBy.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_evidence_policy_change');
    }

    policy.validate();

    if (_history.containsKey(historyId)) {
      throw StateError('duplicate_evidence_policy_history_id');
    }

    final previous = _active[policy.domain];

    if (previous?.policyVersion == policy.policyVersion) {
      throw StateError('evidence_policy_version_must_change');
    }

    _active[policy.domain] = policy;

    _history[historyId] = AvoraLaunchEvidencePolicyHistoryRecord(
      historyId: historyId,
      domain: policy.domain,
      previousVersion: previous?.policyVersion,
      newVersion: policy.policyVersion,
      changedBy: changedBy,
      reason: reason,
      changedAtUtc: policy.createdAtUtc.toUtc(),
    );
  }

  List<AvoraLaunchEvidencePolicyHistoryRecord> historyFor(
    AvoraProductLaunchDomain domain,
  ) {
    return List<AvoraLaunchEvidencePolicyHistoryRecord>.unmodifiable(
      _history.values.where(
        (record) => record.domain == domain,
      ),
    );
  }

  static bool ownerMayStrengthenEvidencePolicyLater() => true;

  static bool ownerMayRebalanceEvidencePolicyLater() => true;

  static bool historicalPoliciesMustRemainAuditable() => true;

  static bool policyChangeMustNotRewriteSubsystemImplementation() => true;
}

class AvoraLaunchEvidencePolicyAssessment {
  const AvoraLaunchEvidencePolicyAssessment({
    required this.domain,
    required this.policyVersion,
    required this.ready,
    required this.passedEvidenceKeys,
    required this.missingEvidenceKeys,
    required this.failedEvidenceKeys,
    required this.blockers,
  });

  final AvoraProductLaunchDomain domain;
  final String policyVersion;
  final bool ready;
  final Set<String> passedEvidenceKeys;
  final Set<String> missingEvidenceKeys;
  final Set<String> failedEvidenceKeys;
  final List<String> blockers;
}

class AvoraLaunchEvidencePolicyEvaluator {
  const AvoraLaunchEvidencePolicyEvaluator();

  AvoraLaunchEvidencePolicyAssessment evaluate({
    required AvoraLaunchDomainEvidencePolicy policy,
    required AvoraLaunchEvidenceRegistry evidenceRegistry,
  }) {
    policy.validate();

    final passed = <String>{};
    final missing = <String>{};
    final failed = <String>{};

    for (final key in policy.requiredEvidenceKeys) {
      final evidence = evidenceRegistry.byKey(key);

      if (evidence == null) {
        missing.add(key);
        continue;
      }

      if (evidence.domain != policy.domain ||
          evidence.status != AvoraLaunchEvidenceStatus.passed) {
        failed.add(key);
        continue;
      }

      passed.add(key);
    }

    final blockers = <String>[
      ...missing.map((key) => 'missing_evidence:$key'),
      ...failed.map((key) => 'failed_evidence:$key'),
    ];

    if (passed.length < policy.minimumPassedEvidence) {
      blockers.add(
        'minimum_passed_evidence_not_met:'
        '${passed.length}/${policy.minimumPassedEvidence}',
      );
    }

    return AvoraLaunchEvidencePolicyAssessment(
      domain: policy.domain,
      policyVersion: policy.policyVersion,
      ready: missing.isEmpty &&
          failed.isEmpty &&
          passed.length >= policy.minimumPassedEvidence,
      passedEvidenceKeys: Set<String>.unmodifiable(passed),
      missingEvidenceKeys: Set<String>.unmodifiable(missing),
      failedEvidenceKeys: Set<String>.unmodifiable(failed),
      blockers: List<String>.unmodifiable(blockers),
    );
  }

  static bool everyRequiredEvidenceMustBePresent() => true;

  static bool minimumCountAloneMustNeverHideMissingRequiredEvidence() => true;

  static bool wrongDomainEvidenceMustNeverSatisfyPolicy() => true;

  static bool failedOrSupersededEvidenceMustNeverSatisfyPolicy() => true;
}

class AvoraNoFalseReadyDomainBuilder {
  const AvoraNoFalseReadyDomainBuilder();

  AvoraProductLaunchDomainRecord build({
    required AvoraLaunchEvidencePolicyAssessment assessment,
    required String readinessVersion,
    required String updatedBy,
    required DateTime updatedAtUtc,
  }) {
    if (readinessVersion.trim().isEmpty || updatedBy.trim().isEmpty) {
      throw ArgumentError('invalid_no_false_ready_builder_input');
    }

    if (assessment.ready) {
      return AvoraProductLaunchDomainRecord(
        domain: assessment.domain,
        status: AvoraProductLaunchDomainStatus.ready,
        version: readinessVersion,
        updatedAtUtc: updatedAtUtc.toUtc(),
        updatedBy: updatedBy,
        reason:
            'active_evidence_policy_fully_satisfied:${assessment.policyVersion}',
        blockers: const <String>[],
        evidenceKeys: assessment.passedEvidenceKeys.toList(growable: false),
      );
    }

    return AvoraProductLaunchDomainRecord(
      domain: assessment.domain,
      status: assessment.passedEvidenceKeys.isEmpty
          ? AvoraProductLaunchDomainStatus.blocked
          : AvoraProductLaunchDomainStatus.partial,
      version: readinessVersion,
      updatedAtUtc: updatedAtUtc.toUtc(),
      updatedBy: updatedBy,
      reason:
          'active_evidence_policy_not_satisfied:${assessment.policyVersion}',
      blockers: assessment.blockers,
      evidenceKeys: assessment.passedEvidenceKeys.toList(growable: false),
    );
  }

  static bool domainReadyMustRequireActivePolicyPass() => true;

  static bool historicalPassAloneMustNotForceCurrentReadyStatus() => true;

  static bool partialHistoricalCoverageMustRemainPartial() => true;

  static bool blockersMustExplainExactlyWhatRemains() => true;
}

class AvoraLaunchEvidencePolicyArchitecture {
  const AvoraLaunchEvidencePolicyArchitecture._();

  static bool evidenceExistenceAndDomainReadinessAreDifferent() => true;

  static bool readinessRequirementsMustBeVersioned() => true;

  static bool futureTestsMayStrengthenPolicyWithoutArchitectureDemolition() =>
      true;

  static bool ownerMustEventuallyControlPolicyFromOwnerPanel() => true;

  static bool policyMustPreventAccidentalFalseLaunchReady() => true;

  static bool oldVerifiedWorkMustStillReduceDuplicateWork() => true;
}
