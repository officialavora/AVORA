enum AvoraCountryAccessMode {
  selectedCountries,
  allCountries,
}

enum AvoraCountryDataDomain {
  users,
  rooms,
  agencies,
  sellers,
  merchants,
  recharge,
  payments,
  withdrawals,
  payouts,
  gifts,
  events,
  festivals,
  moderation,
  reports,
  analytics,
  audit,
}

enum AvoraCountryAccessDenyReason {
  none,
  assignmentDisabled,
  assignmentNotActive,
  countryOutsideScope,
  functionalPermissionRequired,
  globalScopeNotAllowed,
}

class AvoraCountryDataAccessAssignment {
  final String id;

  final String userId;

  final AvoraCountryAccessMode mode;

  /// ISO country codes such as IN, SA, BD, NP, PK.
  ///
  /// Used when mode == selectedCountries.
  final Set<String> countryCodes;

  final String grantedByUserId;

  final DateTime startsAt;
  final DateTime? expiresAt;

  final bool enabled;

  const AvoraCountryDataAccessAssignment({
    required this.id,
    required this.userId,
    required this.mode,
    required this.countryCodes,
    required this.grantedByUserId,
    required this.startsAt,
    this.expiresAt,
    this.enabled = true,
  });

  bool isActiveAt(DateTime time) {
    if (!enabled) {
      return false;
    }

    if (time.isBefore(startsAt)) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && time.isAfter(expiry)) {
      return false;
    }

    return true;
  }

  bool containsCountry(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();

    return countryCodes.any(
      (item) => item.trim().toUpperCase() == normalized,
    );
  }
}

class AvoraCountryDataAccessDecision {
  final bool allowed;

  final AvoraCountryAccessDenyReason reason;

  final String countryCode;

  final AvoraCountryDataDomain domain;

  const AvoraCountryDataAccessDecision({
    required this.allowed,
    required this.reason,
    required this.countryCode,
    required this.domain,
  });
}

class AvoraCountryDataAccessGate {
  const AvoraCountryDataAccessGate._();

  static AvoraCountryDataAccessDecision evaluate({
    required AvoraCountryDataAccessAssignment assignment,
    required String requestedCountryCode,
    required AvoraCountryDataDomain domain,
    required DateTime now,

    /// Result from AVORA Functional Permission Engine.
    required bool functionalPermissionAllowed,

    /// Only Owner/global-authorized staff should normally
    /// pass true here.
    required bool allowAllCountriesScope,
  }) {
    final country = requestedCountryCode.trim().toUpperCase();

    AvoraCountryDataAccessDecision deny(
      AvoraCountryAccessDenyReason reason,
    ) {
      return AvoraCountryDataAccessDecision(
        allowed: false,
        reason: reason,
        countryCode: country,
        domain: domain,
      );
    }

    if (!assignment.enabled) {
      return deny(
        AvoraCountryAccessDenyReason.assignmentDisabled,
      );
    }

    if (!assignment.isActiveAt(now)) {
      return deny(
        AvoraCountryAccessDenyReason.assignmentNotActive,
      );
    }

    if (!functionalPermissionAllowed) {
      return deny(
        AvoraCountryAccessDenyReason.functionalPermissionRequired,
      );
    }

    if (assignment.mode == AvoraCountryAccessMode.allCountries) {
      if (!allowAllCountriesScope) {
        return deny(
          AvoraCountryAccessDenyReason.globalScopeNotAllowed,
        );
      }

      return AvoraCountryDataAccessDecision(
        allowed: true,
        reason: AvoraCountryAccessDenyReason.none,
        countryCode: country,
        domain: domain,
      );
    }

    if (!assignment.containsCountry(country)) {
      return deny(
        AvoraCountryAccessDenyReason.countryOutsideScope,
      );
    }

    return AvoraCountryDataAccessDecision(
      allowed: true,
      reason: AvoraCountryAccessDenyReason.none,
      countryCode: country,
      domain: domain,
    );
  }
}
