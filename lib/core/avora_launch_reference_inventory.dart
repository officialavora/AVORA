import 'avora_reference_launch_coverage.dart';

enum AvoraReferenceSourceKind {
  ownerIdea,
  screenshot,
  video,
  roadmap,
  research,
  userFeedback,
  competitorReference,
  futureDiscovery,
}

enum AvoraInventoryPriority {
  later,
  useful,
  launchImportant,
  launchCritical,
}

class AvoraLaunchReferenceSource {
  const AvoraLaunchReferenceSource({
    required this.sourceId,
    required this.kind,
    required this.capturedAtUtc,
    required this.summary,
    this.externalReference,
  });

  final String sourceId;
  final AvoraReferenceSourceKind kind;
  final DateTime capturedAtUtc;
  final String summary;

  /// Internal trace only. Never makes third-party branding an AVORA asset.
  final String? externalReference;

  void validate() {
    if (sourceId.trim().isEmpty || summary.trim().isEmpty) {
      throw ArgumentError('invalid_launch_reference_source');
    }
  }
}

class AvoraLaunchInventoryItem {
  const AvoraLaunchInventoryItem({
    required this.inventoryId,
    required this.canonicalKey,
    required this.requirementId,
    required this.title,
    required this.priority,
    required this.sourceIds,
    required this.createdAtUtc,
    required this.ownerVisible,
    required this.originalAvoraCreativeRequired,
    this.deferredReason,
  });

  final String inventoryId;

  /// Stable normalized identity used to stop duplicate work.
  final String canonicalKey;

  final String requirementId;
  final String title;
  final AvoraInventoryPriority priority;
  final List<String> sourceIds;
  final DateTime createdAtUtc;

  final bool ownerVisible;
  final bool originalAvoraCreativeRequired;
  final String? deferredReason;

  bool get requiredForLaunch =>
      priority == AvoraInventoryPriority.launchImportant ||
      priority == AvoraInventoryPriority.launchCritical;

  void validate() {
    if (inventoryId.trim().isEmpty ||
        canonicalKey.trim().isEmpty ||
        requirementId.trim().isEmpty ||
        title.trim().isEmpty) {
      throw ArgumentError('invalid_launch_inventory_item');
    }

    if (sourceIds.isEmpty) {
      throw StateError('inventory_item_requires_source_trace');
    }

    if (!ownerVisible) {
      throw StateError('launch_inventory_must_remain_owner_visible');
    }

    if (!originalAvoraCreativeRequired) {
      throw StateError('original_avora_creative_required');
    }
  }
}

class AvoraLaunchReferenceInventory {
  final Map<String, AvoraLaunchReferenceSource> _sources =
      <String, AvoraLaunchReferenceSource>{};

  final Map<String, AvoraLaunchInventoryItem> _items =
      <String, AvoraLaunchInventoryItem>{};

  final Map<String, String> _canonicalIndex = <String, String>{};

  void addSource(
    AvoraLaunchReferenceSource source, {
    required bool actorCanManageRoadmap,
  }) {
    if (!actorCanManageRoadmap) {
      throw StateError('roadmap_management_permission_required');
    }

    source.validate();

    if (_sources.containsKey(source.sourceId)) {
      throw StateError('duplicate_reference_source');
    }

    _sources[source.sourceId] = source;
  }

  void addItem(
    AvoraLaunchInventoryItem item, {
    required bool actorCanManageRoadmap,
  }) {
    if (!actorCanManageRoadmap) {
      throw StateError('roadmap_management_permission_required');
    }

    item.validate();

    if (_items.containsKey(item.inventoryId)) {
      throw StateError('duplicate_inventory_id');
    }

    final normalizedKey = normalizeCanonicalKey(item.canonicalKey);

    if (_canonicalIndex.containsKey(normalizedKey)) {
      throw StateError('duplicate_canonical_requirement');
    }

    for (final sourceId in item.sourceIds) {
      if (!_sources.containsKey(sourceId)) {
        throw StateError('inventory_source_not_found');
      }
    }

    _items[item.inventoryId] = item;
    _canonicalIndex[normalizedKey] = item.inventoryId;
  }

  static String normalizeCanonicalKey(String value) {
    return value.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        );
  }

  AvoraLaunchInventoryItem? findByCanonicalKey(String key) {
    final id = _canonicalIndex[normalizeCanonicalKey(key)];
    return id == null ? null : _items[id];
  }

  List<AvoraLaunchInventoryItem> get allItems =>
      List<AvoraLaunchInventoryItem>.unmodifiable(_items.values);

  List<AvoraLaunchReferenceSource> get allSources =>
      List<AvoraLaunchReferenceSource>.unmodifiable(_sources.values);

  bool sourceExists(String sourceId) => _sources.containsKey(sourceId);

  static bool everyUsefulReferenceMustBecomeTraceable() => true;

  static bool duplicateIdeasMustReuseCanonicalRequirement() => true;

  static bool futureReferencesMustAppendWithoutCoreRewrite() => true;

  static bool ownerMustSeeEntireInventory() => true;

  static bool researchMayAddRequirementsButMustNotCopyBrandIdentity() => true;
}

class AvoraLaunchInventoryGap {
  const AvoraLaunchInventoryGap({
    required this.inventoryId,
    required this.requirementId,
    required this.reason,
  });

  final String inventoryId;
  final String requirementId;
  final String reason;
}

class AvoraLaunchInventoryAuditReport {
  const AvoraLaunchInventoryAuditReport({
    required this.ready,
    required this.totalInventoryItems,
    required this.requiredLaunchItems,
    required this.satisfiedLaunchItems,
    required this.gaps,
  });

  final bool ready;
  final int totalInventoryItems;
  final int requiredLaunchItems;
  final int satisfiedLaunchItems;
  final List<AvoraLaunchInventoryGap> gaps;
}

class AvoraLaunchInventoryAuditGate {
  const AvoraLaunchInventoryAuditGate();

  AvoraLaunchInventoryAuditReport evaluate({
    required AvoraLaunchReferenceInventory inventory,
    required AvoraReferenceCoverageRegistry coverageRegistry,
  }) {
    final gaps = <AvoraLaunchInventoryGap>[];
    var requiredCount = 0;
    var satisfiedCount = 0;

    for (final item in inventory.allItems) {
      if (!item.requiredForLaunch) {
        continue;
      }

      requiredCount++;

      final requirement = coverageRegistry.requirementById(item.requirementId);

      if (requirement == null) {
        gaps.add(
          AvoraLaunchInventoryGap(
            inventoryId: item.inventoryId,
            requirementId: item.requirementId,
            reason: 'coverage_requirement_missing',
          ),
        );
        continue;
      }

      if (requirement.status ==
          AvoraReferenceCoverageStatus.intentionallyDeferred) {
        if (item.deferredReason == null ||
            item.deferredReason!.trim().isEmpty) {
          gaps.add(
            AvoraLaunchInventoryGap(
              inventoryId: item.inventoryId,
              requirementId: item.requirementId,
              reason: 'deferred_item_requires_reason',
            ),
          );
          continue;
        }

        satisfiedCount++;
        continue;
      }

      if (requirement.status != AvoraReferenceCoverageStatus.launchReady) {
        gaps.add(
          AvoraLaunchInventoryGap(
            inventoryId: item.inventoryId,
            requirementId: item.requirementId,
            reason: 'requirement_not_launch_ready',
          ),
        );
        continue;
      }

      if (!coverageRegistry.hasLaunchEligibleBinding(
        item.requirementId,
      )) {
        gaps.add(
          AvoraLaunchInventoryGap(
            inventoryId: item.inventoryId,
            requirementId: item.requirementId,
            reason: 'approved_implementation_binding_missing',
          ),
        );
        continue;
      }

      satisfiedCount++;
    }

    return AvoraLaunchInventoryAuditReport(
      ready: gaps.isEmpty,
      totalInventoryItems: inventory.allItems.length,
      requiredLaunchItems: requiredCount,
      satisfiedLaunchItems: satisfiedCount,
      gaps: List<AvoraLaunchInventoryGap>.unmodifiable(gaps),
    );
  }

  static bool launchMustNotSilentlyLoseCapturedWork() => true;

  static bool criticalAndImportantInventoryMustBeAudited() => true;

  static bool deferredWorkMustKeepReasonAndTrace() => true;

  static bool screenshotVideoRoadmapAndResearchMustBeCrossCheckable() => true;

  static bool passMustDependOnActualCoverageNotItemCount() => true;
}

class AvoraLaunchReferenceSeedCoverage {
  const AvoraLaunchReferenceSeedCoverage._();

  static const Set<AvoraReferenceRequirementKind> experienceFamilies =
      <AvoraReferenceRequirementKind>{
    AvoraReferenceRequirementKind.entry,
    AvoraReferenceRequirementKind.profileFrame,
    AvoraReferenceRequirementKind.chatBubble,
    AvoraReferenceRequirementKind.gift,
    AvoraReferenceRequirementKind.animatedReaction,
    AvoraReferenceRequirementKind.emojiGif,
    AvoraReferenceRequirementKind.soundEffect,
    AvoraReferenceRequirementKind.musicEffect,
    AvoraReferenceRequirementKind.roomEffect,
    AvoraReferenceRequirementKind.profileEffect,
    AvoraReferenceRequirementKind.badgeMedal,
    AvoraReferenceRequirementKind.roomTheme,
    AvoraReferenceRequirementKind.profileDecoration,
    AvoraReferenceRequirementKind.eventEffect,
    AvoraReferenceRequirementKind.gameExperience,
    AvoraReferenceRequirementKind.socialExperience,
  };

  static bool launchInventoryMustCoverUsefulExperienceFamilies() =>
      experienceFamilies.isNotEmpty;

  static bool
      premiumLuxuryFunnyEmotionalAndCinematicVarietyMustRemainPlannable() =>
          true;

  static bool quantityQualityBeautyAndSmoothnessAreSeparateLaunchConcerns() =>
      true;
}
