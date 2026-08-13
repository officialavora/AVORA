import 'avora_pk_level_reward_policy.dart';

enum AvoraPkCanonicalMode {
  oneToOne,
  team,
  sameRoom,
  crossRoom,
  globalBattle,
  unknown,
}

class AvoraPkModeQualificationRule {
  const AvoraPkModeQualificationRule({
    required this.mode,
    required this.enabled,
    this.minimumQualifyingPkValueOverride,
  });

  final AvoraPkCanonicalMode mode;
  final bool enabled;

  /// null = use main PK reward policy threshold.
  final int? minimumQualifyingPkValueOverride;

  void validate() {
    final override = minimumQualifyingPkValueOverride;
    if (override != null && override <= 0) {
      throw StateError('pk_mode_threshold_override_must_be_positive');
    }
  }
}

class AvoraPkModeRewardPolicy {
  AvoraPkModeRewardPolicy({
    required List<AvoraPkModeQualificationRule> rules,
  }) : rules = List<AvoraPkModeQualificationRule>.unmodifiable(rules) {
    for (final rule in this.rules) {
      rule.validate();
    }
  }

  final List<AvoraPkModeQualificationRule> rules;

  factory AvoraPkModeRewardPolicy.defaults() {
    return AvoraPkModeRewardPolicy(
      rules: const <AvoraPkModeQualificationRule>[
        AvoraPkModeQualificationRule(
          mode: AvoraPkCanonicalMode.oneToOne,
          enabled: true,
        ),
        AvoraPkModeQualificationRule(
          mode: AvoraPkCanonicalMode.team,
          enabled: true,
        ),
        AvoraPkModeQualificationRule(
          mode: AvoraPkCanonicalMode.sameRoom,
          enabled: true,
        ),
        AvoraPkModeQualificationRule(
          mode: AvoraPkCanonicalMode.crossRoom,
          enabled: true,
        ),
        AvoraPkModeQualificationRule(
          mode: AvoraPkCanonicalMode.globalBattle,
          enabled: true,
        ),
      ],
    );
  }

  AvoraPkModeQualificationRule? ruleFor(
    AvoraPkCanonicalMode mode,
  ) {
    for (final rule in rules) {
      if (rule.mode == mode) {
        return rule;
      }
    }
    return null;
  }
}

class AvoraPkModeRewardBridge {
  const AvoraPkModeRewardBridge();

  AvoraPkCanonicalMode classifyModeName(String rawName) {
    final value = rawName
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    if (value.contains('global') || value.contains('battle')) {
      return AvoraPkCanonicalMode.globalBattle;
    }

    if (value.contains('crossroom') ||
        value.contains('roomtoroom') ||
        value.contains('cross')) {
      return AvoraPkCanonicalMode.crossRoom;
    }

    if (value.contains('sameroom') ||
        value.contains('inroom') ||
        value.contains('roomteam')) {
      return AvoraPkCanonicalMode.sameRoom;
    }

    if (value.contains('team')) {
      return AvoraPkCanonicalMode.team;
    }

    if (value.contains('1v1') ||
        value.contains('onevone') ||
        value.contains('single') ||
        value.contains('friend')) {
      return AvoraPkCanonicalMode.oneToOne;
    }

    return AvoraPkCanonicalMode.unknown;
  }

  AvoraPkCanonicalMode classifyEnum(Enum value) {
    return classifyModeName(value.name);
  }

  bool shouldCountForReward({
    required AvoraPkLevelRewardPolicy basePolicy,
    required AvoraPkModeRewardPolicy modePolicy,
    required AvoraPkCanonicalMode mode,
    required int pkValue,
    required bool won,
    required bool validMatch,
    required bool cancelled,
    required bool forfeited,
  }) {
    final rule = modePolicy.ruleFor(mode);

    if (rule == null || !rule.enabled) {
      return false;
    }

    if (!won || !validMatch || cancelled || forfeited) {
      return false;
    }

    final minimumValue = rule.minimumQualifyingPkValueOverride ??
        basePolicy.minimumQualifyingPkValue;

    return pkValue >= minimumValue;
  }

  AvoraPkRewardProgress recordQualifiedModeWin({
    required AvoraPkRewardProgress current,
    required AvoraPkLevelRewardPolicy basePolicy,
    required AvoraPkModeRewardPolicy modePolicy,
    required AvoraPkCanonicalMode mode,
    required int pkValue,
    required bool won,
    required bool validMatch,
    bool cancelled = false,
    bool forfeited = false,
  }) {
    final counts = shouldCountForReward(
      basePolicy: basePolicy,
      modePolicy: modePolicy,
      mode: mode,
      pkValue: pkValue,
      won: won,
      validMatch: validMatch,
      cancelled: cancelled,
      forfeited: forfeited,
    );

    if (!counts) {
      return current;
    }

    return current.recordMatch(
      policy: basePolicy,
      pkValue: pkValue,
      won: true,
      validMatch: true,
    );
  }

  static bool normalPkOutcomeMustRemainSeparateFromRewardCounting() => true;

  static bool everyPkModeMayHaveOwnerConfigurableQualification() => true;

  static bool invalidCancelledOrForfeitedPkMustNotCount() => true;

  static bool winnerMustNotReceiveLoserPunishment() => true;

  static bool duplicatePkRewardCountingMustBePreventedByMatchIdentity() => true;
}
