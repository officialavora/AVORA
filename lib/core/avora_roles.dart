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
  customerService,
  customerServiceHead,
  eventManager,
  countryManager,
  regionalManager,
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
  String get key => name;

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

extension AvoraCommerceRoleX on AvoraCommerceRole {
  String get title {
    switch (this) {
      case AvoraCommerceRole.merchant:
        return 'Merchant';
      case AvoraCommerceRole.seller:
        return 'Seller';
      case AvoraCommerceRole.none:
        return 'None';
    }
  }
}

extension AvoraStaffAssignmentX on AvoraStaffAssignment {
  String get title {
    switch (this) {
      case AvoraStaffAssignment.countryManager:
        return 'Country Manager';
      case AvoraStaffAssignment.regionalManager:
        return 'Regional Manager';
      case AvoraStaffAssignment.customerServiceHead:
        return 'CS Head';
      case AvoraStaffAssignment.customerService:
        return 'Customer Service';
      case AvoraStaffAssignment.eventManager:
        return 'Event Manager';
    }
  }
}

class AvoraRoleStructure {
  static const Set<AvoraAuthorityRole> launchAuthorityRoles = {
    AvoraAuthorityRole.manager,
    AvoraAuthorityRole.bd,
    AvoraAuthorityRole.agency,
    AvoraAuthorityRole.user,
  };

  static const Set<AvoraCommerceRole> launchCommerceRoles = {
    AvoraCommerceRole.seller,
  };

  static const Map<AvoraAuthorityRole, int> authorityRank = {
    AvoraAuthorityRole.user: 0,
    AvoraAuthorityRole.agency: 10,
    AvoraAuthorityRole.bd: 20,
    AvoraAuthorityRole.admin: 30,
    AvoraAuthorityRole.superAdmin: 40,
    AvoraAuthorityRole.manager: 50,
    AvoraAuthorityRole.owner: 100,
  };

  static bool canAssignRole(
    AvoraAuthorityRole actor,
    AvoraAuthorityRole target,
  ) {
    if (actor == AvoraAuthorityRole.owner) {
      return target != AvoraAuthorityRole.owner;
    }

    return (authorityRank[actor] ?? 0) > (authorityRank[target] ?? 0);
  }
}
