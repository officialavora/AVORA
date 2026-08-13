import 'avora_actor_presentation.dart';
import 'avora_launch_wallet.dart';
import 'avora_recharge_dispute_recovery.dart';

enum AvoraWalletSpendPurpose {
  gift,
  game,
  transfer,
  purchase,
  exchange,
  other,
}

enum AvoraWalletProtectedOperation {
  disputeRecovery,
  ownerCorrection,
  systemCorrection,
}

class AvoraWalletSpendDecision {
  const AvoraWalletSpendDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraWalletFreezeEnforcementPolicy {
  const AvoraWalletFreezeEnforcementPolicy({
    required AvoraRechargeDisputeRecoveryLedger recoveryLedger,
  }) : _recoveryLedger = recoveryLedger;

  final AvoraRechargeDisputeRecoveryLedger _recoveryLedger;

  AvoraWalletSpendDecision evaluateSpend({
    required String avoraId,
    required AvoraWalletSpendPurpose purpose,
  }) {
    if (avoraId.trim().isEmpty) {
      return const AvoraWalletSpendDecision(
        allowed: false,
        reason: 'wallet_avora_id_required',
      );
    }

    if (_recoveryLedger.isWalletFrozen(avoraId)) {
      return AvoraWalletSpendDecision(
        allowed: false,
        reason: 'wallet_frozen_for_${purpose.name}',
      );
    }

    return const AvoraWalletSpendDecision(
      allowed: true,
      reason: 'wallet_spend_allowed',
    );
  }

  AvoraWalletSpendDecision evaluateProtectedOperation({
    required String targetAvoraId,
    required AvoraActionActor actor,
    required AvoraWalletProtectedOperation operation,
  }) {
    if (targetAvoraId.trim().isEmpty || actor.avoraId.trim().isEmpty) {
      return const AvoraWalletSpendDecision(
        allowed: false,
        reason: 'invalid_protected_wallet_operation',
      );
    }

    switch (operation) {
      case AvoraWalletProtectedOperation.disputeRecovery:
        if (actor.kind == AvoraActorKind.system ||
            actor.kind == AvoraActorKind.owner) {
          return const AvoraWalletSpendDecision(
            allowed: true,
            reason: 'authorized_dispute_recovery',
          );
        }

        return const AvoraWalletSpendDecision(
          allowed: false,
          reason: 'unauthorized_dispute_recovery',
        );

      case AvoraWalletProtectedOperation.ownerCorrection:
        if (actor.kind == AvoraActorKind.owner) {
          return const AvoraWalletSpendDecision(
            allowed: true,
            reason: 'authorized_owner_correction',
          );
        }

        return const AvoraWalletSpendDecision(
          allowed: false,
          reason: 'owner_authority_required',
        );

      case AvoraWalletProtectedOperation.systemCorrection:
        if (actor.kind == AvoraActorKind.system ||
            actor.kind == AvoraActorKind.owner) {
          return const AvoraWalletSpendDecision(
            allowed: true,
            reason: 'authorized_system_correction',
          );
        }

        return const AvoraWalletSpendDecision(
          allowed: false,
          reason: 'system_or_owner_authority_required',
        );
    }
  }

  static bool activeFreezeMustBlockNormalSpend() => true;
  static bool freezeMustBlockGiftSpend() => true;
  static bool freezeMustBlockGameSpend() => true;
  static bool freezeMustBlockTransferSpend() => true;
  static bool freezeMustBlockPurchaseSpend() => true;
  static bool freezeMustBlockExchangeSpend() => true;
  static bool freezeMustNotEqualAccountBan() => true;
  static bool incomingCreditMustNotBeBlockedBySpendFreeze() => true;
  static bool ownerRecoveryAuthorityMustRemainAvailable() => true;
  static bool systemRecoveryMustRemainAvailable() => true;
  static bool futureSpendModulesMustUseSameFreezePolicy() => true;
}

class AvoraFreezeAwareWalletService {
  AvoraFreezeAwareWalletService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraWalletFreezeEnforcementPolicy freezePolicy,
  })  : _walletLedger = walletLedger,
        _freezePolicy = freezePolicy;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraWalletFreezeEnforcementPolicy _freezePolicy;

  AvoraWalletTransaction spend({
    required String transactionId,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String reason,
    required AvoraWalletSpendPurpose purpose,
  }) {
    if (actor.avoraId != targetAvoraId) {
      throw StateError('wallet_spend_actor_identity_mismatch');
    }

    final decision = _freezePolicy.evaluateSpend(
      avoraId: targetAvoraId,
      purpose: purpose,
    );

    if (!decision.allowed) {
      throw StateError(decision.reason);
    }

    return _walletLedger.debit(
      transactionId: transactionId,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      createdAtUtc: createdAtUtc,
      reason: reason,
    );
  }

  AvoraWalletTransaction protectedDebit({
    required String transactionId,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String reason,
    required AvoraWalletProtectedOperation operation,
  }) {
    final decision = _freezePolicy.evaluateProtectedOperation(
      targetAvoraId: targetAvoraId,
      actor: actor,
      operation: operation,
    );

    if (!decision.allowed) {
      throw StateError(decision.reason);
    }

    return _walletLedger.debit(
      transactionId: transactionId,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      createdAtUtc: createdAtUtc,
      reason: reason,
    );
  }

  AvoraWalletTransaction credit({
    required String transactionId,
    required AvoraWalletTransactionType type,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String reason,
  }) {
    return _walletLedger.credit(
      transactionId: transactionId,
      type: type,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      createdAtUtc: createdAtUtc,
      reason: reason,
    );
  }

  static bool everyNormalSpendMustCheckFreezeFirst() => true;
  static bool protectedDebitMustRequireAuthorizedActor() => true;
  static bool freezeMustNeverSilentlyEraseBalance() => true;
  static bool futureGameWalletSpendMustUseFreezeAwareService() => true;
}
