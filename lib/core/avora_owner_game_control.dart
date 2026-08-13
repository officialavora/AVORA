enum AvoraGameAvailabilityScope {
  global,
  selectedCountries,
  disabled,
}

class AvoraOwnerGameControlPolicy {
  const AvoraOwnerGameControlPolicy({
    required this.gameId,
    required this.version,
    required this.scope,
    required this.countryCodes,
    required this.minBetCoins,
    required this.maxBetCoins,
    required this.jackpotEnabled,
    required this.specialEventsEnabled,
    required this.createdAtUtc,
    required this.createdByOwnerAvoraId,
  });

  final String gameId;
  final String version;
  final AvoraGameAvailabilityScope scope;
  final Set<String> countryCodes;

  final int minBetCoins;
  final int maxBetCoins;

  final bool jackpotEnabled;
  final bool specialEventsEnabled;

  final DateTime createdAtUtc;

  /// Internal authoritative Owner identity.
  /// Never use this field as public Owner presentation.
  final String createdByOwnerAvoraId;

  void validate() {
    if (gameId.trim().isEmpty ||
        version.trim().isEmpty ||
        createdByOwnerAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_owner_game_control_identity');
    }

    if (minBetCoins <= 0 || maxBetCoins <= 0 || maxBetCoins < minBetCoins) {
      throw ArgumentError('invalid_owner_game_bet_limits');
    }

    if (scope == AvoraGameAvailabilityScope.selectedCountries &&
        countryCodes.isEmpty) {
      throw ArgumentError('selected_country_scope_requires_country');
    }
  }

  bool isAvailableInCountry(String countryCode) {
    switch (scope) {
      case AvoraGameAvailabilityScope.global:
        return true;

      case AvoraGameAvailabilityScope.selectedCountries:
        return countryCodes.contains(
          countryCode.trim().toUpperCase(),
        );

      case AvoraGameAvailabilityScope.disabled:
        return false;
    }
  }

  bool acceptsBet(int coins) {
    return coins >= minBetCoins && coins <= maxBetCoins;
  }
}

class AvoraOwnerGameControlAuditRecord {
  const AvoraOwnerGameControlAuditRecord({
    required this.auditId,
    required this.gameId,
    required this.previousVersion,
    required this.newVersion,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String gameId;
  final String? previousVersion;
  final String newVersion;

  /// Internal only.
  final String ownerAvoraId;

  final String reason;
  final DateTime createdAtUtc;
}

class AvoraOwnerGameControlAuditLedger {
  final Map<String, AvoraOwnerGameControlAuditRecord> _records =
      <String, AvoraOwnerGameControlAuditRecord>{};

  void append(AvoraOwnerGameControlAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.gameId.trim().isEmpty ||
        record.newVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_owner_game_control_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_owner_game_control_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraOwnerGameControlAuditRecord> forGame(
    String gameId,
  ) {
    return List<AvoraOwnerGameControlAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.gameId == gameId,
      ),
    );
  }

  static bool everyOwnerGameChangeMustBeAudited() => true;

  static bool auditHistoryMustRemainImmutable() => true;

  static bool auditMustPreserveAuthoritativeOwnerIdentity() => true;

  static bool publicOwnerPresentationMustRemainOwnerOnly() => true;
}

class AvoraOwnerGameControlRegistry {
  AvoraOwnerGameControlRegistry({
    required AvoraOwnerGameControlAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraOwnerGameControlAuditLedger _auditLedger;

  final Map<String, AvoraOwnerGameControlPolicy> _active =
      <String, AvoraOwnerGameControlPolicy>{};

  final Map<String, Map<String, AvoraOwnerGameControlPolicy>> _history =
      <String, Map<String, AvoraOwnerGameControlPolicy>>{};

  AvoraOwnerGameControlPolicy? activeFor(String gameId) {
    return _active[gameId.trim()];
  }

  AvoraOwnerGameControlPolicy? historical({
    required String gameId,
    required String version,
  }) {
    final active = _active[gameId];

    if (active?.version == version) {
      return active;
    }

    return _history[gameId]?[version];
  }

  void activate({
    required String auditId,
    required AvoraOwnerGameControlPolicy policy,
    required bool actorIsVerifiedOwner,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    policy.validate();

    final previous = _active[policy.gameId];

    if (previous?.version == policy.version) {
      throw StateError('game_control_version_must_change');
    }

    if (previous != null) {
      _history.putIfAbsent(
        policy.gameId,
        () => <String, AvoraOwnerGameControlPolicy>{},
      )[previous.version] = previous;
    }

    _active[policy.gameId] = policy;

    _auditLedger.append(
      AvoraOwnerGameControlAuditRecord(
        auditId: auditId,
        gameId: policy.gameId,
        previousVersion: previous?.version,
        newVersion: policy.version,
        ownerAvoraId: policy.createdByOwnerAvoraId,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );
  }

  static bool onlyVerifiedOwnerMayChangeGameControl() => true;

  static bool ownerMayEnableOrDisableAnyGame() => true;

  static bool ownerMayControlCountryAvailability() => true;

  static bool ownerMayControlBetLimits() => true;

  static bool ownerMayControlJackpotAvailability() => true;

  static bool ownerMayControlSpecialEvents() => true;

  static bool historicalGameControlMustNeverBeRewritten() => true;

  static bool futureGamesMustUseSameControlRegistry() => true;
}

class AvoraGameLaunchControlGuard {
  const AvoraGameLaunchControlGuard();

  void validate({
    required AvoraOwnerGameControlPolicy policy,
    required String gameId,
    required String countryCode,
    required int betCoins,
  }) {
    if (policy.gameId != gameId) {
      throw StateError('game_control_policy_mismatch');
    }

    if (!policy.isAvailableInCountry(countryCode)) {
      throw StateError('game_not_available_in_country');
    }

    if (!policy.acceptsBet(betCoins)) {
      throw StateError('game_bet_outside_owner_limits');
    }
  }

  static bool everyGameLaunchMustPassOwnerControl() => true;

  static bool disabledGameMustFailClosed() => true;

  static bool countryRestrictionMustBeServerAuthoritative() => true;

  static bool betLimitsMustBeServerAuthoritative() => true;

  static bool clientMustNeverOverrideOwnerGameControl() => true;

  static bool futureGamesMustUseSameLaunchGuard() => true;
}
