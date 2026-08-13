enum AvoraLaunchCriticalModule {
  authentication,
  immutableAvoraId,
  profile,
  homeDiscovery,
  roomCreateJoin,
  realtimeVoice,
  roomSeatsAndMic,
  roomModeration,
  roomLock,
  wallet,
  recharge,
  masterCoinLedger,
  gifts,
  inboxMessaging,
  roomMessaging,
  ownerControls,
  officialPermissions,
  backendPersistence,
  realtimePersistence,
  notifications,
  oneLaunchGame,
  crashRecovery,
  networkRecovery,
  productionSecurity,
  privacyAndTerms,
  androidReleaseBuild,
  testerValidation,
}

class AvoraLaunchModuleStatus {
  const AvoraLaunchModuleStatus({
    required this.module,
    required this.ready,
    required this.evidence,
  });

  final AvoraLaunchCriticalModule module;
  final bool ready;
  final String evidence;
}

class AvoraLaunchReadinessReport {
  const AvoraLaunchReadinessReport({
    required this.readyForLaunch,
    required this.readyCount,
    required this.totalCount,
    required this.blockers,
  });

  final bool readyForLaunch;
  final int readyCount;
  final int totalCount;
  final List<AvoraLaunchCriticalModule> blockers;

  double get completionPercent {
    if (totalCount == 0) return 0;
    return (readyCount / totalCount) * 100;
  }
}

class AvoraLaunchReadinessGate {
  const AvoraLaunchReadinessGate();

  AvoraLaunchReadinessReport evaluate(
    Iterable<AvoraLaunchModuleStatus> statuses,
  ) {
    final byModule = <AvoraLaunchCriticalModule, AvoraLaunchModuleStatus>{};

    for (final status in statuses) {
      if (byModule.containsKey(status.module)) {
        throw StateError('duplicate_launch_module_status');
      }

      byModule[status.module] = status;
    }

    final blockers = <AvoraLaunchCriticalModule>[];
    var readyCount = 0;

    for (final module in AvoraLaunchCriticalModule.values) {
      final status = byModule[module];

      if (status != null && status.ready && status.evidence.trim().isNotEmpty) {
        readyCount++;
      } else {
        blockers.add(module);
      }
    }

    return AvoraLaunchReadinessReport(
      readyForLaunch: blockers.isEmpty,
      readyCount: readyCount,
      totalCount: AvoraLaunchCriticalModule.values.length,
      blockers: List<AvoraLaunchCriticalModule>.unmodifiable(blockers),
    );
  }

  static bool policyTestsAloneMustNotMarkAppLaunchReady() => true;

  static bool launchRequiresWorkingUserFacingFlow() => true;

  static bool launchRequiresRealBackendPersistence() => true;

  static bool launchRequiresWorkingCoinMonetization() => true;

  static bool launchRequiresOwnerOperationalControls() => true;

  static bool launchRequiresAtLeastOneWorkingGame() => true;

  static bool nonCriticalGamesMayShipAfterLaunch() => true;

  static bool everyCriticalModuleNeedsEvidenceBeforeReady() => true;
}
