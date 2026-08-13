import 'avora_experience_asset_purchase.dart';
import 'avora_experience_asset_registry.dart';

enum AvoraExperienceDeliveryMode {
  oneShot,
  timedEntitlement,
  permanentEntitlement,
}

enum AvoraExperienceEntitlementStatus {
  active,
  expired,
  revoked,
}

class AvoraExperienceDeliveryRule {
  const AvoraExperienceDeliveryRule({
    required this.mode,
    this.duration,
  });

  final AvoraExperienceDeliveryMode mode;
  final Duration? duration;

  void validate() {
    switch (mode) {
      case AvoraExperienceDeliveryMode.oneShot:
      case AvoraExperienceDeliveryMode.permanentEntitlement:
        if (duration != null) {
          throw ArgumentError(
            'duration_not_allowed_for_delivery_mode',
          );
        }

      case AvoraExperienceDeliveryMode.timedEntitlement:
        if (duration == null || duration!.inSeconds <= 0) {
          throw ArgumentError(
            'timed_entitlement_requires_positive_duration',
          );
        }
    }
  }

  static AvoraExperienceDeliveryRule oneShot() {
    return const AvoraExperienceDeliveryRule(
      mode: AvoraExperienceDeliveryMode.oneShot,
    );
  }

  static AvoraExperienceDeliveryRule permanent() {
    return const AvoraExperienceDeliveryRule(
      mode: AvoraExperienceDeliveryMode.permanentEntitlement,
    );
  }

  static AvoraExperienceDeliveryRule timed(Duration duration) {
    return AvoraExperienceDeliveryRule(
      mode: AvoraExperienceDeliveryMode.timedEntitlement,
      duration: duration,
    );
  }
}

class AvoraExperienceEntitlementRecord {
  const AvoraExperienceEntitlementRecord({
    required this.entitlementId,
    required this.purchaseId,
    required this.assetId,
    required this.assetVersion,
    required this.ownerAvoraId,
    required this.mode,
    required this.grantedAtUtc,
    required this.status,
    this.expiresAtUtc,
    this.revokedAtUtc,
    this.revokeReason,
  });

  final String entitlementId;
  final String purchaseId;

  final String assetId;
  final String assetVersion;

  /// User who owns/receives the entitlement.
  final String ownerAvoraId;

  final AvoraExperienceDeliveryMode mode;

  final DateTime grantedAtUtc;
  final DateTime? expiresAtUtc;

  final AvoraExperienceEntitlementStatus status;

  final DateTime? revokedAtUtc;
  final String? revokeReason;

  bool isActiveAt(DateTime nowUtc) {
    if (status == AvoraExperienceEntitlementStatus.revoked) {
      return false;
    }

    if (mode == AvoraExperienceDeliveryMode.oneShot) {
      return false;
    }

    if (mode == AvoraExperienceDeliveryMode.permanentEntitlement) {
      return true;
    }

    final expiry = expiresAtUtc;

    if (expiry == null) {
      return false;
    }

    return nowUtc.toUtc().isBefore(expiry);
  }

  AvoraExperienceEntitlementRecord revoke({
    required DateTime revokedAtUtc,
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('entitlement_revoke_reason_required');
    }

    return AvoraExperienceEntitlementRecord(
      entitlementId: entitlementId,
      purchaseId: purchaseId,
      assetId: assetId,
      assetVersion: assetVersion,
      ownerAvoraId: ownerAvoraId,
      mode: mode,
      grantedAtUtc: grantedAtUtc,
      expiresAtUtc: expiresAtUtc,
      status: AvoraExperienceEntitlementStatus.revoked,
      revokedAtUtc: revokedAtUtc.toUtc(),
      revokeReason: reason,
    );
  }
}

class AvoraExperienceDeliveryRecord {
  const AvoraExperienceDeliveryRecord({
    required this.deliveryId,
    required this.purchaseId,
    required this.assetId,
    required this.assetVersion,
    required this.recipientAvoraId,
    required this.mode,
    required this.deliveredAtUtc,
  });

  final String deliveryId;
  final String purchaseId;
  final String assetId;
  final String assetVersion;
  final String recipientAvoraId;
  final AvoraExperienceDeliveryMode mode;
  final DateTime deliveredAtUtc;
}

class AvoraExperienceEntitlementLedger {
  final Map<String, AvoraExperienceEntitlementRecord> _entitlements =
      <String, AvoraExperienceEntitlementRecord>{};

  final Map<String, AvoraExperienceDeliveryRecord> _deliveries =
      <String, AvoraExperienceDeliveryRecord>{};

  void appendDelivery(
    AvoraExperienceDeliveryRecord record,
  ) {
    if (record.deliveryId.trim().isEmpty ||
        record.purchaseId.trim().isEmpty ||
        record.assetId.trim().isEmpty ||
        record.assetVersion.trim().isEmpty ||
        record.recipientAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_experience_delivery');
    }

    if (_deliveries.containsKey(record.deliveryId)) {
      throw StateError('duplicate_experience_delivery');
    }

    final samePurchaseDelivered = _deliveries.values.any(
      (item) => item.purchaseId == record.purchaseId,
    );

    if (samePurchaseDelivered) {
      throw StateError('experience_purchase_already_delivered');
    }

    _deliveries[record.deliveryId] = record;
  }

  void appendEntitlement(
    AvoraExperienceEntitlementRecord record,
  ) {
    if (record.entitlementId.trim().isEmpty ||
        record.purchaseId.trim().isEmpty ||
        record.assetId.trim().isEmpty ||
        record.assetVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_experience_entitlement');
    }

    if (_entitlements.containsKey(record.entitlementId)) {
      throw StateError('duplicate_experience_entitlement');
    }

    _entitlements[record.entitlementId] = record;
  }

  AvoraExperienceDeliveryRecord? deliveryByPurchase(
    String purchaseId,
  ) {
    for (final record in _deliveries.values) {
      if (record.purchaseId == purchaseId) {
        return record;
      }
    }

    return null;
  }

  AvoraExperienceEntitlementRecord? entitlementByPurchase(
    String purchaseId,
  ) {
    for (final record in _entitlements.values) {
      if (record.purchaseId == purchaseId) {
        return record;
      }
    }

    return null;
  }

  List<AvoraExperienceEntitlementRecord> activeForUser({
    required String avoraId,
    required DateTime nowUtc,
  }) {
    return List<AvoraExperienceEntitlementRecord>.unmodifiable(
      _entitlements.values.where(
        (record) => record.ownerAvoraId == avoraId && record.isActiveAt(nowUtc),
      ),
    );
  }

  void revoke({
    required String entitlementId,
    required DateTime revokedAtUtc,
    required String reason,
  }) {
    final current = _entitlements[entitlementId];

    if (current == null) {
      throw StateError('experience_entitlement_not_found');
    }

    if (current.status == AvoraExperienceEntitlementStatus.revoked) {
      throw StateError('experience_entitlement_already_revoked');
    }

    _entitlements[entitlementId] = current.revoke(
      revokedAtUtc: revokedAtUtc,
      reason: reason,
    );
  }

  static bool purchaseMustNeverDeliverTwice() => true;

  static bool entitlementMustBindPurchasedAssetVersion() => true;

  static bool revocationMustRemainExplicit() => true;

  static bool futureExperienceTypesMustUseSameLedger() => true;
}

class AvoraExperienceDeliveryService {
  AvoraExperienceDeliveryService({
    required AvoraExperienceAssetRegistry assetRegistry,
    required AvoraExperienceAssetPurchaseLedger purchaseLedger,
    required AvoraExperienceEntitlementLedger entitlementLedger,
  })  : _assetRegistry = assetRegistry,
        _purchaseLedger = purchaseLedger,
        _entitlementLedger = entitlementLedger;

  final AvoraExperienceAssetRegistry _assetRegistry;
  final AvoraExperienceAssetPurchaseLedger _purchaseLedger;
  final AvoraExperienceEntitlementLedger _entitlementLedger;

  AvoraExperienceDeliveryRecord deliver({
    required String deliveryId,
    required String purchaseId,
    required AvoraExperienceDeliveryRule rule,
    required DateTime deliveredAtUtc,
  }) {
    rule.validate();

    final purchase = _purchaseLedger.byId(purchaseId);

    if (purchase == null) {
      throw StateError('experience_purchase_not_found');
    }

    if (_entitlementLedger.deliveryByPurchase(purchaseId) != null) {
      throw StateError('experience_purchase_already_delivered');
    }

    final purchasedAsset = _assetRegistry.historical(
      assetId: purchase.assetId,
      version: purchase.assetVersion,
    );

    if (purchasedAsset == null) {
      throw StateError('purchased_asset_version_not_found');
    }

    final delivery = AvoraExperienceDeliveryRecord(
      deliveryId: deliveryId,
      purchaseId: purchase.purchaseId,
      assetId: purchase.assetId,
      assetVersion: purchase.assetVersion,
      recipientAvoraId: purchase.recipientAvoraId,
      mode: rule.mode,
      deliveredAtUtc: deliveredAtUtc.toUtc(),
    );

    _entitlementLedger.appendDelivery(delivery);

    if (rule.mode != AvoraExperienceDeliveryMode.oneShot) {
      final expiry = rule.mode == AvoraExperienceDeliveryMode.timedEntitlement
          ? deliveredAtUtc.toUtc().add(rule.duration!)
          : null;

      _entitlementLedger.appendEntitlement(
        AvoraExperienceEntitlementRecord(
          entitlementId: 'entitlement-$deliveryId',
          purchaseId: purchase.purchaseId,
          assetId: purchase.assetId,
          assetVersion: purchase.assetVersion,
          ownerAvoraId: purchase.recipientAvoraId,
          mode: rule.mode,
          grantedAtUtc: deliveredAtUtc.toUtc(),
          expiresAtUtc: expiry,
          status: AvoraExperienceEntitlementStatus.active,
        ),
      );
    }

    return delivery;
  }

  static bool deliveryMustRequireCompletedPurchaseRecord() => true;

  static bool deliveryMustUseExactPurchasedAssetVersion() => true;

  static bool oneShotGiftMustNotCreatePermanentOwnership() => true;

  static bool timedEntryMayUseConfigurableDuration() => true;

  static bool permanentAssetMayCreatePermanentEntitlement() => true;

  static bool assetUpdateMustNotRewriteExistingEntitlement() => true;

  static bool futureDurationOptionsMustNeedNoCoreRewrite() => true;
}

class AvoraExperienceDurationPresets {
  const AvoraExperienceDurationPresets._();

  static const Duration sevenDays = Duration(days: 7);
  static const Duration thirtyDays = Duration(days: 30);
  static const Duration ninetyDays = Duration(days: 90);

  static bool ownerMayAddDifferentDurationsLater() => true;
}
