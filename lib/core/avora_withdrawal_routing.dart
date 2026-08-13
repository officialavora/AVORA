enum AvoraWithdrawalRouteType {
  agencyOwner,
  merchant,
}

enum AvoraWithdrawalAgentKind {
  agencyOwner,
  merchant,
}

class AvoraWithdrawalAgent {
  const AvoraWithdrawalAgent({
    required this.avoraId,
    required this.kind,
    required this.verified,
    required this.active,
    required this.payoutEnabled,
    required this.countryCodes,
    required this.currencyCodes,
    required this.availableCapacityMinor,
    this.reservedCapacityMinor = 0,
    this.minimumAmountMinor = 1,
    this.maximumAmountMinor,
  });

  /// Immutable AVORA ID of Agency Owner or Merchant.
  final String avoraId;
  final AvoraWithdrawalAgentKind kind;

  final bool verified;
  final bool active;
  final bool payoutEnabled;

  final Set<String> countryCodes;
  final Set<String> currencyCodes;

  /// Amount this agent can currently settle.
  final int availableCapacityMinor;

  /// Already reserved for pending withdrawals.
  final int reservedCapacityMinor;

  final int minimumAmountMinor;
  final int? maximumAmountMinor;

  int get usableCapacityMinor {
    final value = availableCapacityMinor - reservedCapacityMinor;
    return value < 0 ? 0 : value;
  }

  bool supports({
    required String countryCode,
    required String currencyCode,
  }) {
    return countryCodes.contains(countryCode) &&
        currencyCodes.contains(currencyCode);
  }
}

class AvoraWithdrawalRequest {
  const AvoraWithdrawalRequest({
    required this.requestId,
    required this.userAvoraId,
    required this.routeType,
    required this.selectedAgentAvoraId,
    required this.amountMinor,
    required this.feeMinor,
    required this.currencyCode,
    required this.countryCode,
    required this.availableWithdrawableBalanceMinor,
    required this.userConfirmedAgent,
    required this.riskApproved,
    required this.complianceApproved,
    required this.createdAt,
    required this.idempotencyKey,
  });

  final String requestId;

  /// Immutable AVORA ID requesting withdrawal.
  final String userAvoraId;

  final AvoraWithdrawalRouteType routeType;

  /// User-selected eligible Agency Owner / Merchant.
  final String selectedAgentAvoraId;

  final int amountMinor;
  final int feeMinor;

  final String currencyCode;
  final String countryCode;

  /// Server-authoritative eligible withdrawable balance.
  final int availableWithdrawableBalanceMinor;

  /// User must see and confirm the selected payout agent.
  final bool userConfirmedAgent;

  final bool riskApproved;
  final bool complianceApproved;

  final DateTime createdAt;

  /// Prevents duplicate withdrawal submission.
  final String idempotencyKey;

  int get netAmountMinor => amountMinor - feeMinor;
}

class AvoraWithdrawalRouteDecision {
  const AvoraWithdrawalRouteDecision({
    required this.allowed,
    required this.reason,
    this.agent,
  });

  final bool allowed;
  final String reason;
  final AvoraWithdrawalAgent? agent;
}

class AvoraWithdrawalRoutingEngine {
  static AvoraWithdrawalRouteDecision validate({
    required AvoraWithdrawalRequest request,
    required Iterable<AvoraWithdrawalAgent> agents,
  }) {
    if (request.requestId.trim().isEmpty ||
        request.userAvoraId.trim().isEmpty ||
        request.selectedAgentAvoraId.trim().isEmpty ||
        request.currencyCode.trim().isEmpty ||
        request.countryCode.trim().isEmpty ||
        request.idempotencyKey.trim().isEmpty) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'missingRequiredMetadata',
      );
    }

    if (request.amountMinor <= 0) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'invalidAmount',
      );
    }

    if (request.feeMinor < 0 || request.feeMinor >= request.amountMinor) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'invalidFee',
      );
    }

    if (request.availableWithdrawableBalanceMinor < request.amountMinor) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'insufficientWithdrawableBalance',
      );
    }

    if (!request.userConfirmedAgent) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentConfirmationRequired',
      );
    }

    if (!request.riskApproved) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'riskReviewRequired',
      );
    }

    if (!request.complianceApproved) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'complianceNotApproved',
      );
    }

    final agent = _findAgent(
      agents,
      request.selectedAgentAvoraId,
    );

    if (agent == null) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentNotFound',
      );
    }

    if (agent.avoraId == request.userAvoraId) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'selfAgentRouteNotAllowed',
      );
    }

    final requiredKind =
        request.routeType == AvoraWithdrawalRouteType.agencyOwner
            ? AvoraWithdrawalAgentKind.agencyOwner
            : AvoraWithdrawalAgentKind.merchant;

    if (agent.kind != requiredKind) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentKindMismatch',
      );
    }

    if (!agent.verified || !agent.active || !agent.payoutEnabled) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentNotEligible',
      );
    }

    if (!agent.supports(
      countryCode: request.countryCode,
      currencyCode: request.currencyCode,
    )) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentCountryOrCurrencyUnsupported',
      );
    }

    if (request.amountMinor < agent.minimumAmountMinor) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'belowAgentMinimum',
      );
    }

    final maximum = agent.maximumAmountMinor;
    if (maximum != null && request.amountMinor > maximum) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'aboveAgentMaximum',
      );
    }

    if (agent.usableCapacityMinor < request.amountMinor) {
      return const AvoraWithdrawalRouteDecision(
        allowed: false,
        reason: 'agentCapacityInsufficient',
      );
    }

    return AvoraWithdrawalRouteDecision(
      allowed: true,
      reason: 'eligibleUserSelectedPayoutAgent',
      agent: agent,
    );
  }

  static AvoraWithdrawalAgent? _findAgent(
    Iterable<AvoraWithdrawalAgent> agents,
    String avoraId,
  ) {
    for (final agent in agents) {
      if (agent.avoraId == avoraId) {
        return agent;
      }
    }

    return null;
  }

  /// User may choose any eligible payout agent allowed by policy.
  static bool userMustUseOwnAgencyOwner() => false;

  /// Friendship/follow-back is never required for payout routing.
  static bool friendshipRequiredForWithdrawalAgent() => false;

  /// Unverified arbitrary accounts cannot act as payout agents.
  static bool arbitraryAccountCanActAsAgent() => false;

  /// Funds must be reserved before settlement/acceptance.
  static bool reserveBeforeSettlementRequired() => true;

  /// Screenshot alone never proves withdrawal completion.
  static bool screenshotAloneConfirmsWithdrawal() => false;

  /// Mobile client never mutates authoritative withdrawable balance.
  static bool clientCanDirectlySetWithdrawalBalance() => false;
}
