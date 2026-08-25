import 'package:avora/core/avora_account_deletion.dart';
import 'package:avora/core/avora_actor_presentation.dart';
import 'package:avora/core/avora_coin_pricing.dart';
import 'package:avora/core/avora_community_rules.dart';
import 'package:avora/core/avora_identity_cosmetics.dart';
import 'package:avora/core/avora_launch_recharge_provider.dart';
import 'package:avora/core/avora_presence_privacy.dart';
import 'package:avora/core/avora_recharge_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

class _RechargeProvider implements AvoraRechargeProvider {
  @override
  Future<String> createPayment({
    required String orderId,
    required String targetAvoraId,
    required int amountCoins,
  }) async =>
      'provider-$orderId';
}

void main() {
  test('required AVORA policies are versioned and complete', () {
    final acceptedAt = DateTime.utc(2026, 8, 25);
    final acceptances = [
      for (final document in AvoraCommunityRules.requiredSignupDocuments)
        AvoraPolicyAcceptance(
          avoraId: '1001',
          documentType: document.type,
          documentVersion: document.version,
          acceptedAtUtc: acceptedAt,
        ),
    ];

    expect(
      AvoraCommunityRules.hasAcceptedEveryRequiredDocument(
        acceptances: acceptances,
      ),
      isTrue,
    );
  });

  test('frame, noble and entry remain independent identity layers', () {
    final loadout = AvoraIdentityCosmeticLoadout();
    final now = DateTime.utc(2026, 8, 25);

    for (final layer in <AvoraIdentityCosmeticLayer>[
      AvoraIdentityCosmeticLayer.frame,
      AvoraIdentityCosmeticLayer.noble,
      AvoraIdentityCosmeticLayer.entry,
    ]) {
      loadout.select(
        AvoraIdentityCosmeticSelection(
          avoraId: '1001',
          layer: layer,
          assetId: 'avora-${layer.name}',
          entitlementId: 'entitlement-${layer.name}',
          selectedAtUtc: now,
        ),
      );
    }

    expect(loadout.snapshot(), hasLength(3));
  });

  test('one recharge creates one pending order with immutable pricing', () async {
    final now = DateTime.utc(2026, 8, 25);
    final ledger = AvoraRechargeLedger();
    final service = AvoraRechargeOrchestrator(
      provider: _RechargeProvider(),
      ledger: ledger,
    );

    final result = await service.create(
      orderId: 'order-1',
      payerAvoraId: '1001',
      requestedRecipientAvoraId: null,
      beneficiaryMode: AvoraRechargeBeneficiaryMode.myself,
      package: AvoraCoinPackageDefinition(
        packageId: 'avora-100',
        version: 1,
        baseCoinUnits: 100,
        bonusCoinUnits: 10,
        usdReferenceMicros: 1000000,
        effectiveFrom: now.subtract(const Duration(days: 1)),
      ),
      localQuote: AvoraLocalCurrencyQuote(
        quoteId: 'quote-1',
        currencyCode: 'SAR',
        baseAmountMinor: 375,
        feeAmountMinor: 0,
        taxAmountMinor: 0,
        fractionDigits: 2,
        quotedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        providerQuoteRef: 'provider-quote-1',
      ),
      actor: const AvoraActionActor(
        avoraId: '1001',
        kind: AvoraActorKind.user,
        displayName: 'AVORA User',
      ),
      nowUtc: now,
    );

    expect(result.created, isTrue);
    expect(result.order?.status, AvoraRechargeStatus.pending);
    expect(result.pricingSnapshot?.totalCoinUnits, 110);
    expect(ledger.byTarget('1001'), hasLength(1));
  });

  test('account deletion has a cancellable grace period', () {
    const service = AvoraAccountDeletionService();
    final now = DateTime.utc(2026, 8, 25);
    final request = service.request(
      requestId: 'delete-1',
      avoraId: '1001',
      nowUtc: now,
    );

    expect(request.cancel(now.add(const Duration(days: 1))).status,
        AvoraAccountDeletionStatus.cancelled);
  });

  test('presence privacy blocks unrelated viewers', () {
    expect(
      AvoraPresencePrivacyPolicy.canView(
        settings: const AvoraPresencePrivacySettings(),
        viewer: const AvoraPresenceViewerContext(
          sameUser: false,
          viewerFollows: true,
          friends: false,
          blockedEitherDirection: false,
        ),
      ),
      isFalse,
    );
  });
}
