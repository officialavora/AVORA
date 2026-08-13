enum AvoraCountryDisplayMode {
  hidden,
  countryOnly,
  flagOnly,
  countryAndFlag,
}

class AvoraProfileCountryVisibility {
  const AvoraProfileCountryVisibility({
    required this.avoraId,
    required this.mode,
    required this.authoritativeCountryCode,
    required this.displayCountryCode,
    required this.updatedByAvoraId,
    required this.reason,
    required this.updatedAtUtc,
  });

  final String avoraId;

  /// Backend authority/compliance country.
  /// Must remain separate from UI display.
  final String authoritativeCountryCode;

  /// Optional display country. Can be blank when hidden.
  final String displayCountryCode;

  final AvoraCountryDisplayMode mode;

  final String updatedByAvoraId;
  final String reason;
  final DateTime updatedAtUtc;

  bool get showCountry =>
      mode == AvoraCountryDisplayMode.countryOnly ||
      mode == AvoraCountryDisplayMode.countryAndFlag;

  bool get showFlag =>
      mode == AvoraCountryDisplayMode.flagOnly ||
      mode == AvoraCountryDisplayMode.countryAndFlag;

  bool get hidden => mode == AvoraCountryDisplayMode.hidden;
}

class AvoraProfileCountryVisibilityPolicy {
  const AvoraProfileCountryVisibilityPolicy._();

  static bool displayCountryMustNotControlAuthorityScope() => true;

  static bool ownerIdMayHideCountryAndFlag() => true;

  static bool ownerIdMayShowCountryAndFlag() => true;

  static bool ownerMayOverrideAnyProfileVisibility() => true;

  static bool hiddenDisplayMustNotEraseAuthoritativeCountry() => true;

  static bool permissionsMustUseAuthoritativeCountryOnly() => true;

  static bool complianceMustUseAuthoritativeCountryOnly() => true;

  static bool paymentRulesMustUseAuthoritativeCountryOnly() => true;

  static bool visibilityChangesMustBeAudited() => true;

  static bool futureCountryArchitectureMustKeepDisplaySeparate() => true;
}
