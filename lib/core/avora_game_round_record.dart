class AvoraGameRoundRecord {
  const AvoraGameRoundRecord({
    required this.roundId,
    required this.gameId,
    required this.userAvoraId,
    required this.betCoins,
    required this.payoutCoins,
    required this.policyVersion,
    required this.rtpBasisPoints,
    required this.createdAtUtc,
    this.failureReason,
  });

  final String roundId;
  final String gameId;
  final String userAvoraId;

  final int betCoins;
  final int payoutCoins;

  final String policyVersion;
  final int rtpBasisPoints;

  final DateTime createdAtUtc;

  final String? failureReason;

  int get netUserResult => payoutCoins - betCoins;

  int get platformGrossResult => betCoins - payoutCoins;

  bool get won => payoutCoins > betCoins;

  bool get lost => payoutCoins < betCoins;

  bool get breakEven => payoutCoins == betCoins;

  bool get isValid =>
      roundId.trim().isNotEmpty &&
      gameId.trim().isNotEmpty &&
      userAvoraId.trim().isNotEmpty &&
      betCoins >= 0 &&
      payoutCoins >= 0 &&
      rtpBasisPoints >= 0 &&
      rtpBasisPoints <= 10000;
}
