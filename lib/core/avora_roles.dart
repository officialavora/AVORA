enum AvoraAuthorityRole {
  user,
  agency,
  bd,
  admin,
  superAdmin,
  manager,
  owner,
}

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

class AvoraRoleStructure {
  static const Set<AvoraAuthorityRole> launchRoles = {
    AvoraAuthorityRole.manager,
    AvoraAuthorityRole.bd,
    AvoraAuthorityRole.agency,
    AvoraAuthorityRole.user,
  };

  static const Map<AvoraAuthorityRole, Set<AvoraAuthorityRole>> canAssign = {
    AvoraAuthorityRole.owner: {
      AvoraAuthorityRole.manager,
      AvoraAuthorityRole.superAdmin,
      AvoraAuthorityRole.admin,
      AvoraAuthorityRole.bd,
      AvoraAuthorityRole.agency,
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.manager: {
      AvoraAuthorityRole.superAdmin,
      AvoraAuthorityRole.admin,
      AvoraAuthorityRole.bd,
      AvoraAuthorityRole.agency,
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.superAdmin: {
      AvoraAuthorityRole.admin,
      AvoraAuthorityRole.bd,
      AvoraAuthorityRole.agency,
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.admin: {
      AvoraAuthorityRole.bd,
      AvoraAuthorityRole.agency,
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.bd: {
      AvoraAuthorityRole.agency,
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.agency: {
      AvoraAuthorityRole.user,
    },
    AvoraAuthorityRole.user: {},
  };
}
