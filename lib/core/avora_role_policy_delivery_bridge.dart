enum AvoraPolicyDeliveryRole {
  owner,
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  host,
  user,
}

class AvoraRolePolicyDeliveryRule {
  const AvoraRolePolicyDeliveryRule({
    required this.role,
    required this.visiblePolicyRoles,
  });

  final AvoraPolicyDeliveryRole role;
  final Set<AvoraPolicyDeliveryRole> visiblePolicyRoles;
}

class AvoraRolePolicyDeliveryBridge {
  const AvoraRolePolicyDeliveryBridge._();

  static const Map<AvoraPolicyDeliveryRole, Set<AvoraPolicyDeliveryRole>>
      _visibility = {
    AvoraPolicyDeliveryRole.owner: {
      AvoraPolicyDeliveryRole.owner,
      AvoraPolicyDeliveryRole.manager,
      AvoraPolicyDeliveryRole.superAdmin,
      AvoraPolicyDeliveryRole.admin,
      AvoraPolicyDeliveryRole.bd,
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.manager: {
      AvoraPolicyDeliveryRole.manager,
      AvoraPolicyDeliveryRole.superAdmin,
      AvoraPolicyDeliveryRole.admin,
      AvoraPolicyDeliveryRole.bd,
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.superAdmin: {
      AvoraPolicyDeliveryRole.superAdmin,
      AvoraPolicyDeliveryRole.admin,
      AvoraPolicyDeliveryRole.bd,
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.admin: {
      AvoraPolicyDeliveryRole.admin,
      AvoraPolicyDeliveryRole.bd,
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.bd: {
      AvoraPolicyDeliveryRole.bd,
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.agency: {
      AvoraPolicyDeliveryRole.agency,
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.host: {
      AvoraPolicyDeliveryRole.host,
      AvoraPolicyDeliveryRole.user,
    },
    AvoraPolicyDeliveryRole.user: {
      AvoraPolicyDeliveryRole.user,
    },
  };

  static Set<AvoraPolicyDeliveryRole> applicablePolicyRoles(
    AvoraPolicyDeliveryRole role,
  ) {
    return Set.unmodifiable(_visibility[role] ?? const {});
  }

  static bool canViewPolicy({
    required AvoraPolicyDeliveryRole viewer,
    required AvoraPolicyDeliveryRole policyOwnerRole,
  }) {
    return applicablePolicyRoles(viewer).contains(policyOwnerRole);
  }

  static List<T> deliverApplicablePolicies<T>({
    required AvoraPolicyDeliveryRole role,
    required List<T> policies,
    required AvoraPolicyDeliveryRole Function(T policy) policyRoleOf,
  }) {
    final allowed = applicablePolicyRoles(role);

    return List<T>.unmodifiable(
      policies.where(
        (policy) => allowed.contains(policyRoleOf(policy)),
      ),
    );
  }

  static bool activationMustAutoDeliverApplicablePolicies() => true;

  static bool lowerRoleMustNotSeeHigherConfidentialPolicy() => true;

  static bool deliveryMustReuseAuthoritativePolicySource() => true;

  static bool policyVisibilityMustRemainRoleScoped() => true;
}
