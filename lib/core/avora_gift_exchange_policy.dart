class AvoraGiftExchangePolicy {
  const AvoraGiftExchangePolicy({
    required this.exchangeBasisPoints,
  }) : assert(
          exchangeBasisPoints >= 0 && exchangeBasisPoints <= 10000,
        );

  /// 1000 bps = 10%
  final int exchangeBasisPoints;

  int exchangeBackupToCoins({
    required int backupValue,
  }) {
    if (backupValue < 0) {
      throw ArgumentError('backup_value_must_not_be_negative');
    }

    return (backupValue * exchangeBasisPoints) ~/ 10000;
  }

  static bool exchangeRateMustNotChangeHistoricalGiftCount() => true;

  static bool exchangePolicyMustBeVersionable() => true;

  static bool exchangeRateMustBeOwnerConfigurable() => true;
}
