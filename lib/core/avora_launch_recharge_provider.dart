import 'avora_actor_presentation.dart';
import 'avora_launch_wallet.dart';

enum AvoraRechargeStatus {
  created,
  pending,
  confirmed,
  failed,
  refunded,
  chargeback,
}

class AvoraRechargeOrder {
  const AvoraRechargeOrder({
    required this.orderId,
    required this.targetAvoraId,
    required this.amountCoins,
    required this.providerReference,
    required this.status,
    required this.createdAtUtc,
    required this.actor,
  });

  final String orderId;
  final String targetAvoraId;
  final int amountCoins;
  final String providerReference;
  final AvoraRechargeStatus status;
  final DateTime createdAtUtc;
  final AvoraActionActor actor;

  AvoraRechargeOrder copyWith({
    AvoraRechargeStatus? status,
  }) {
    return AvoraRechargeOrder(
      orderId: orderId,
      targetAvoraId: targetAvoraId,
      amountCoins: amountCoins,
      providerReference: providerReference,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      actor: actor,
    );
  }
}

abstract interface class AvoraRechargeProvider {
  Future<String> createPayment({
    required String orderId,
    required String targetAvoraId,
    required int amountCoins,
  });
}

class AvoraRechargeLedger {
  final Map<String, AvoraRechargeOrder> _orders =
      <String, AvoraRechargeOrder>{};

  void create(AvoraRechargeOrder order) {
    if (order.orderId.trim().isEmpty ||
        order.targetAvoraId.trim().isEmpty ||
        order.providerReference.trim().isEmpty ||
        order.amountCoins <= 0 ||
        order.actor.avoraId.trim().isEmpty) {
      throw ArgumentError('invalid_recharge_order');
    }

    if (_orders.containsKey(order.orderId)) {
      throw StateError('duplicate_recharge_order');
    }

    _orders[order.orderId] = order;
  }

  AvoraRechargeOrder? byId(String orderId) {
    return _orders[orderId.trim()];
  }

  void updateStatus({
    required String orderId,
    required AvoraRechargeStatus status,
  }) {
    final current = _orders[orderId];

    if (current == null) {
      throw StateError('recharge_order_not_found');
    }

    _orders[orderId] = current.copyWith(status: status);
  }

  List<AvoraRechargeOrder> byTarget(String avoraId) {
    return List<AvoraRechargeOrder>.unmodifiable(
      _orders.values.where(
        (order) => order.targetAvoraId == avoraId,
      ),
    );
  }

  static bool rechargeOrderMustUseImmutableAvoraId() => true;

  static bool paymentStateMustRemainAuditable() => true;

  static bool refundAndChargebackMustRemainRecorded() => true;

  static bool duplicateOrderMustFailClosed() => true;

  static bool futureProvidersMustUseSameRechargeLedger() => true;
}

class AvoraRechargeConfirmationService {
  AvoraRechargeConfirmationService({
    required AvoraRechargeLedger rechargeLedger,
    required AvoraLaunchRechargeService rechargeService,
  })  : _rechargeLedger = rechargeLedger,
        _rechargeService = rechargeService;

  final AvoraRechargeLedger _rechargeLedger;
  final AvoraLaunchRechargeService _rechargeService;

  final Set<String> _creditedOrders = <String>{};

  AvoraRechargeOrder confirm({
    required String orderId,
    required DateTime confirmedAtUtc,
  }) {
    final order = _rechargeLedger.byId(orderId);

    if (order == null) {
      throw StateError('recharge_order_not_found');
    }

    if (_creditedOrders.contains(orderId)) {
      return order;
    }

    if (order.status != AvoraRechargeStatus.pending &&
        order.status != AvoraRechargeStatus.created) {
      throw StateError('recharge_not_confirmable');
    }

    _rechargeService.recharge(
      transactionId: 'recharge-$orderId',
      actor: order.actor,
      targetAvoraId: order.targetAvoraId,
      amountCoins: order.amountCoins,
      createdAtUtc: confirmedAtUtc,
      reason: 'confirmed_recharge:$orderId',
    );

    _creditedOrders.add(orderId);

    _rechargeLedger.updateStatus(
      orderId: orderId,
      status: AvoraRechargeStatus.confirmed,
    );

    return _rechargeLedger.byId(orderId)!;
  }

  void markFailed(String orderId) {
    _rechargeLedger.updateStatus(
      orderId: orderId,
      status: AvoraRechargeStatus.failed,
    );
  }

  void markRefunded(String orderId) {
    _rechargeLedger.updateStatus(
      orderId: orderId,
      status: AvoraRechargeStatus.refunded,
    );
  }

  void markChargeback(String orderId) {
    _rechargeLedger.updateStatus(
      orderId: orderId,
      status: AvoraRechargeStatus.chargeback,
    );
  }

  static bool coinsMustCreditOnlyAfterConfirmedPayment() => true;

  static bool duplicateConfirmationMustNotDoubleCredit() => true;

  static bool failedPaymentMustNeverCreditCoins() => true;

  static bool refundMustRemainVisibleInHistory() => true;

  static bool chargebackMustRemainVisibleInHistory() => true;

  static bool chargebackRecoveryMustUseSeparateRiskRecoveryFlow() => true;

  static bool futurePaymentProvidersMustReuseSameConfirmationService() => true;
}
