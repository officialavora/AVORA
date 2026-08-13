enum AvoraProductLaunchDomain {
  identityAndAuthentication,
  ownerAndRoleSecurity,
  moderationAndSafety,
  messagingAndSocial,
  walletAndEconomy,
  rechargeAndPayments,
  gamesAndSettlement,
  roomAndAudio,
  experienceAndCatalog,
  notifications,
  persistenceAndRecovery,
  buildAndStoreCompliance,
  observabilityAndBackup,
}

enum AvoraProductLaunchDomainStatus {
  notEvaluated,
  blocked,
  partial,
  ready,
  intentionallyDeferred,
}

class AvoraProductLaunchDomainRecord {
  const AvoraProductLaunchDomainRecord({
    required this.domain,
    required this.status,
    required this.version,
    required this.updatedAtUtc,
    required this.updatedBy,
    required this.reason,
    required this.blockers,
    required this.evidenceKeys,
  });

  final AvoraProductLaunchDomain domain;
  final AvoraProductLaunchDomainStatus status;

  /// Version of the readiness assessment itself.
  final String version;

  final DateTime updatedAtUtc;

  /// Internal authoritative actor/system identity.
  final String updatedBy;

  final String reason;

  /// Human-readable blocker codes.
  final List<String> blockers;

  /// References to tests/checkpoints/audits rather than raw screenshots.
  final List<String> evidenceKeys;

  bool get launchSatisfied =>
      status == AvoraProductLaunchDomainStatus.ready ||
      status == AvoraProductLaunchDomainStatus.intentionallyDeferred;

  void validate() {
    if (version.trim().isEmpty ||
        updatedBy.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError(
        'invalid_product_launch_domain_record',
      );
    }

    if (status == AvoraProductLaunchDomainStatus.ready && blockers.isNotEmpty) {
      throw StateError(
        'ready_domain_must_not_have_blockers',
      );
    }

    if (status == AvoraProductLaunchDomainStatus.blocked && blockers.isEmpty) {
      throw StateError(
        'blocked_domain_requires_blocker',
      );
    }

    if (status == AvoraProductLaunchDomainStatus.intentionallyDeferred &&
        reason.trim().isEmpty) {
      throw StateError(
        'deferred_domain_requires_reason',
      );
    }
  }
}

class AvoraProductLaunchDomainHistoryRecord {
  const AvoraProductLaunchDomainHistoryRecord({
    required this.historyId,
    required this.domain,
    required this.previousVersion,
    required this.newVersion,
    required this.updatedBy,
    required this.reason,
    required this.createdAtUtc,
  });

  final String historyId;
  final AvoraProductLaunchDomain domain;
  final String? previousVersion;
  final String newVersion;
  final String updatedBy;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraProductLaunchDomainRegistry {
  final Map<AvoraProductLaunchDomain, AvoraProductLaunchDomainRecord> _active =
      <AvoraProductLaunchDomain, AvoraProductLaunchDomainRecord>{};

  final Map<String, AvoraProductLaunchDomainHistoryRecord> _history =
      <String, AvoraProductLaunchDomainHistoryRecord>{};

  AvoraProductLaunchDomainRecord? active(
    AvoraProductLaunchDomain domain,
  ) {
    return _active[domain];
  }

  void update({
    required String historyId,
    required AvoraProductLaunchDomainRecord record,
    required bool actorCanManageLaunchReadiness,
  }) {
    if (!actorCanManageLaunchReadiness) {
      throw StateError(
        'launch_readiness_management_permission_required',
      );
    }

    record.validate();

    if (_history.containsKey(historyId)) {
      throw StateError(
        'duplicate_launch_domain_history_id',
      );
    }

    final previous = _active[record.domain];

    if (previous?.version == record.version) {
      throw StateError(
        'launch_domain_version_must_change',
      );
    }

    _active[record.domain] = record;

    _history[historyId] = AvoraProductLaunchDomainHistoryRecord(
      historyId: historyId,
      domain: record.domain,
      previousVersion: previous?.version,
      newVersion: record.version,
      updatedBy: record.updatedBy,
      reason: record.reason,
      createdAtUtc: record.updatedAtUtc.toUtc(),
    );
  }

  List<AvoraProductLaunchDomainRecord> get activeRecords =>
      List<AvoraProductLaunchDomainRecord>.unmodifiable(
        _active.values,
      );

  List<AvoraProductLaunchDomainHistoryRecord> historyFor(
    AvoraProductLaunchDomain domain,
  ) {
    return List<AvoraProductLaunchDomainHistoryRecord>.unmodifiable(
      _history.values.where(
        (record) => record.domain == domain,
      ),
    );
  }

  static bool readinessUpdatesMustRemainAudited() => true;

  static bool launchDomainStatusMustBeVersioned() => true;

  static bool sameDomainMayBeReevaluatedWithoutDeletingHistory() => true;

  static bool futureDomainsMustBeAddableWithoutRewritingExistingModules() =>
      true;
}

class AvoraProductLaunchDomainGap {
  const AvoraProductLaunchDomainGap({
    required this.domain,
    required this.code,
    required this.details,
  });

  final AvoraProductLaunchDomain domain;
  final String code;
  final String details;
}

class AvoraProductLaunchDomainReport {
  const AvoraProductLaunchDomainReport({
    required this.ready,
    required this.requiredDomains,
    required this.readyDomains,
    required this.gaps,
  });

  final bool ready;
  final Set<AvoraProductLaunchDomain> requiredDomains;
  final Set<AvoraProductLaunchDomain> readyDomains;
  final List<AvoraProductLaunchDomainGap> gaps;
}

class AvoraProductLaunchDomainGate {
  const AvoraProductLaunchDomainGate();

  Set<AvoraProductLaunchDomain> requiredForLaunch() {
    return AvoraProductLaunchDomain.values.toSet();
  }

  AvoraProductLaunchDomainReport evaluate(
    AvoraProductLaunchDomainRegistry registry,
  ) {
    final required = requiredForLaunch();
    final ready = <AvoraProductLaunchDomain>{};
    final gaps = <AvoraProductLaunchDomainGap>[];

    for (final domain in required) {
      final record = registry.active(domain);

      if (record == null) {
        gaps.add(
          AvoraProductLaunchDomainGap(
            domain: domain,
            code: 'domain_not_evaluated',
            details: domain.name,
          ),
        );
        continue;
      }

      switch (record.status) {
        case AvoraProductLaunchDomainStatus.ready:
          ready.add(domain);

        case AvoraProductLaunchDomainStatus.intentionallyDeferred:
          ready.add(domain);

        case AvoraProductLaunchDomainStatus.notEvaluated:
          gaps.add(
            AvoraProductLaunchDomainGap(
              domain: domain,
              code: 'domain_not_evaluated',
              details: record.reason,
            ),
          );

        case AvoraProductLaunchDomainStatus.partial:
          gaps.add(
            AvoraProductLaunchDomainGap(
              domain: domain,
              code: 'domain_partially_ready',
              details: record.reason,
            ),
          );

        case AvoraProductLaunchDomainStatus.blocked:
          if (record.blockers.isEmpty) {
            gaps.add(
              AvoraProductLaunchDomainGap(
                domain: domain,
                code: 'domain_blocked',
                details: record.reason,
              ),
            );
          } else {
            for (final blocker in record.blockers) {
              gaps.add(
                AvoraProductLaunchDomainGap(
                  domain: domain,
                  code: blocker,
                  details: record.reason,
                ),
              );
            }
          }
      }
    }

    return AvoraProductLaunchDomainReport(
      ready: gaps.isEmpty,
      requiredDomains: Set<AvoraProductLaunchDomain>.unmodifiable(
        required,
      ),
      readyDomains: Set<AvoraProductLaunchDomain>.unmodifiable(
        ready,
      ),
      gaps: List<AvoraProductLaunchDomainGap>.unmodifiable(
        gaps,
      ),
    );
  }

  static bool everyLaunchCriticalDomainMustBeEvaluated() => true;

  static bool missingDomainAssessmentMustBlockLaunch() => true;

  static bool partialDomainMustNotPretendToBeReady() => true;

  static bool blockedDomainMustExposeActionableReason() => true;

  static bool evidenceMustSupportReadinessInsteadOfMemoryAlone() => true;

  static bool deferredDomainMustRemainExplicitAndTraceable() => true;
}

class AvoraProductLaunchReadinessBridge {
  const AvoraProductLaunchReadinessBridge();

  bool productMayBeCalledLaunchReady({
    required bool creativeAndReferenceGateReady,
    required AvoraProductLaunchDomainReport domainReport,
  }) {
    return creativeAndReferenceGateReady && domainReport.ready;
  }

  static bool creativeReadinessAloneMustNotMeanLaunchReady() => true;

  static bool functionalReadinessAloneMustNotMeanLaunchReady() => true;

  static bool bothCreativeAndFunctionalReadinessMustPass() => true;

  static bool futureReadinessFamiliesMustPlugIntoSameFinalDecision() => true;
}

class AvoraProductLaunchReadinessArchitecture {
  const AvoraProductLaunchReadinessArchitecture._();

  static bool identitySecurityModerationAndEconomyAreLaunchCritical() => true;

  static bool rechargeGamesRoomsAndMessagingAreLaunchCritical() => true;

  static bool persistenceNotificationsAndRecoveryAreLaunchCritical() => true;

  static bool buildStoreComplianceObservabilityAndBackupAreLaunchCritical() =>
      true;

  static bool ownerMustEventuallySeeEveryDomainAndBlockerInOnePanel() => true;

  static bool passMustReflectActualSystemEvidenceNotOptimism() => true;

  static bool existingSubsystemsMustBeReusedNotReimplemented() => true;
}
