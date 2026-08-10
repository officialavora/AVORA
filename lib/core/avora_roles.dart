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
  customerService,
  csHead,
  eventOrganizer,
  countryManager,
}

enum AvoraScopeType {
  self,
  agency,
  team,
  country,
  region,
  global,
}

extension AvoraAuthorityRoleX on AvoraAuthorityRole {
  String get title {
    switch (this) {
      case AvoraAuthorityRole.owner:
        return 'Owner';
      case AvoraAuthorityRole.manager:
        return 'Manager';
      case AvoraAuthorityRole.superAdmin:
        return 'Super Admin';
      case AvoraAuthorityRole.admin:
        return 'Admin';
      case AvoraAuthorityRole.bd:
        return 'BD';
      case AvoraAuthorityRole.agency:
        return 'Agency';
      case AvoraAuthorityRole.user:
        return 'User';
    }
  }
}

class AvoraRoleStructure {
  static const Map<AvoraAuthorityRole, int> authorityRank = {
    AvoraAuthorityRole.user: 0,
    AvoraAuthorityRole.agency: 10,
    AvoraAuthorityRole.bd: 20,
    AvoraAuthorityRole.admin: 30,
    AvoraAuthorityRole.superAdmin: 40,
    AvoraAuthorityRole.manager: 50,
    AvoraAuthorityRole.owner: 100,
  };

  static bool isHigherAuthority(
    AvoraAuthorityRole actor,
    AvoraAuthorityRole target,
  ) {
    return (authorityRank[actor] ?? 0) > (authorityRank[target] ?? 0);
  }

  static bool managerCanAssign(AvoraAuthorityRole target) {
    return target != AvoraAuthorityRole.owner &&
        target != AvoraAuthorityRole.manager;
  }
}
