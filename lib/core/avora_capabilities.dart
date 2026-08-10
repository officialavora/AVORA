enum AvoraCommerceRole {
  none,
  seller,
  merchant,
}

enum AvoraStaffAssignment {
  none,
  countryManager,
  csHead,
  customerService,
  eventOrganizer,
}

enum AvoraScopeType {
  self,
  agency,
  team,
  country,
  region,
  global,
}

class AvoraCapabilityProfile {
  final AvoraCommerceRole commerceRole;
  final Set<AvoraStaffAssignment> staffAssignments;
  final AvoraScopeType scopeType;
  final String? countryCode;
  final String? regionCode;

  const AvoraCapabilityProfile({
    this.commerceRole = AvoraCommerceRole.none,
    this.staffAssignments = const {},
    this.scopeType = AvoraScopeType.self,
    this.countryCode,
    this.regionCode,
  });
}
