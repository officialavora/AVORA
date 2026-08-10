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
      case AvoraStaffAssignment.customerService:
        return 'Customer Service';
      case AvoraStaffAssignment.csHead:
        return 'CS Head';
      case AvoraStaffAssignment.eventOrganizer:
        return 'Event Organizer';
      case AvoraStaffAssignment.countryManager:
        return 'Country Manager';
      case AvoraStaffAssignment.none:
        return 'None';
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

  static const Map<AvoraAuthorityRole, Set<AvoraAuthorityRole>> canAppoint = {
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

  static const Set<AvoraAuthorityRole> launchAuthorityRoles = {
    AvoraAuthorityRole.manager,
    AvoraAuthorityRole.bd,
    AvoraAuthorityRole.agency,
    AvoraAuthorityRole.user,
  };

  static const Set<AvoraCommerceRole> launchCommerceRoles = {
    AvoraCommerceRole.seller,
  };
}
