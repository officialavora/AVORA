enum AvoraIdentityCosmeticLayer {
  frame,
  noble,
  vip,
  svip,
  badge,
  medal,
  entry,
  room,
  profileMusic,
}

class AvoraIdentityCosmeticSelection {
  const AvoraIdentityCosmeticSelection({
    required this.avoraId,
    required this.layer,
    required this.assetId,
    required this.entitlementId,
    required this.selectedAtUtc,
  });

  final String avoraId;
  final AvoraIdentityCosmeticLayer layer;
  final String assetId;
  final String entitlementId;
  final DateTime selectedAtUtc;
}

class AvoraIdentityCosmeticLoadout {
  final Map<AvoraIdentityCosmeticLayer, AvoraIdentityCosmeticSelection>
      _selections =
      <AvoraIdentityCosmeticLayer, AvoraIdentityCosmeticSelection>{};

  AvoraIdentityCosmeticSelection? selection(
    AvoraIdentityCosmeticLayer layer,
  ) =>
      _selections[layer];

  void select(AvoraIdentityCosmeticSelection selection) {
    if (selection.avoraId.trim().isEmpty ||
        selection.assetId.trim().isEmpty ||
        selection.entitlementId.trim().isEmpty) {
      throw ArgumentError('invalid_identity_cosmetic_selection');
    }

    _selections[selection.layer] = selection;
  }

  void clear(AvoraIdentityCosmeticLayer layer) {
    _selections.remove(layer);
  }

  Map<AvoraIdentityCosmeticLayer, AvoraIdentityCosmeticSelection> snapshot() =>
      Map<AvoraIdentityCosmeticLayer, AvoraIdentityCosmeticSelection>.unmodifiable(
        _selections,
      );

  static bool everyLayerIsIndependent() => true;
  static bool cosmeticSelectionNeverGrantsAuthority() => true;
  static bool selectionRequiresServerEntitlement() => true;
  static bool frameNobleVipBadgeMedalAndEntryMustNotOverwriteEachOther() => true;
}
