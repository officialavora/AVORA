enum AvoraSeatLayoutKind {
  normal,
  equalGrid,
  cpPaired,
  royalThrone,
  birthdayEvent,
  official,
  performance,
  custom,
}

enum AvoraSeatVisualRole {
  standard,
  owner,
  host,
  cpLeft,
  cpRight,
  king,
  queen,
  official,
  performer,
  guest,
  custom,
}

class AvoraNormalizedSeatPosition {
  /// 0.0 = left, 1.0 = right.
  final double x;

  /// 0.0 = top, 1.0 = bottom.
  final double y;

  /// Relative width/height. Flutter decides actual pixels.
  final double width;
  final double height;

  const AvoraNormalizedSeatPosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  })  : assert(x >= 0 && x <= 1),
        assert(y >= 0 && y <= 1),
        assert(width > 0 && width <= 1),
        assert(height > 0 && height <= 1);
}

class AvoraSeatLayoutItem {
  final int seatNumber;

  final AvoraNormalizedSeatPosition position;

  final AvoraSeatVisualRole visualRole;

  /// CP pair / throne pair / event grouping reference.
  final String? pairGroupId;

  /// Purely presentation metadata.
  final String? seatThemeRef;
  final String? effectRef;

  final bool lockedByDefault;

  /// Does not itself grant VIP/authority.
  final bool premiumVisual;

  const AvoraSeatLayoutItem({
    required this.seatNumber,
    required this.position,
    this.visualRole = AvoraSeatVisualRole.standard,
    this.pairGroupId,
    this.seatThemeRef,
    this.effectRef,
    this.lockedByDefault = false,
    this.premiumVisual = false,
  }) : assert(seatNumber >= 1);
}

class AvoraSeatLayoutVersion {
  final String versionId;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  final int seatCount;

  final List<AvoraSeatLayoutItem> seats;

  /// Discovery/configuration tags:
  /// normal, 5-seat, birthday, cp, royal, etc.
  final Set<String> tags;

  /// Optional entitlement/policy references.
  final String? entitlementPolicyRef;
  final String? roomPolicyRef;

  const AvoraSeatLayoutVersion({
    required this.versionId,
    required this.effectiveFrom,
    required this.enabled,
    required this.seatCount,
    required this.seats,
    this.effectiveUntil,
    this.tags = const {},
    this.entitlementPolicyRef,
    this.roomPolicyRef,
  }) : assert(seatCount >= 1);

  bool activeAt(DateTime now) {
    if (!enabled || now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }
}

class AvoraSeatLayoutDefinition {
  final String layoutId;
  final String displayName;

  final AvoraSeatLayoutKind kind;

  final List<AvoraSeatLayoutVersion> versions;

  const AvoraSeatLayoutDefinition({
    required this.layoutId,
    required this.displayName,
    required this.kind,
    required this.versions,
  });
}

enum AvoraSeatLayoutIssue {
  seatCountMismatch,
  duplicateSeatNumber,
  missingSeatNumber,
  incompletePairGroup,
}

class AvoraSeatLayoutValidation {
  final bool valid;
  final Set<AvoraSeatLayoutIssue> issues;

  const AvoraSeatLayoutValidation({
    required this.valid,
    required this.issues,
  });
}

class AvoraResolvedSeatLayout {
  final String layoutId;
  final String displayName;

  final AvoraSeatLayoutKind kind;

  final String versionId;

  final int seatCount;

  final List<AvoraSeatLayoutItem> seats;

  final String? entitlementPolicyRef;
  final String? roomPolicyRef;

  const AvoraResolvedSeatLayout({
    required this.layoutId,
    required this.displayName,
    required this.kind,
    required this.versionId,
    required this.seatCount,
    required this.seats,
    required this.entitlementPolicyRef,
    required this.roomPolicyRef,
  });
}

class AvoraSeatLayoutEngine {
  const AvoraSeatLayoutEngine._();

  static AvoraSeatLayoutVersion? effectiveVersion({
    required AvoraSeatLayoutDefinition layout,
    required DateTime now,
  }) {
    final active = layout.versions
        .where((version) => version.activeAt(now))
        .toList(growable: false)
      ..sort(
        (a, b) => b.effectiveFrom.compareTo(a.effectiveFrom),
      );

    return active.isEmpty ? null : active.first;
  }

  static AvoraSeatLayoutValidation validate(
    AvoraSeatLayoutVersion version,
  ) {
    final issues = <AvoraSeatLayoutIssue>{};

    if (version.seats.length != version.seatCount) {
      issues.add(AvoraSeatLayoutIssue.seatCountMismatch);
    }

    final seatNumbers = <int>{};

    for (final seat in version.seats) {
      if (!seatNumbers.add(seat.seatNumber)) {
        issues.add(AvoraSeatLayoutIssue.duplicateSeatNumber);
      }
    }

    for (var number = 1; number <= version.seatCount; number++) {
      if (!seatNumbers.contains(number)) {
        issues.add(AvoraSeatLayoutIssue.missingSeatNumber);
      }
    }

    final pairCounts = <String, int>{};

    for (final seat in version.seats) {
      final pair = seat.pairGroupId;

      if (pair != null) {
        pairCounts[pair] = (pairCounts[pair] ?? 0) + 1;
      }
    }

    if (pairCounts.values.any((count) => count != 2)) {
      issues.add(AvoraSeatLayoutIssue.incompletePairGroup);
    }

    return AvoraSeatLayoutValidation(
      valid: issues.isEmpty,
      issues: Set.unmodifiable(issues),
    );
  }

  static AvoraResolvedSeatLayout? resolve({
    required AvoraSeatLayoutDefinition layout,
    required DateTime now,
  }) {
    final version = effectiveVersion(
      layout: layout,
      now: now,
    );

    if (version == null) {
      return null;
    }

    final validation = validate(version);

    if (!validation.valid) {
      return null;
    }

    return AvoraResolvedSeatLayout(
      layoutId: layout.layoutId,
      displayName: layout.displayName,
      kind: layout.kind,
      versionId: version.versionId,
      seatCount: version.seatCount,
      seats: List.unmodifiable(version.seats),
      entitlementPolicyRef: version.entitlementPolicyRef,
      roomPolicyRef: version.roomPolicyRef,
    );
  }

  /// Generates responsive equal grids such as:
  /// 5, 10, 25, 50 or future configurable counts.
  static List<AvoraSeatLayoutItem> generateEqualGrid({
    required int seatCount,
    required int columns,
  }) {
    if (seatCount < 1 || columns < 1) {
      throw ArgumentError(
        'seatCount and columns must be positive.',
      );
    }

    final rows = (seatCount / columns).ceil();

    final cellWidth = 1 / columns;
    final cellHeight = 1 / rows;

    final seats = <AvoraSeatLayoutItem>[];

    for (var index = 0; index < seatCount; index++) {
      final row = index ~/ columns;
      final column = index % columns;

      seats.add(
        AvoraSeatLayoutItem(
          seatNumber: index + 1,
          position: AvoraNormalizedSeatPosition(
            x: column * cellWidth,
            y: row * cellHeight,
            width: cellWidth,
            height: cellHeight,
          ),
        ),
      );
    }

    return List.unmodifiable(seats);
  }

  /// CP/royal pairs use metadata, not hardcoded seat numbers.
  static bool pairLayoutMustAlwaysUseSeatsOneAndTwo() {
    return false;
  }

  /// 5/10/25/50 are presets, not permanent structural limits.
  static bool seatCountsAreHardcodedForever() {
    return false;
  }

  /// Layout visual role never grants actual moderation authority.
  static bool visualSeatRoleGrantsAuthority() {
    return false;
  }

  /// Seat UI coordinates never become backend identity.
  static bool visualSeatPositionIsAuthoritativeIdentity() {
    return false;
  }

  /// Owner absence does not destroy the room or layout.
  static bool ownerMustBePresentForLayoutToRemainActive() {
    return false;
  }

  /// New custom/event layouts can be added through configuration.
  static bool everyNewLayoutRequiresCoreEngineChange() {
    return false;
  }
}
