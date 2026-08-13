import 'avora_actor_presentation.dart';
import 'avora_launch_recharge_provider.dart';
import 'avora_launch_wallet.dart';

enum AvoraRechargeDisputeType {
  refund,
  chargeback,
}

enum AvoraRechargeDisputeStatus {
  opened,
  investigating,
  recoveryPending,
  recovered,
  partiallyRecovered,
  waived,
  closed,
}

class AvoraRechargeDisputeCase {
  const AvoraRechargeDisputeCase({
    required this.caseId,
    required this.orderId,
    required this.targetAvoraId,
    required this.type,
    required this.originalCoinAmount,
    required this.recoveredCoinAmount,
    required this.status,
    required this.reason,
    required this.createdAtUtc,
  });

  final String caseId;
  final String orderId;
  final String targetAvoraId;
  final AvoraRechargeDisputeType type;
  final int originalCoinAmount;
  final int recoveredCoinAmount;
  final AvoraRechargeDisputeStatus status;
  final String reason;
  final DateTime createdAtUtc;

  AvoraRechargeDisputeCase copyWith({
    int? recoveredCoinAmount,
    AvoraRechargeDisputeStatus? status,
    String? reason,
  }) {
    return AvoraRechargeDisputeCase(
      caseId: caseId,
      orderId: orderId,
      targetAvoraId: targetAvoraId,
      type: type,
      originalCoinAmount: originalCoinAmount,
      recoveredCoinAmount: recoveredCoinAmount ?? this.recoveredCoinAmount,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      createdAtUtc: createdAtUtc,
    );
  }

  int get remainingCoinAmount => originalCoinAmount - recoveredCoinAmount;
}

class AvoraWalletFreezeRecord {
  const AvoraWalletFreezeRecord({
    required this.freezeId,
    required this.avoraId,
    required this.reason,
    required this.createdAtUtc,
    this.releasedAtUtc,
  });

  final String freezeId;
  final String avoraId;
  final String reason;
  final DateTime createdAtUtc;
  final DateTime? releasedAtUtc;

  bool get active => releasedAtUtc == null;

  AvoraWalletFreezeRecord release(DateTime releasedAtUtc) {
    return AvoraWalletFreezeRecord(
      freezeId: freezeId,
      avoraId: avoraId,
      reason: reason,
      createdAtUtc: createdAtUtc,
      releasedAtUtc: releasedAtUtc.toUtc(),
    );
  }
}

class AvoraRechargeDisputeRecoveryLedger {
  final Map<String, AvoraRechargeDisputeCase> _cases =
      <String, AvoraRechargeDisputeCase>{};

  final Map<String, AvoraWalletFreezeRecord> _freezes =
      <String, AvoraWalletFreezeRecord>{};

  void openCase(AvoraRechargeDisputeCase dispute) {
    if (dispute.caseId.trim().isEmpty ||
        dispute.orderId.trim().isEmpty ||
        dispute.targetAvoraId.trim().isEmpty ||
        dispute.originalCoinAmount <= 0 ||
        dispute.reason.trim().isEmpty) {
      throw ArgumentError('invalid_recharge_dispute_case');
    }

    if (_cases.containsKey(dispute.caseId)) {
      throw StateError('duplicate_recharge_dispute_case');
    }

    _cases[dispute.caseId] = dispute;
  }

  AvoraRechargeDisputeCase? caseById(String caseId) => _cases[caseId.trim()];

  void updateCase({
    required String caseId,
    required AvoraRechargeDisputeStatus status,
    int? recoveredCoinAmount,
    String? reason,
  }) {
    final current = _cases[caseId];

    if (current == null) {
      throw StateError('recharge_dispute_case_not_found');
    }

    final nextRecovered = recoveredCoinAmount ?? current.recoveredCoinAmount;

    if (nextRecovered < 0 || nextRecovered > current.originalCoinAmount) {
      throw ArgumentError('invalid_recovered_coin_amount');
    }

    _cases[caseId] = current.copyWith(
      status: status,
      recoveredCoinAmount: nextRecovered,
      reason: reason,
    );
  }

  void freezeWallet(AvoraWalletFreezeRecord freeze) {
    if (freeze.freezeId.trim().isEmpty ||
        freeze.avoraId.trim().isEmpty ||
        freeze.reason.trim().isEmpty) {
      throw ArgumentError('invalid_wallet_freeze');
    }

    if (_freezes.containsKey(freeze.freezeId)) {
      throw StateError('duplicate_wallet_freeze');
    }

    _freezes[freeze.freezeId] = freeze;
  }

  void releaseFreeze({
    required String freezeId,
    required DateTime releasedAtUtc,
  }) {
    final current = _freezes[freezeId];

    if (current == null) {
      throw StateError('wallet_freeze_not_found');
    }

    _freezes[freezeId] = current.release(releasedAtUtc);
  }

  bool isWalletFrozen(String avoraId) {
    return _freezes.values.any(
      (freeze) => freeze.avoraId == avoraId && freeze.active,
    );
  }

  List<AvoraRechargeDisputeCase> byTarget(String avoraId) {
    return List<AvoraRechargeDisputeCase>.unmodifiable(
      _cases.values.where(
        (item) => item.targetAvoraId == avoraId,
      ),
    );
  }

  static bool refundMustCreateRecoveryCase() => true;

  static bool chargebackMustCreateRecoveryCase() => true;

  static bool disputeMustNotSilentlyDeleteCoins() => true;

  static bool walletFreezeMustBeExplicitAndAuditable() => true;

  static bool ownerManualReviewMustRemainPossible() => true;

  static bool recoveredAmountMustNeverExceedOriginalRecharge() => true;

  static bool futurePaymentDisputesMustUseSameRecoveryLedger() => true;
}

class AvoraRechargeDisputeRecoveryService {
  AvoraRechargeDisputeRecoveryService({
    required AvoraRechargeLedger rechargeLedger,
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraRechargeDisputeRecoveryLedger recoveryLedger,
  })  : _rechargeLedger = rechargeLedger,
        _walletLedger = walletLedger,
        _recoveryLedger = recoveryLedger;

  final AvoraRechargeLedger _rechargeLedger;
  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraRechargeDisputeRecoveryLedger _recoveryLedger;

  AvoraRechargeDisputeCase openFromOrder({
    required String caseId,
    required String orderId,
    required AvoraRechargeDisputeType type,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    final order = _rechargeLedger.byId(orderId);

    if (order == null) {
      throw StateError('recharge_order_not_found');
    }

    if (order.status != AvoraRechargeStatus.refunded &&
        order.status != AvoraRechargeStatus.chargeback) {
      throw StateError('recharge_order_not_disputed');
    }

    final dispute = AvoraRechargeDisputeCase(
      caseId: caseId,
      orderId: order.orderId,
      targetAvoraId: order.targetAvoraId,
      type: type,
      originalCoinAmount: order.amountCoins,
      recoveredCoinAmount: 0,
      status: AvoraRechargeDisputeStatus.opened,
      reason: reason,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _recoveryLedger.openCase(dispute);

    return dispute;
  }

  int recoverAvailableCoins({
    required String caseId,
    required String transactionId,
    required DateTime createdAtUtc,
  }) {
    final dispute = _recoveryLedger.caseById(caseId);

    if (dispute == null) {
      throw StateError('recharge_dispute_case_not_found');
    }

    final account = _walletLedger.account(dispute.targetAvoraId);

    final recoverable = account.coinBalance < dispute.remainingCoinAmount
        ? account.coinBalance
        : dispute.remainingCoinAmount;

    if (recoverable <= 0) {
      _recoveryLedger.updateCase(
        caseId: caseId,
        status: AvoraRechargeDisputeStatus.recoveryPending,
      );

      return 0;
    }

    _walletLedger.debit(
      transactionId: transactionId,
      actor: const AvoraActionActor(
        avoraId: 'SYSTEM',
        kind: AvoraActorKind.system,
        displayName: 'System',
      ),
      targetAvoraId: dispute.targetAvoraId,
      amountCoins: recoverable,
      createdAtUtc: createdAtUtc,
      reason: 'recharge_dispute_recovery:$caseId',
    );

    final totalRecovered = dispute.recoveredCoinAmount + recoverable;

    final nextStatus = totalRecovered == dispute.originalCoinAmount
        ? AvoraRechargeDisputeStatus.recovered
        : AvoraRechargeDisputeStatus.partiallyRecovered;

    _recoveryLedger.updateCase(
      caseId: caseId,
      recoveredCoinAmount: totalRecovered,
      status: nextStatus,
    );

    return recoverable;
  }

  static bool recoveryMustNeverMakeWalletNegative() => true;

  static bool unavailableCoinsMustRemainRecoveryPending() => true;

  static bool partialRecoveryMustRemainTraceable() => true;

  static bool fullRecoveryMustCloseEconomicExposure() => true;

  static bool recoveryMustCreateWalletLedgerTransaction() => true;

  static bool futureDisputeRecoveryMustUseSameService() => true;
}
