// AVORA Role & Capability Foundation
//
// Core authority:
// Owner -> Manager -> Super Admin -> Admin -> BD -> Agency -> User
//
// Seller, Merchant, Country Manager, CS Head, CS Agent and
// Event Organizer are capabilities/assignments, not fixed hierarchy rungs.

enum AvoraRole {
  owner,
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  user,
}

enum AvoraCapability {
  merchant,
  seller,
  countryManager,
  csHead,
  csAgent,
  eventOrganizer,
}

enum AvoraScopeType {
  global,
  region,
  country,
  agency,
  room,
  user,
}

class AvoraScope {
  final AvoraScopeType type;
  final String? id;

  const AvoraScope._(this.type, this.id);

  const AvoraScope.global() : this._(AvoraScopeType.global, null);

  const AvoraScope.region(String regionId)
      : this._(AvoraScopeType.region, regionId);

  const AvoraScope.country(String countryId)
      : this._(AvoraScopeType.country, countryId);

  const AvoraScope.agency(String agencyId)
      : this._(AvoraScopeType.agency, agencyId);

  const AvoraScope.room(String roomId) : this._(AvoraScopeType.room, roomId);

  const AvoraScope.user(String userId) : this._(AvoraScopeType.user, userId);

  bool get isGlobal => type == AvoraScopeType.global;

  bool covers(AvoraScope other) {
    if (isGlobal) {
      return true;
    }

    return type == other.type && id == other.id;
  }
}

extension AvoraRolePolicy on AvoraRole {
  int get authorityRank {
    switch (this) {
      case AvoraRole.owner:
        return 700;
      case AvoraRole.manager:
        return 600;
      case AvoraRole.superAdmin:
        return 500;
      case AvoraRole.admin:
        return 400;
      case AvoraRole.bd:
        return 300;
      case AvoraRole.agency:
        return 200;
      case AvoraRole.user:
        return 100;
    }
  }

  String get label {
    switch (this) {
      case AvoraRole.owner:
        return 'Owner';
      case AvoraRole.manager:
        return 'Manager';
      case AvoraRole.superAdmin:
        return 'Super Admin';
      case AvoraRole.admin:
        return 'Admin';
      case AvoraRole.bd:
        return 'BD';
      case AvoraRole.agency:
        return 'Agency';
      case AvoraRole.user:
        return 'User';
    }
  }

  bool canManageRole(AvoraRole target) {
    return authorityRank > target.authorityRank;
  }

  bool get isLaunchCoreRole {
    switch (this) {
      case AvoraRole.manager:
      case AvoraRole.bd:
      case AvoraRole.agency:
      case AvoraRole.user:
        return true;

      case AvoraRole.owner:
      case AvoraRole.superAdmin:
      case AvoraRole.admin:
        return false;
    }
  }
}

extension AvoraCapabilityPolicy on AvoraCapability {
  String get label {
    switch (this) {
      case AvoraCapability.merchant:
        return 'Merchant';
      case AvoraCapability.seller:
        return 'Seller';
      case AvoraCapability.countryManager:
        return 'Country Manager';
      case AvoraCapability.csHead:
        return 'CS Head';
      case AvoraCapability.csAgent:
        return 'CS Agent';
      case AvoraCapability.eventOrganizer:
        return 'Event Organizer';
    }
  }

  bool get isLaunchVisible {
    switch (this) {
      case AvoraCapability.seller:
        return true;

      case AvoraCapability.merchant:
      case AvoraCapability.countryManager:
      case AvoraCapability.csHead:
      case AvoraCapability.csAgent:
      case AvoraCapability.eventOrganizer:
        return false;
    }
  }
}

class AvoraRoleAssignment {
  final AvoraRole role;
  final AvoraScope scope;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const AvoraRoleAssignment({
    required this.role,
    required this.scope,
    this.startsAt,
    this.endsAt,
  });

  bool isActiveAt(DateTime time) {
    if (startsAt != null && time.isBefore(startsAt!)) {
      return false;
    }

    if (endsAt != null && !time.isBefore(endsAt!)) {
      return false;
    }

    return true;
  }
}

class AvoraCapabilityAssignment {
  final AvoraCapability capability;
  final AvoraScope scope;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const AvoraCapabilityAssignment({
    required this.capability,
    required this.scope,
    this.startsAt,
    this.endsAt,
  });

  bool isActiveAt(DateTime time) {
    if (startsAt != null && time.isBefore(startsAt!)) {
      return false;
    }

    if (endsAt != null && !time.isBefore(endsAt!)) {
      return false;
    }

    return true;
  }
}

class AvoraAccessProfile {
  final List<AvoraRoleAssignment> roles;
  final List<AvoraCapabilityAssignment> capabilities;

  const AvoraAccessProfile({
    this.roles = const [],
    this.capabilities = const [],
  });

  bool hasRole(
    AvoraRole role, {
    DateTime? at,
  }) {
    final checkTime = at ?? DateTime.now();

    return roles.any(
      (assignment) =>
          assignment.role == role && assignment.isActiveAt(checkTime),
    );
  }

  bool hasCapability(
    AvoraCapability capability, {
    DateTime? at,
  }) {
    final checkTime = at ?? DateTime.now();

    return capabilities.any(
      (assignment) =>
          assignment.capability == capability &&
          assignment.isActiveAt(checkTime),
    );
  }
}
