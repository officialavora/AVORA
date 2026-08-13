import 'avora_withdrawal_routing.dart';

enum AvoraWithdrawalTradeListingStatus {
  listed,
  reserved,
  completed,
  cancelled,
  expired,
  review,
}

class AvoraWithdrawalTradeListing {
  const AvoraWithdrawalTradeListing({
    required this.listingId,
    required this.withdrawalRequestId,
    required this.userAvoraId,
    required this.amountMinor,
    required this.currencyCode,
    required this.countryCode,
    required this.payoutRailCode,
    required this.allowedAgentKinds,
    required this.createdAt,
    required this.expiresAt,
    this.status = AvoraWithdrawalTradeListingStatus.listed,
    this.acceptedByAgentAvoraId,
    this.reservedAt,
    this.completedAt,
  });

  final String listingId;
  final String withdrawalRequestId;

  /// Authoritative immutable AVORA ID of the withdrawing user.
  final String userAvoraId;

  final int amountMinor;
  final String currencyCode;
  final String countryCode;

  /// Example: UPI, bank, wallet, provider-specific rail code.
  /// Actual rail eligibility remains controlled by country/payment policy.
  final String payoutRailCode;

  final Set<AvoraWithdrawalAgentKind> allowedAgentKinds;

  final DateTime createdAt;
  final DateTime expiresAt;

  final AvoraWithdrawalTradeListingStatus status;

  final String? acceptedByAgentAvoraId;
  final DateTime? reservedAt;
  final DateTime? completedAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool get isOpen => status == AvoraWithdrawalTradeListingStatus.listed;

  bool belongsToUser(String avoraId) => userAvoraId == avoraId;

  bool acceptedBy(String avoraId) => acceptedByAgentAvoraId == avoraId;

  AvoraWithdrawalTradeListing copyWith({
    AvoraWithdrawalTradeListingStatus? status,
    String? acceptedByAgentAvoraId,
    DateTime? reservedAt,
    DateTime? completedAt,
  }) {
    return AvoraWithdrawalTradeListing(
      listingId: listingId,
      withdrawalRequestId: withdrawalRequestId,
      userAvoraId: userAvoraId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      countryCode: countryCode,
      payoutRailCode: payoutRailCode,
      allowedAgentKinds: allowedAgentKinds,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      acceptedByAgentAvoraId:
          acceptedByAgentAvoraId ?? this.acceptedByAgentAvoraId,
      reservedAt: reservedAt ?? this.reservedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class AvoraWithdrawalTradeListingEngine {
  static bool isValid(
    AvoraWithdrawalTradeListing listing,
  ) {
    return listing.listingId.trim().isNotEmpty &&
        listing.withdrawalRequestId.trim().isNotEmpty &&
        listing.userAvoraId.trim().isNotEmpty &&
        listing.amountMinor > 0 &&
        listing.currencyCode.trim().isNotEmpty &&
        listing.countryCode.trim().isNotEmpty &&
        listing.payoutRailCode.trim().isNotEmpty &&
        listing.allowedAgentKinds.isNotEmpty &&
        listing.expiresAt.isAfter(listing.createdAt);
  }

  static bool canAppearInAllOrders({
    required AvoraWithdrawalTradeListing listing,
    required DateTime now,
    String? countryCode,
    String? currencyCode,
  }) {
    if (!isValid(listing)) return false;
    if (!listing.isOpen) return false;
    if (listing.isExpiredAt(now)) return false;

    if (countryCode != null &&
        listing.countryCode.toUpperCase() != countryCode.toUpperCase()) {
      return false;
    }

    if (currencyCode != null &&
        listing.currencyCode.toUpperCase() != currencyCode.toUpperCase()) {
      return false;
    }

    return true;
  }

  static bool canAgentAccept({
    required AvoraWithdrawalTradeListing listing,
    required String agentAvoraId,
    required AvoraWithdrawalAgentKind agentKind,
    required DateTime now,
  }) {
    if (!canAppearInAllOrders(
      listing: listing,
      now: now,
    )) {
      return false;
    }

    if (agentAvoraId.trim().isEmpty) return false;

    /// User cannot accept their own withdrawal listing as payout agent.
    if (agentAvoraId == listing.userAvoraId) return false;

    if (!listing.allowedAgentKinds.contains(agentKind)) {
      return false;
    }

    return true;
  }

  static AvoraWithdrawalTradeListing reserveListing({
    required AvoraWithdrawalTradeListing listing,
    required String agentAvoraId,
    required AvoraWithdrawalAgentKind agentKind,
    required DateTime now,
  }) {
    if (!canAgentAccept(
      listing: listing,
      agentAvoraId: agentAvoraId,
      agentKind: agentKind,
      now: now,
    )) {
      return listing;
    }

    return listing.copyWith(
      status: AvoraWithdrawalTradeListingStatus.reserved,
      acceptedByAgentAvoraId: agentAvoraId,
      reservedAt: now,
    );
  }

  static List<AvoraWithdrawalTradeListing> allOrders({
    required Iterable<AvoraWithdrawalTradeListing> listings,
    required DateTime now,
    String? countryCode,
    String? currencyCode,
  }) {
    final result = listings.where((listing) {
      return canAppearInAllOrders(
        listing: listing,
        now: now,
        countryCode: countryCode,
        currencyCode: currencyCode,
      );
    }).toList();

    result.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return result;
  }

  /// "My Orders" includes withdrawals created by the user
  /// and orders accepted by an eligible payout agent.
  static List<AvoraWithdrawalTradeListing> myOrders({
    required Iterable<AvoraWithdrawalTradeListing> listings,
    required String viewerAvoraId,
  }) {
    final result = listings.where((listing) {
      return listing.belongsToUser(viewerAvoraId) ||
          listing.acceptedBy(viewerAvoraId);
    }).toList();

    result.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return result;
  }

  /// Listing creation must only happen after the user's eligible
  /// Withdrawable Balance has been authoritatively locked/reserved.
  static bool userBalanceMustBeLockedBeforeListing() => true;

  /// This listing engine never directly edits financial balances.
  static bool listingEngineMutatesWithdrawableBalance() => false;

  /// Acceptance must use the existing Settlement Liquidity Bridge.
  static bool acceptanceRequiresLiquidityReservationBridge() => true;

  /// Final settlement remains in the authoritative withdrawal/order lifecycle.
  static bool authoritativeOrderLifecycleRequired() => true;

  /// Screenshot/manual image alone can never complete settlement.
  static bool screenshotAloneCompletesTrade() => false;

  /// Mobile client cannot directly mark a listed withdrawal completed.
  static bool clientCanDirectlyCompleteTrade() => false;
}
