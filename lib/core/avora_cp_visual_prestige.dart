import 'avora_relationship.dart';

enum AvoraCpHeartStyle {
  basic,
  filled,
  glow,
  animated,
  royal,
}

enum AvoraCpVisualUnlock {
  pairedProfile,
  heartEffect,
  pairedFrame,
  pairedSeatLink,
  pairedRoomEntry,
  pairedBanner,
  bestCoupleFly,
}

class AvoraCpVisualStageDefinition {
  final String id;

  /// Relationship requirements.
  final int minimumLevel;
  final int minimumEligiblePoints;

  /// 0 = normal/far presentation.
  /// 10000 = maximum configured visual closeness.
  final int closenessBps;

  final AvoraCpHeartStyle heartStyle;

  final Set<AvoraCpVisualUnlock> unlocks;

  /// Asset references remain configurable.
  final String? pairedFrameAssetId;
  final String? seatLinkAssetId;
  final String? roomEntryAssetId;
  final String? bestCoupleAssetId;

  const AvoraCpVisualStageDefinition({
    required this.id,
    required this.minimumLevel,
    required this.minimumEligiblePoints,
    required this.closenessBps,
    required this.heartStyle,
    required this.unlocks,
    this.pairedFrameAssetId,
    this.seatLinkAssetId,
    this.roomEntryAssetId,
    this.bestCoupleAssetId,
  })  : assert(minimumLevel >= 0),
        assert(minimumEligiblePoints >= 0),
        assert(closenessBps >= 0 && closenessBps <= 10000);

  bool qualifies({
    required int relationshipLevel,
    required int eligiblePoints,
  }) {
    return relationshipLevel >= minimumLevel &&
        eligiblePoints >= minimumEligiblePoints;
  }

  bool hasUnlock(AvoraCpVisualUnlock unlock) {
    return unlocks.contains(unlock);
  }
}

class AvoraCpVisualState {
  final bool activeCp;

  final String? stageId;

  final int relationshipLevel;
  final int eligiblePoints;

  final int closenessBps;

  final AvoraCpHeartStyle heartStyle;

  final Set<AvoraCpVisualUnlock> unlocks;

  final String? pairedFrameAssetId;
  final String? seatLinkAssetId;
  final String? roomEntryAssetId;
  final String? bestCoupleAssetId;

  const AvoraCpVisualState({
    required this.activeCp,
    required this.stageId,
    required this.relationshipLevel,
    required this.eligiblePoints,
    required this.closenessBps,
    required this.heartStyle,
    required this.unlocks,
    this.pairedFrameAssetId,
    this.seatLinkAssetId,
    this.roomEntryAssetId,
    this.bestCoupleAssetId,
  });

  bool hasUnlock(AvoraCpVisualUnlock unlock) {
    return unlocks.contains(unlock);
  }

  double get closenessRatio => closenessBps / 10000;
}

class AvoraCpRoomEffectDecision {
  final bool showPairedSeatLink;
  final bool showPairedEntry;
  final bool showBestCoupleFly;

  final bool animationEnabled;
  final bool soundEnabled;

  const AvoraCpRoomEffectDecision({
    required this.showPairedSeatLink,
    required this.showPairedEntry,
    required this.showBestCoupleFly,
    required this.animationEnabled,
    required this.soundEnabled,
  });
}

class AvoraCpVisualPrestigeEngine {
  const AvoraCpVisualPrestigeEngine._();

  static AvoraCpVisualState resolve({
    required AvoraRelationshipRecord relationship,
    required int relationshipLevel,
    required int eligiblePoints,
    required List<AvoraCpVisualStageDefinition> stages,
  }) {
    final activeCp =
        relationship.type == AvoraRelationshipType.cp && relationship.isActive;

    if (!activeCp) {
      return AvoraCpVisualState(
        activeCp: false,
        stageId: null,
        relationshipLevel: relationshipLevel,
        eligiblePoints: eligiblePoints,
        closenessBps: 0,
        heartStyle: AvoraCpHeartStyle.basic,
        unlocks: const {},
      );
    }

    final sorted = [...stages]..sort((a, b) {
        final levelCompare = a.minimumLevel.compareTo(b.minimumLevel);

        if (levelCompare != 0) {
          return levelCompare;
        }

        return a.minimumEligiblePoints.compareTo(
          b.minimumEligiblePoints,
        );
      });

    AvoraCpVisualStageDefinition? selected;

    for (final stage in sorted) {
      if (stage.qualifies(
        relationshipLevel: relationshipLevel,
        eligiblePoints: eligiblePoints,
      )) {
        selected = stage;
      }
    }

    if (selected == null) {
      return AvoraCpVisualState(
        activeCp: true,
        stageId: null,
        relationshipLevel: relationshipLevel,
        eligiblePoints: eligiblePoints,
        closenessBps: 0,
        heartStyle: AvoraCpHeartStyle.basic,
        unlocks: const {
          AvoraCpVisualUnlock.pairedProfile,
        },
      );
    }

    return AvoraCpVisualState(
      activeCp: true,
      stageId: selected.id,
      relationshipLevel: relationshipLevel,
      eligiblePoints: eligiblePoints,
      closenessBps: selected.closenessBps,
      heartStyle: selected.heartStyle,
      unlocks: Set.unmodifiable(selected.unlocks),
      pairedFrameAssetId: selected.pairedFrameAssetId,
      seatLinkAssetId: selected.seatLinkAssetId,
      roomEntryAssetId: selected.roomEntryAssetId,
      bestCoupleAssetId: selected.bestCoupleAssetId,
    );
  }

  static AvoraCpRoomEffectDecision roomEffects({
    required AvoraCpVisualState state,

    /// Both CP members are currently present.
    required bool bothMembersInRoom,

    /// Both members occupy an eligible paired-seat layout.
    required bool bothMembersOnPairedSeats,

    /// Per-user Room Experience preferences.
    required bool animationsAllowed,
    required bool soundsAllowed,
  }) {
    if (!state.activeCp || !bothMembersInRoom) {
      return const AvoraCpRoomEffectDecision(
        showPairedSeatLink: false,
        showPairedEntry: false,
        showBestCoupleFly: false,
        animationEnabled: false,
        soundEnabled: false,
      );
    }

    final seatLink = bothMembersOnPairedSeats &&
        state.hasUnlock(
          AvoraCpVisualUnlock.pairedSeatLink,
        );

    final pairedEntry = state.hasUnlock(
      AvoraCpVisualUnlock.pairedRoomEntry,
    );

    final bestCouple = bothMembersOnPairedSeats &&
        state.hasUnlock(
          AvoraCpVisualUnlock.bestCoupleFly,
        );

    return AvoraCpRoomEffectDecision(
      showPairedSeatLink: seatLink,
      showPairedEntry: pairedEntry,
      showBestCoupleFly: bestCouple,
      animationEnabled: animationsAllowed,
      soundEnabled: soundsAllowed,
    );
  }

  static bool canShowPairedProfile({
    required AvoraCpVisualState state,
    required bool relationshipVisibleByPrivacy,
  }) {
    return state.activeCp &&
        relationshipVisibleByPrivacy &&
        state.hasUnlock(
          AvoraCpVisualUnlock.pairedProfile,
        );
  }
}
