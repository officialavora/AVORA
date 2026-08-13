enum AvoraDiamondExchangeError {
  invalidAmount,
  belowMinimum,
  aboveMaximum,
}

class AvoraDiamondExchangeConfig {
  /// 10000 basis points = 100%.
  ///
  /// Examples:
  /// 2000 = 20%
  /// 3000 = 30%
  final int exchangeRateBps;

  final int minDiamondAmount;

  /// Null means no configured maximum.
  final int? maxDiamondAmount;

  const AvoraDiamondExchangeConfig({
    required this.exchangeRateBps,
    this.minDiamondAmount = 1,
    this.maxDiamondAmount,
  })  : assert(exchangeRateBps >= 0 && exchangeRateBps <= 10000),
        assert(minDiamondAmount > 0),
        assert(
          maxDiamondAmount == null || maxDiamondAmount >= minDiamondAmount,
        );
}

class AvoraDiamondExchangeQuote {
  final int diamondDebit;
  final int coinCredit;
  final int exchangeRateBps;
  final AvoraDiamondExchangeError? error;

  const AvoraDiamondExchangeQuote({
    required this.diamondDebit,
    required this.coinCredit,
    required this.exchangeRateBps,
    this.error,
  });

  bool get allowed => error == null;
}

class AvoraDiamondExchangeEngine {
  const AvoraDiamondExchangeEngine._();

  static AvoraDiamondExchangeQuote quote({
    required int diamondAmount,
    required AvoraDiamondExchangeConfig config,
  }) {
    if (diamondAmount <= 0) {
      return AvoraDiamondExchangeQuote(
        diamondDebit: 0,
        coinCredit: 0,
        exchangeRateBps: config.exchangeRateBps,
        error: AvoraDiamondExchangeError.invalidAmount,
      );
    }

    if (diamondAmount < config.minDiamondAmount) {
      return AvoraDiamondExchangeQuote(
        diamondDebit: diamondAmount,
        coinCredit: 0,
        exchangeRateBps: config.exchangeRateBps,
        error: AvoraDiamondExchangeError.belowMinimum,
      );
    }

    final max = config.maxDiamondAmount;

    if (max != null && diamondAmount > max) {
      return AvoraDiamondExchangeQuote(
        diamondDebit: diamondAmount,
        coinCredit: 0,
        exchangeRateBps: config.exchangeRateBps,
        error: AvoraDiamondExchangeError.aboveMaximum,
      );
    }

    final coins = (diamondAmount * config.exchangeRateBps) ~/ 10000;

    return AvoraDiamondExchangeQuote(
      diamondDebit: diamondAmount,
      coinCredit: coins,
      exchangeRateBps: config.exchangeRateBps,
    );
  }
}
