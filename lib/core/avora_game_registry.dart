enum AvoraGameCategory {
  board,
  party,
  chance,
  skill,
  social,
  other,
}

class AvoraGameDefinition {
  const AvoraGameDefinition({
    required this.gameId,
    required this.displayName,
    required this.category,
    required this.economyEnabled,
    required this.active,
    required this.createdAtUtc,
  });

  final String gameId;
  final String displayName;
  final AvoraGameCategory category;
  final bool economyEnabled;
  final bool active;
  final DateTime createdAtUtc;

  AvoraGameDefinition copyWith({
    String? displayName,
    AvoraGameCategory? category,
    bool? economyEnabled,
    bool? active,
  }) {
    return AvoraGameDefinition(
      gameId: gameId,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      economyEnabled: economyEnabled ?? this.economyEnabled,
      active: active ?? this.active,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraGameRegistryAudit {
  const AvoraGameRegistryAudit({
    required this.auditId,
    required this.gameId,
    required this.actorAvoraId,
    required this.action,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String gameId;
  final String actorAvoraId;
  final String action;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraGameRegistry {
  final Map<String, AvoraGameDefinition> _games =
      <String, AvoraGameDefinition>{};

  final List<AvoraGameRegistryAudit> _audit = <AvoraGameRegistryAudit>[];

  List<AvoraGameDefinition> get games =>
      List<AvoraGameDefinition>.unmodifiable(_games.values);

  List<AvoraGameRegistryAudit> get auditHistory =>
      List<AvoraGameRegistryAudit>.unmodifiable(_audit);

  AvoraGameDefinition? byId(String gameId) {
    return _games[gameId.trim()];
  }

  void register({
    required String auditId,
    required AvoraGameDefinition game,
    required String ownerAvoraId,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    _validateAudit(
      auditId: auditId,
      gameId: game.gameId,
      actorAvoraId: ownerAvoraId,
      reason: reason,
    );

    if (game.displayName.trim().isEmpty) {
      throw ArgumentError('game_display_name_required');
    }

    if (_games.containsKey(game.gameId.trim())) {
      throw StateError('game_already_registered');
    }

    _games[game.gameId.trim()] = game;

    _recordAudit(
      auditId: auditId,
      gameId: game.gameId,
      actorAvoraId: ownerAvoraId,
      action: 'game_registered',
      reason: reason,
      createdAtUtc: createdAtUtc,
    );
  }

  bool canUseCoinEconomy(String gameId) {
    final game = byId(gameId);

    return game != null && game.active && game.economyEnabled;
  }

  void setActive({
    required String auditId,
    required String gameId,
    required bool active,
    required String ownerAvoraId,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    _validateAudit(
      auditId: auditId,
      gameId: gameId,
      actorAvoraId: ownerAvoraId,
      reason: reason,
    );

    final game = byId(gameId);

    if (game == null) {
      throw StateError('game_not_registered');
    }

    _games[game.gameId] = game.copyWith(active: active);

    _recordAudit(
      auditId: auditId,
      gameId: game.gameId,
      actorAvoraId: ownerAvoraId,
      action: active ? 'game_activated' : 'game_deactivated',
      reason: reason,
      createdAtUtc: createdAtUtc,
    );
  }

  void _validateAudit({
    required String auditId,
    required String gameId,
    required String actorAvoraId,
    required String reason,
  }) {
    if (auditId.trim().isEmpty ||
        gameId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('game_registry_audit_required');
    }

    if (_audit.any((item) => item.auditId == auditId)) {
      throw StateError('duplicate_game_registry_audit');
    }
  }

  void _recordAudit({
    required String auditId,
    required String gameId,
    required String actorAvoraId,
    required String action,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    _audit.add(
      AvoraGameRegistryAudit(
        auditId: auditId.trim(),
        gameId: gameId.trim(),
        actorAvoraId: actorAvoraId.trim(),
        action: action,
        reason: reason.trim(),
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );
  }

  static bool unregisteredGameMustNotUseCoins() => true;
  static bool disabledGameMustNotAcceptBets() => true;
  static bool ownerMustControlGameActivation() => true;
  static bool everyGameChangeMustBeAudited() => true;
  static bool futureGamesMustUseCentralRegistry() => true;
  static bool gameIdMustRemainStableAcrossEconomyRecords() => true;
}
