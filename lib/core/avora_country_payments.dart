import 'avora_compliance_gate.dart';

enum AvoraPaymentPurpose {
  recharge,
  payout,
}

enum AvoraPaymentChannel {
  iosAppStore,
  googlePlay,
  web,
  directDistribution,
}

enum AvoraPaymentRail {
  appStoreBilling,
  playBilling,

  card,
  upi,
  bankTransfer,
  localWallet,

  sellerInventory,
  merchantPayout,

  cryptoStablecoin,
}

class AvoraCountryPaymentMethod {
  final String id;

  final String countryCode;

  /// ISO currency code such as INR, SAR, USD.
  final String currencyCode;

  final AvoraPaymentPurpose purpose;
  final AvoraPaymentRail rail;

  /// Backend/provider adapter reference.
  ///
  /// Examples:
  /// apple_storekit
  /// google_play_billing
  /// local_acquirer_01
  /// upi_provider_01
  /// sa_wallet_provider_01
  final String providerId;

  /// User-visible name controlled by configuration.
  final String displayName;

  /// Optional aliases for UI/search only.
  ///
  /// Business logic must never depend on these names.
  final List<String> displayAliases;

  /// Channels where this method may be presented.
  final Set<AvoraPaymentChannel> allowedChannels;

  /// Country/store/provider compliance feature required
  /// before this method can be enabled.
  final AvoraComplianceFeature? requiredComplianceFeature;

  /// Amounts are in local currency minor units.
  final int minimumMinorUnits;
  final int? maximumMinorUnits;

  final bool identityVerificationRequired;
  final bool adultVerificationRequired;

  final bool enabled;

  const AvoraCountryPaymentMethod({
    required this.id,
    required this.countryCode,
    required this.currencyCode,
    required this.purpose,
    required this.rail,
    required this.providerId,
    required this.displayName,
    required this.allowedChannels,
    required this.minimumMinorUnits,
    this.maximumMinorUnits,
    this.displayAliases = const [],
    this.requiredComplianceFeature,
    this.identityVerificationRequired = true,
    this.adultVerificationRequired = true,
    this.enabled = true,
  })  : assert(minimumMinorUnits >= 0),
        assert(
          maximumMinorUnits == null || maximumMinorUnits >= minimumMinorUnits,
        );

  bool supportsChannel(
    AvoraPaymentChannel channel,
  ) {
    return allowedChannels.contains(channel);
  }

  bool amountAllowed(int minorUnits) {
    if (minorUnits < minimumMinorUnits) {
      return false;
    }

    final maximum = maximumMinorUnits;

    if (maximum != null && minorUnits > maximum) {
      return false;
    }

    return true;
  }
}

class AvoraCountryPaymentProfile {
  final String countryCode;

  final String currencyCode;

  /// Country Manager assignment responsible for
  /// operational administration, if configured.
  final String? countryManagerUserId;

  final List<AvoraCountryPaymentMethod> methods;

  final bool enabled;

  const AvoraCountryPaymentProfile({
    required this.countryCode,
    required this.currencyCode,
    required this.methods,
    this.countryManagerUserId,
    this.enabled = true,
  });
}

class AvoraCountryPaymentRegistry {
  const AvoraCountryPaymentRegistry._();

  static List<AvoraCountryPaymentMethod> availableMethods({
    required AvoraCountryPaymentProfile profile,
    required AvoraPaymentPurpose purpose,
    required AvoraPaymentChannel channel,
    required int amountMinorUnits,
  }) {
    if (!profile.enabled) {
      return const [];
    }

    return profile.methods.where((method) {
      if (!method.enabled) {
        return false;
      }

      if (method.countryCode.toUpperCase() !=
          profile.countryCode.toUpperCase()) {
        return false;
      }

      if (method.currencyCode.toUpperCase() !=
          profile.currencyCode.toUpperCase()) {
        return false;
      }

      if (method.purpose != purpose) {
        return false;
      }

      if (!method.supportsChannel(channel)) {
        return false;
      }

      if (!method.amountAllowed(amountMinorUnits)) {
        return false;
      }

      return true;
    }).toList(growable: false);
  }

  static bool isStoreBillingRail(
    AvoraPaymentRail rail,
  ) {
    return rail == AvoraPaymentRail.appStoreBilling ||
        rail == AvoraPaymentRail.playBilling;
  }

  static bool isLocalPaymentRail(
    AvoraPaymentRail rail,
  ) {
    switch (rail) {
      case AvoraPaymentRail.card:
      case AvoraPaymentRail.upi:
      case AvoraPaymentRail.bankTransfer:
      case AvoraPaymentRail.localWallet:
      case AvoraPaymentRail.sellerInventory:
      case AvoraPaymentRail.merchantPayout:
        return true;

      case AvoraPaymentRail.appStoreBilling:
      case AvoraPaymentRail.playBilling:
      case AvoraPaymentRail.cryptoStablecoin:
        return false;
    }
  }

  static bool isCryptoRail(
    AvoraPaymentRail rail,
  ) {
    return rail == AvoraPaymentRail.cryptoStablecoin;
  }
}
