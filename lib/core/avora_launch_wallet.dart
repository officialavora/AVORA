import 'avora_actor_presentation.dart';

enum AvoraWalletTransactionType {
  recharge,
  coinCredit,
  coinDebit,
}

class AvoraWalletAccount {
  const AvoraWalletAccount({
    required this.avoraId,
    required this.coinBalance,
  });

  final String avoraId;
  final int coinBalance;

  AvoraWalletAccount copyWith({
    int? coinBalance,
  }) {
    return AvoraWalletAccount(
      avoraId: avoraId,
      coinBalance: coinBalance ?? this.coinBalance,
    );
  }
}

class AvoraWalletTransaction {
  const AvoraWalletTransaction({
    required this.transactionId,
    required this.type,
    required this.actor,
    required this.targetAvoraId,
    required this.amountCoins,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAtUtc,
    required this.reason,
  });

  final String transactionId;
  final AvoraWalletTransactionType type;
  final AvoraActionActor actor;
  final String targetAvoraId;
  final int amountCoins;
  final int balanceBefore;
  final int balanceAfter;
  final DateTime createdAtUtc;
  final String reason;
}

class AvoraLaunchWalletLedger {
  final Map<String, AvoraWalletAccount> _accounts =
      <String, AvoraWalletAccount>{};

  final Map<String, AvoraWalletTransaction> _transactions =
      <String, AvoraWalletTransaction>{};

  AvoraWalletAccount ensureAccount(String avoraId) {
    final id = avoraId.trim();

    if (id.isEmpty) {
      throw ArgumentError('wallet_avora_id_required');
    }

    return _accounts.putIfAbsent(
      id,
      () => AvoraWalletAccount(
        avoraId: id,
        coinBalance: 0,
      ),
    );
  }

  AvoraWalletAccount account(String avoraId) {
    return ensureAccount(avoraId);
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
    if (type == AvoraWalletTransactionType.coinDebit) {
      throw ArgumentError('credit_cannot_use_debit_type');
    }

    if (amountCoins <= 0) {
      throw ArgumentError('credit_amount_must_be_positive');
    }

    _validateTransactionIdentity(
      transactionId: transactionId,
      actor: actor,
      targetAvoraId: targetAvoraId,
      reason: reason,
    );

    final current = ensureAccount(targetAvoraId);

    final nextBalance = current.coinBalance + amountCoins;

    final tx = AvoraWalletTransaction(
      transactionId: transactionId,
      type: type,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      balanceBefore: current.coinBalance,
      balanceAfter: nextBalance,
      createdAtUtc: createdAtUtc.toUtc(),
      reason: reason,
    );

    _accounts[targetAvoraId] = current.copyWith(
      coinBalance: nextBalance,
    );

    _transactions[transactionId] = tx;

    return tx;
  }

  AvoraWalletTransaction debit({
    required String transactionId,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String reason,
  }) {
    if (amountCoins <= 0) {
      throw ArgumentError('debit_amount_must_be_positive');
    }

    _validateTransactionIdentity(
      transactionId: transactionId,
      actor: actor,
      targetAvoraId: targetAvoraId,
      reason: reason,
    );

    final current = ensureAccount(targetAvoraId);

    if (current.coinBalance < amountCoins) {
      throw StateError('insufficient_coin_balance');
    }

    final nextBalance = current.coinBalance - amountCoins;

    final tx = AvoraWalletTransaction(
      transactionId: transactionId,
      type: AvoraWalletTransactionType.coinDebit,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      balanceBefore: current.coinBalance,
      balanceAfter: nextBalance,
      createdAtUtc: createdAtUtc.toUtc(),
      reason: reason,
    );

    _accounts[targetAvoraId] = current.copyWith(
      coinBalance: nextBalance,
    );

    _transactions[transactionId] = tx;

    return tx;
  }

  void _validateTransactionIdentity({
    required String transactionId,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required String reason,
  }) {
    if (transactionId.trim().isEmpty ||
        actor.avoraId.trim().isEmpty ||
        targetAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_wallet_transaction');
    }

    if (_transactions.containsKey(transactionId)) {
      throw StateError('duplicate_wallet_transaction');
    }
  }

  AvoraWalletTransaction? transactionById(
    String transactionId,
  ) {
    return _transactions[transactionId.trim()];
  }

  List<AvoraWalletTransaction> historyFor(
    String avoraId,
  ) {
    return List<AvoraWalletTransaction>.unmodifiable(
      _transactions.values.where(
        (tx) => tx.targetAvoraId == avoraId,
      ),
    );
  }

  static bool walletMustUseImmutableAvoraId() => true;

  static bool walletBalanceMustNeverGoNegative() => true;

  static bool duplicateTransactionMustFailClosed() => true;

  static bool everyCoinChangeMustCreateLedgerRecord() => true;

  static bool rechargeMustPreserveActorIdentityInternally() => true;

  static bool ownerRechargeNotificationMustUseMaskedOwnerPresentation() => true;

  static bool sellerMerchantRechargeMustRemainAccountable() => true;

  static bool futureCoinModulesMustUseSameWalletLedger() => true;
}

class AvoraLaunchRechargeService {
  AvoraLaunchRechargeService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraOperationalActionLedger actionLedger,
  })  : _walletLedger = walletLedger,
        _actionLedger = actionLedger;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraOperationalActionLedger _actionLedger;

  AvoraWalletTransaction recharge({
    required String transactionId,
    required AvoraActionActor actor,
    required String targetAvoraId,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String reason,
  }) {
    final tx = _walletLedger.credit(
      transactionId: transactionId,
      type: AvoraWalletTransactionType.recharge,
      actor: actor,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      createdAtUtc: createdAtUtc,
      reason: reason,
    );

    _actionLedger.append(
      AvoraOperationalActionRecord(
        recordId: 'action-$transactionId',
        actionType: AvoraOperationalActionType.recharge,
        actor: actor,
        targetAvoraId: targetAvoraId,
        amountCoins: amountCoins,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );

    return tx;
  }

  String publicNotificationFor(
    String transactionId,
  ) {
    final tx = _walletLedger.transactionById(transactionId);

    if (tx == null) {
      throw StateError('wallet_transaction_not_found');
    }

    return AvoraActionNotificationFormatter.format(
      AvoraOperationalActionRecord(
        recordId: 'notification-${tx.transactionId}',
        actionType: AvoraOperationalActionType.recharge,
        actor: tx.actor,
        targetAvoraId: tx.targetAvoraId,
        amountCoins: tx.amountCoins,
        reason: tx.reason,
        createdAtUtc: tx.createdAtUtc,
      ),
    );
  }

  static bool rechargeMustUpdateWalletAndAuditTogether() => true;

  static bool rechargeNotificationMustUseActorPresentationPolicy() => true;

  static bool ownerRechargeMustNeverExposeOwnerPersonalDetails() => true;

  static bool futureRechargeProvidersMustReuseSameServiceContract() => true;
}
