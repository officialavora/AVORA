enum AvoraCommerceEntityKind {
  seller,
  merchant,
}

class AvoraCommerceBenefitSnapshot {
  const AvoraCommerceBenefitSnapshot({
    this.frameCode,
    this.badgeCode,
    this.bubbleCode,
    this.nobilityCode,
    this.vipCode,
    this.svipCode,
    this.uniqueIdStyleCode,
  });

  final String? frameCode;
  final String? badgeCode;
  final String? bubbleCode;
  final String? nobilityCode;
  final String? vipCode;
  final String? svipCode;
  final String? uniqueIdStyleCode;
}

class AvoraOwnerCommerceEntityRecord {
  const AvoraOwnerCommerceEntityRecord({
    required this.avoraId,
    required this.kind,
    required this.countryCode,
    required this.active,
    required this.coinBalanceMinor,
    required this.liquidityMinor,
    required this.amountDueMinor,
    required this.turnoverMinor,
    required this.benefits,
  });

  final String avoraId;
  final AvoraCommerceEntityKind kind;
  final String countryCode;
  final bool active;

  final int coinBalanceMinor;
  final int liquidityMinor;
  final int amountDueMinor;
  final int turnoverMinor;

  final AvoraCommerceBenefitSnapshot benefits;

  void validate() {
    if (avoraId.trim().isEmpty || countryCode.trim().isEmpty) {
      throw StateError('commerce_entity_identity_required');
    }

    if (coinBalanceMinor < 0 ||
        liquidityMinor < 0 ||
        amountDueMinor < 0 ||
        turnoverMinor < 0) {
      throw StateError('commerce_entity_amount_cannot_be_negative');
    }
  }
}

class AvoraOwnerCommerceRegistryQuery {
  const AvoraOwnerCommerceRegistryQuery({
    this.countryCode,
    this.kind,
    this.includeInactive = false,
    this.selectedAvoraIds = const <String>{},
  });

  final String? countryCode;
  final AvoraCommerceEntityKind? kind;
  final bool includeInactive;
  final Set<String> selectedAvoraIds;
}

class AvoraOwnerSellerMerchantRegistry {
  const AvoraOwnerSellerMerchantRegistry._();

  static List<AvoraOwnerCommerceEntityRecord> resolve({
    required List<AvoraOwnerCommerceEntityRecord> records,
    required AvoraOwnerCommerceRegistryQuery query,
  }) {
    final country = query.countryCode?.trim().toUpperCase();

    final result = records.where((record) {
      record.validate();

      if (!query.includeInactive && !record.active) {
        return false;
      }

      if (query.kind != null && record.kind != query.kind) {
        return false;
      }

      if (country != null &&
          country.isNotEmpty &&
          record.countryCode.trim().toUpperCase() != country) {
        return false;
      }

      if (query.selectedAvoraIds.isNotEmpty &&
          !query.selectedAvoraIds.contains(record.avoraId)) {
        return false;
      }

      return true;
    }).toList(growable: false);

    return List.unmodifiable(result);
  }

  static int totalTurnoverMinor(
    List<AvoraOwnerCommerceEntityRecord> records,
  ) {
    return records.fold<int>(
      0,
      (sum, record) => sum + record.turnoverMinor,
    );
  }

  static int totalAmountDueMinor(
    List<AvoraOwnerCommerceEntityRecord> records,
  ) {
    return records.fold<int>(
      0,
      (sum, record) => sum + record.amountDueMinor,
    );
  }

  static bool ownerIdentityAndPanelMustShareSameRegistrySource() => true;

  static bool benefitMutationsMustUseExistingAuthoritativeInventory() => true;

  static bool sellerAndMerchantMustRemainDistinctWhenPolicyRequires() => true;

  static bool delegatedAccessMustRemainScopeBound() => true;

  static bool everyGrantAndRevokeMustRemainAudited() => true;
}
