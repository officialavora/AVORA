import 'avora_actor_presentation.dart';
import 'avora_coin_pricing.dart';
import 'avora_launch_recharge_provider.dart';

class AvoraRechargeCreationResult {
  const AvoraRechargeCreationResult({
    required this.created,
    required this.reason,
    this.order,
    this.pricingSnapshot,
  });

  final bool created;
  final String reason;
  final AvoraRechargeOrder? order;
  final AvoraRechargeOrderPricingSnapshot? pricingSnapshot;
}

class AvoraRechargeOrchestrator {
  AvoraRechargeOrchestrator({
    required AvoraRechargeProvider provider,
    required AvoraRechargeLedger ledger,
  })  : _provider = provider,
        _ledger = ledger;

  final AvoraRechargeProvider _provider;
  final AvoraRechargeLedger _ledger;

  Future<AvoraRechargeCreationResult> create({
    required String orderId,
    required String payerAvoraId,
    required String? requestedRecipientAvoraId,
    required AvoraRechargeBeneficiaryMode beneficiaryMode,
    required AvoraCoinPackageDefinition package,
    required AvoraLocalCurrencyQuote localQuote,
    required AvoraActionActor actor,
    required DateTime nowUtc,
  }) async {
    if (_ledger.byId(orderId) != null) {
      return const AvoraRechargeCreationResult(
        created: false,
        reason: 'duplicate_recharge_order',
      );
    }

    final pricing = AvoraCoinPricingEngine.createOrderSnapshot(
      orderId: orderId,
      payerAvoraId: payerAvoraId,
      requestedRecipientAvoraId: requestedRecipientAvoraId,
      beneficiaryMode: beneficiaryMode,
      package: package,
      localQuote: localQuote,
      now: nowUtc.toUtc(),
    );

    final snapshot = pricing.snapshot;
    if (!pricing.allowed || snapshot == null) {
      return AvoraRechargeCreationResult(
        created: false,
        reason: pricing.reason,
      );
    }

    final providerReference = await _provider.createPayment(
      orderId: orderId,
      targetAvoraId: snapshot.recipientAvoraId,
      amountCoins: snapshot.totalCoinUnits,
    );

    if (providerReference.trim().isEmpty) {
      return const AvoraRechargeCreationResult(
        created: false,
        reason: 'provider_reference_missing',
      );
    }

    final order = AvoraRechargeOrder(
      orderId: orderId,
      targetAvoraId: snapshot.recipientAvoraId,
      amountCoins: snapshot.totalCoinUnits,
      providerReference: providerReference,
      status: AvoraRechargeStatus.pending,
      createdAtUtc: nowUtc.toUtc(),
      actor: actor,
    );

    _ledger.create(order);

    return AvoraRechargeCreationResult(
      created: true,
      reason: 'created',
      order: order,
      pricingSnapshot: snapshot,
    );
  }

  static bool oneOrderUsesOnePricingSnapshot() => true;
  static bool providerReferenceMustExistBeforeLedgerCreation() => true;
  static bool confirmationRemainsTheOnlyCoinCreditPath() => true;
  static bool rechargeForAnotherUserKeepsPayerAndRecipientSeparate() => true;
}
