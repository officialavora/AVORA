import 'avora_game_economy_policy.dart';

class AvoraGamePolicyChangeRecord {
  const AvoraGamePolicyChangeRecord({
    required this.changeId,
    required this.actorAvoraId,
    required this.previousVersion,
    required this.newVersion,
    required this.previousRtpBasisPoints,
    required this.newRtpBasisPoints,
    required this.reason,
    required this.createdAtUtc,
  });

  final String changeId;
  final String actorAvoraId;
  final String previousVersion;
  final String newVersion;
  final int previousRtpBasisPoints;
  final int newRtpBasisPoints;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraGamePolicyRegistry {
  AvoraGamePolicyRegistry({
    required AvoraGameEconomyPolicy initialPolicy,
  }) : _activePolicy = initialPolicy;

  AvoraGameEconomyPolicy _activePolicy;
  final Map<String, AvoraGameEconomyPolicy> _versions =
      <String, AvoraGameEconomyPolicy>{};

  final List<AvoraGamePolicyChangeRecord> _changes =
      <AvoraGamePolicyChangeRecord>[];

  AvoraGameEconomyPolicy get activePolicy => _activePolicy;

  List<AvoraGamePolicyChangeRecord> get changeHistory =>
      List<AvoraGamePolicyChangeRecord>.unmodifiable(_changes);

  void registerInitial() {
    _versions[_activePolicy.policyVersion] = _activePolicy;
  }

  AvoraGameEconomyPolicy? byVersion(String version) {
    return _versions[version];
  }

  void changePolicy({
    required String changeId,
    required String actorAvoraId,
    required String newVersion,
    required int newRtpBasisPoints,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (changeId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        newVersion.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('game_policy_change_identity_required');
    }

    if (newRtpBasisPoints < 0 || newRtpBasisPoints > 10000) {
      throw ArgumentError('game_policy_rtp_out_of_range');
    }

    if (_versions.containsKey(newVersion)) {
      throw StateError('game_policy_version_already_exists');
    }

    final previous = _activePolicy;

    final next = AvoraGameEconomyPolicy(
      minimumBet: previous.minimumBet,
      maximumBet: previous.maximumBet,
      policyVersion: newVersion,
      returnBasisPoints: newRtpBasisPoints,
      active: true,
    );

    _versions[newVersion] = next;
    _activePolicy = next;

    _changes.add(
      AvoraGamePolicyChangeRecord(
        changeId: changeId,
        actorAvoraId: actorAvoraId,
        previousVersion: previous.policyVersion,
        newVersion: next.policyVersion,
        previousRtpBasisPoints: previous.returnBasisPoints,
        newRtpBasisPoints: next.returnBasisPoints,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );
  }

  static bool ownerCanAdjustFutureRtp() => true;
  static bool previousPolicyVersionsMustRemainQueryable() => true;
  static bool policyChangesMustBeAudited() => true;
  static bool historicalRoundsMustKeepOriginalPolicyVersion() => true;
  static bool newGamesMustUseActiveUniversalPolicyByDefault() => true;
}
