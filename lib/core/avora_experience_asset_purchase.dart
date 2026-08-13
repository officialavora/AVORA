import 'avora_actor_presentation.dart';
import 'avora_experience_asset_registry.dart';
import 'avora_wallet_freeze_enforcement.dart';

class AvoraExperienceAssetPurchaseRecord {
  const AvoraExperienceAssetPurchaseRecord({
    required this.purchaseId,
    required this.assetId,
    required this.assetVersion,
    required this.buyerAvoraId,
    required this.recipientAvoraId,
    required this.chargedCoins,
    required this.createdAtUtc,
  });

  final String purchaseId;
  final String assetId;
  final String assetVersion;
  final String buyerAvoraId;
  final String recipientAvoraId;
  final int chargedCoins;
  final DateTime createdAtUtc;
}

class AvoraExperienceAssetPurchaseLedger {
  final Map<String, AvoraExperienceAssetPurchaseRecord> _records =
      <String, AvoraExperienceAssetPurchaseRecord>{};

  void append(AvoraExperienceAssetPurchaseRecord record) {
    if (_records.containsKey(record.purchaseId)) {
      throw StateError('duplicate_experience_asset_purchase');
    }

    if (record.purchaseId.trim().isEmpty ||
        record.assetId.trim().isEmpty ||
        record.assetVersion.trim().isEmpty ||
        record.buyerAvoraId.trim().isEmpty ||
        record.recipientAvoraId.trim().isEmpty ||
        record.chargedCoins < 0) {
      throw ArgumentError('invalid_experience_asset_purchase');
    }

    _records[record.purchaseId] = record;
  }

  AvoraExperienceAssetPurchaseRecord? byId(String purchaseId) {
    return _records[purchaseId];
  }

  static bool purchaseRecordsMustRemainImmutable() => true;

  static bool purchaseMustBindExactAssetVersion() => true;

  static bool purchaseMustRecordActualChargedCoins() => true;
}

class AvoraExperienceAssetPurchaseService {
  AvoraExperienceAssetPurchaseService({
    required AvoraExperienceAssetRegistry assetRegistry,
    required AvoraFreezeAwareWalletService walletService,
    required AvoraExperienceAssetPurchaseLedger purchaseLedger,
  })  : _assetRegistry = assetRegistry,
        _walletService = walletService,
        _purchaseLedger = purchaseLedger;

  final AvoraExperienceAssetRegistry _assetRegistry;
  final AvoraFreezeAwareWalletService _walletService;
  final AvoraExperienceAssetPurchaseLedger _purchaseLedger;

  AvoraExperienceAssetPurchaseRecord purchase({
    required String purchaseId,
    required String assetId,
    required AvoraActionActor buyerActor,
    required String recipientAvoraId,
    required DateTime createdAtUtc,
  }) {
    final asset = _assetRegistry.activeById(assetId);

    if (asset == null) {
      throw StateError('experience_asset_not_found');
    }

    if (!asset.enabled) {
      throw StateError('experience_asset_disabled');
    }

    if (_purchaseLedger.byId(purchaseId) != null) {
      throw StateError('duplicate_experience_asset_purchase');
    }

    final chargedCoins = asset.coinPrice;

    if (chargedCoins > 0) {
      _walletService.spend(
        transactionId: 'experience:$purchaseId',
        actor: buyerActor,
        targetAvoraId: buyerActor.avoraId,
        amountCoins: chargedCoins,
        createdAtUtc: createdAtUtc.toUtc(),
        reason: 'experience_asset:$assetId:${asset.version}',
        purpose: AvoraWalletSpendPurpose.purchase,
      );
    }

    final record = AvoraExperienceAssetPurchaseRecord(
      purchaseId: purchaseId,
      assetId: asset.assetId,
      assetVersion: asset.version,
      buyerAvoraId: buyerActor.avoraId,
      recipientAvoraId: recipientAvoraId,
      chargedCoins: chargedCoins,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _purchaseLedger.append(record);
    return record;
  }

  static bool activeOwnerConfiguredPriceMustBeAuthoritative() => true;

  static bool clientMustNeverSupplyAuthoritativeAssetPrice() => true;

  static bool disabledAssetMustNeverDebitWallet() => true;

  static bool freezeAwareWalletMustProtectAssetPurchases() => true;

  static bool giftAndEntryMustUseSamePurchaseFoundation() => true;

  static bool emojiGifSoundAndFutureAssetsMayUseSameFoundation() => true;

  static bool priceChangeMustApplyWithoutClientRelease() => true;

  static bool historicalPurchaseMustKeepOriginalAssetVersion() => true;
}
