// Owner-only global organisation hierarchy projection.
//
// Read/projection layer only.
// Existing role, permission, family, agency and audit engines
// remain authoritative.

enum AvoraOwnerHierarchyRole {
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  host,
  user,
}

enum AvoraOwnerHierarchyDepth {
  direct,
  indirect,
  all,
}

class AvoraOwnerHierarchyMember {
  const AvoraOwnerHierarchyMember({
    required this.avoraId,
    required this.role,
    required this.countryCode,
    this.parentAvoraId,
    this.displayName,
    this.active = true,
  });

  final String avoraId;
  final AvoraOwnerHierarchyRole role;
  final String countryCode;
  final String? parentAvoraId;
  final String? displayName;
  final bool active;
}

class AvoraOwnerHierarchyQuery {
  const AvoraOwnerHierarchyQuery({
    this.role,
    this.countryCode,
    this.depth = AvoraOwnerHierarchyDepth.all,
    this.rootAvoraId,
    this.includeInactive = false,
    this.selectedAvoraIds = const <String>{},
  });

  final AvoraOwnerHierarchyRole? role;
  final String? countryCode;
  final AvoraOwnerHierarchyDepth depth;
  final String? rootAvoraId;
  final bool includeInactive;
  final Set<String> selectedAvoraIds;
}

class AvoraOwnerHierarchySummary {
  const AvoraOwnerHierarchySummary({
    required this.total,
    required this.direct,
    required this.indirect,
    required this.byRole,
    required this.byCountry,
  });

  final int total;
  final int direct;
  final int indirect;
  final Map<AvoraOwnerHierarchyRole, int> byRole;
  final Map<String, int> byCountry;
}

class AvoraOwnerGlobalHierarchy {
  const AvoraOwnerGlobalHierarchy._();

  static List<AvoraOwnerHierarchyMember> resolve({
    required List<AvoraOwnerHierarchyMember> members,
    required AvoraOwnerHierarchyQuery query,
  }) {
    final byParent = <String?, List<AvoraOwnerHierarchyMember>>{};

    for (final member in members) {
      final parent = _normalize(member.parentAvoraId);
      byParent
          .putIfAbsent(parent, () => <AvoraOwnerHierarchyMember>[])
          .add(member);
    }

    final root = _normalize(query.rootAvoraId);
    final direct = List<AvoraOwnerHierarchyMember>.from(
      byParent[root] ?? const <AvoraOwnerHierarchyMember>[],
    );

    final indirect = <AvoraOwnerHierarchyMember>[];
    final queue = <AvoraOwnerHierarchyMember>[...direct];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);

      if (!visited.add(parent.avoraId)) {
        continue;
      }

      final children =
          byParent[parent.avoraId] ?? const <AvoraOwnerHierarchyMember>[];

      for (final child in children) {
        indirect.add(child);
        queue.add(child);
      }
    }

    Iterable<AvoraOwnerHierarchyMember> candidates;

    switch (query.depth) {
      case AvoraOwnerHierarchyDepth.direct:
        candidates = direct;
        break;
      case AvoraOwnerHierarchyDepth.indirect:
        candidates = indirect;
        break;
      case AvoraOwnerHierarchyDepth.all:
        candidates = <AvoraOwnerHierarchyMember>[
          ...direct,
          ...indirect,
        ];
        break;
    }

    final country = query.countryCode?.trim().toUpperCase();

    final unique = <String, AvoraOwnerHierarchyMember>{};

    for (final member in candidates) {
      if (!query.includeInactive && !member.active) {
        continue;
      }

      if (query.role != null && member.role != query.role) {
        continue;
      }

      if (country != null &&
          country.isNotEmpty &&
          member.countryCode.trim().toUpperCase() != country) {
        continue;
      }

      if (query.selectedAvoraIds.isNotEmpty &&
          !query.selectedAvoraIds.contains(member.avoraId)) {
        continue;
      }

      unique[member.avoraId] = member;
    }

    return List<AvoraOwnerHierarchyMember>.unmodifiable(unique.values);
  }

  static Set<String> resolveBulkTargetIds({
    required List<AvoraOwnerHierarchyMember> members,
    required AvoraOwnerHierarchyQuery query,
  }) {
    return resolve(
      members: members,
      query: query,
    ).map((member) => member.avoraId).toSet();
  }

  static String? _normalize(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static AvoraOwnerHierarchySummary summarize({
    required List<AvoraOwnerHierarchyMember> members,
    String? rootAvoraId,
  }) {
    final direct = resolve(
      members: members,
      query: AvoraOwnerHierarchyQuery(
        rootAvoraId: rootAvoraId,
        depth: AvoraOwnerHierarchyDepth.direct,
      ),
    );

    final indirect = resolve(
      members: members,
      query: AvoraOwnerHierarchyQuery(
        rootAvoraId: rootAvoraId,
        depth: AvoraOwnerHierarchyDepth.indirect,
      ),
    );

    final all = <String, AvoraOwnerHierarchyMember>{};

    for (final member in <AvoraOwnerHierarchyMember>[
      ...direct,
      ...indirect,
    ]) {
      all[member.avoraId] = member;
    }

    final byRole = <AvoraOwnerHierarchyRole, int>{};
    final byCountry = <String, int>{};

    for (final member in all.values) {
      byRole.update(
        member.role,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final country = member.countryCode.trim().toUpperCase();

      byCountry.update(
        country,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return AvoraOwnerHierarchySummary(
      total: all.length,
      direct: direct.length,
      indirect: indirect.length,
      byRole: Map.unmodifiable(byRole),
      byCountry: Map.unmodifiable(byCountry),
    );
  }

  static bool ownerPanelAndOwnerIdentityUseSameHierarchySource() => true;

  static bool hierarchyProjectionNeverGrantsAuthority() => true;

  static bool bulkActionsMustRemainAudited() => true;
}
