import 'avora_coin_treasury.dart';
import 'avora_recharge_refund_recovery.dart';

enum AvoraRefundRecoveryBridgeDenyReason {
  none,
  providerEventNotVerified,
  providerEventMismatch,
  invalidRecoveryAmount,
  missingWalletAccount,
  missingTreasuryAccount,
  missingAccountableActor,
}

class AvoraRefundRecoveryHoldDirective {
  const AvoraRefundRecoveryHoldDirective({
    required this.beneficiaryAvoraId,
    required this.liabilityId,
    required this.purchaseLotId,
    required this.providerEventId,
    required this.unresolvedCoinUnits,
    required this.holdWithdrawal,
    required this.holdRewards,
    required this.holdSettlement,
    required this.reason,
    required this.createdAt,
  });

  final String beneficiaryAvoraId;
  final String liabilityId;
  final String purchaseLotId;
  final String providerEventId;

  final int unresolvedCoinUnits;

  /// These are scoped hold instructions.
  /// Existing backend risk/withdrawal/reward guards remain authoritative.
  final bool holdWithdrawal;
  final bool holdRewards;
  final bool holdSettlement;

  final String reason;
  final DateTime createdAt;
}

class AvoraRefundRecoveryBridgeDecision {
  const AvoraRefundRecoveryBridgeDecision({
    required this.allowed,
    required this.reason,
    this.treasuryReversalEntry,
    this.holdDirective,
  });

  final bool allowed;
  final AvoraRefundRecoveryBridgeDenyReason reason;

  /// Instruction only. It must still pass AvoraCoinTreasuryEngine/backend
  /// validation before any balance mutation.
  final AvoraCoinLedgerEntry? treasuryReversalEntry;

  /// Scoped hold instruction when consumed value remains unrecovered.
  final AvoraRefundRecoveryHoldDirective? holdDirective;
}

class AvoraRefundRecoveryBridge {
  const AvoraRefundRecoveryBridge._();

  static AvoraRefundRecoveryBridgeDecision prepare({
    required AvoraProviderRefundEvent providerEvent,
    required AvoraRefundRecoveryLiability liability,
    required String beneficiaryWalletAccountId,
    required String companyTreasuryAccountId,
    required String accountableActorAvoraId,
    required DateTime serverNow,
  }) {
    if (!providerEvent.serverVerified) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.providerEventNotVerified,
      );
    }

    if (providerEvent.eventId != liability.providerEventId ||
        providerEvent.purchaseLotId != liability.purchaseLotId) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.providerEventMismatch,
      );
    }

    if (liability.coinUnitsToRecover <= 0 ||
        liability.recoverFromRemainingBalanceCoinUnits < 0 ||
        liability.unrecoveredConsumedCoinUnits < 0) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.invalidRecoveryAmount,
      );
    }

    final recoverable = liability.recoverFromRemainingBalanceCoinUnits;

    if (recoverable > 0 && beneficiaryWalletAccountId.trim().isEmpty) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.missingWalletAccount,
      );
    }

    if (recoverable > 0 && companyTreasuryAccountId.trim().isEmpty) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.missingTreasuryAccount,
      );
    }

    if (accountableActorAvoraId.trim().isEmpty) {
      return const AvoraRefundRecoveryBridgeDecision(
        allowed: false,
        reason: AvoraRefundRecoveryBridgeDenyReason.missingAccountableActor,
      );
    }

    AvoraCoinLedgerEntry? reversalEntry;

    if (recoverable > 0) {
      reversalEntry = AvoraCoinLedgerEntry(
        entryId: 'REFUND-REVERSAL-${liability.liabilityId}',
        type: AvoraCoinMovementType.reversal,
        sourceAccountId: beneficiaryWalletAccountId.trim(),
        destinationAccountId: companyTreasuryAccountId.trim(),
        amount: recoverable,
        actorAvoraId: accountableActorAvoraId.trim(),
        serverAuthorized: true,
        createdAt: serverNow,
        reason: 'provider_refund_or_chargeback_recovery',
        referenceId: providerEvent.eventId,
        policyVersion: liability.policyVersion,
        idempotencyKey: 'refund-recovery:${liability.liabilityId}:balance',
      );
    }

    AvoraRefundRecoveryHoldDirective? holdDirective;

    if (liability.unrecoveredConsumedCoinUnits > 0) {
      holdDirective = AvoraRefundRecoveryHoldDirective(
        beneficiaryAvoraId: liability.beneficiaryAvoraId,
        liabilityId: liability.liabilityId,
        purchaseLotId: liability.purchaseLotId,
        providerEventId: liability.providerEventId,
        unresolvedCoinUnits: liability.unrecoveredConsumedCoinUnits,
        holdWithdrawal: true,
        holdRewards: true,
        holdSettlement: true,
        reason: 'unresolved_consumed_refund_liability',
        createdAt: serverNow,
      );
    }

    return AvoraRefundRecoveryBridgeDecision(
      allowed: true,
      reason: AvoraRefundRecoveryBridgeDenyReason.none,
      treasuryReversalEntry: reversalEntry,
      holdDirective: holdDirective,
    );
  }

  /// Payment provider/store/server event must be authoritative.
  static bool providerVerificationRequired() => true;

  /// Mobile client cannot directly execute refund recovery.
  static bool clientCanExecuteRecovery() => false;

  /// Bridge only prepares a ledger instruction.
  /// Treasury/backend still validates and applies it.
  static bool treasuryValidationRequiredBeforeMutation() => true;

  /// A chargeback does not authorize rewriting old gift/game history.
  static bool historicalSpendCanBeDeletedByRecovery() => false;

  /// Unrelated receiver/third-party earned balances remain untouched.
  static bool unrelatedThirdPartyBalanceCanBeMutated() => false;

  /// Hold should be limited to relevant financial/reward functions.
  static bool accountDeletionRequiredForLiability() => false;

  static bool scopedHoldPreferredOverAccountErasure() => true;

  /// Same provider event/recovery liability must remain idempotent.
  static bool deterministicRecoveryIdempotencyRequired() => true;
}
