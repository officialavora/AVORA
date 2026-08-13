import 'avora_launch_experience_catalog.dart';

enum AvoraReferenceRequirementKind {
  entry,
  profileFrame,
  chatBubble,
  gift,
  animatedReaction,
  emojiGif,
  soundEffect,
  musicEffect,
  roomEffect,
  profileEffect,
  badgeMedal,
  roomTheme,
  profileDecoration,
  eventEffect,
  gameExperience,
  socialExperience,
  other,
}

enum AvoraReferenceImportance {
  optional,
  useful,
  launchImportant,
  launchCritical,
}

enum AvoraReferenceCoverageStatus {
  captured,
  planned,
  implemented,
  launchReady,
  intentionallyDeferred,
}

class AvoraReferenceRequirement {
  const AvoraReferenceRequirement({
    required this.requirementId,
    required this.kind,
    required this.title,
    required this.description,
    required this.importance,
    required this.status,
    required this.originalAvoraImplementationRequired,
    required this.ownerApproved,
    required this.createdAtUtc,
    this.catalogCategory,
    this.referenceKey,
    this.notes,
  });

  final String requirementId;
  final AvoraReferenceRequirementKind kind;
  final String title;
  final String description;
  final AvoraReferenceImportance importance;
  final AvoraReferenceCoverageStatus status;

  /// Internal reference key only.
  /// Do not use competitor branding as an AVORA public asset identity.
  final String? referenceKey;

  final AvoraLaunchExperienceCategory? catalogCategory;

  final bool originalAvoraImplementationRequired;
  final bool ownerApproved;

  final DateTime createdAtUtc;
  final String? notes;

  bool get requiredForLaunch =>
      importance == AvoraReferenceImportance.launchImportant ||
      importance == AvoraReferenceImportance.launchCritical;

  bool get satisfiedForLaunch =>
      status == AvoraReferenceCoverageStatus.launchReady ||
      status == AvoraReferenceCoverageStatus.intentionallyDeferred;

  void validate() {
    if (requirementId.trim().isEmpty ||
        title.trim().isEmpty ||
        description.trim().isEmpty) {
      throw ArgumentError('invalid_reference_requirement');
    }

    if (!originalAvoraImplementationRequired) {
      throw StateError(
        'reference_requirement_must_produce_original_avora_implementation',
      );
    }
  }
}

class AvoraReferenceCoverageBinding {
  const AvoraReferenceCoverageBinding({
    required this.bindingId,
    required this.requirementId,
    required this.avoraImplementationId,
    required this.implementationVersion,
    required this.ownerApproved,
    required this.qualityApproved,
    required this.createdAtUtc,
  });

  final String bindingId;
  final String requirementId;

  /// AVORA-owned implementation identity.
  final String avoraImplementationId;
  final String implementationVersion;

  final bool ownerApproved;
  final bool qualityApproved;
  final DateTime createdAtUtc;

  bool get launchEligible =>
      ownerApproved &&
      qualityApproved &&
      avoraImplementationId.trim().isNotEmpty &&
      implementationVersion.trim().isNotEmpty;

  void validate() {
    if (bindingId.trim().isEmpty ||
        requirementId.trim().isEmpty ||
        avoraImplementationId.trim().isEmpty ||
        implementationVersion.trim().isEmpty) {
      throw ArgumentError('invalid_reference_coverage_binding');
    }
  }
}

class AvoraReferenceCoverageRegistry {
  final Map<String, AvoraReferenceRequirement> _requirements =
      <String, AvoraReferenceRequirement>{};

  final Map<String, List<AvoraReferenceCoverageBinding>> _bindings =
      <String, List<AvoraReferenceCoverageBinding>>{};

  void capture(
    AvoraReferenceRequirement requirement, {
    required bool actorCanManageRoadmap,
  }) {
    if (!actorCanManageRoadmap) {
      throw StateError('roadmap_management_permission_required');
    }

    requirement.validate();

    if (_requirements.containsKey(requirement.requirementId)) {
      throw StateError('duplicate_reference_requirement');
    }

    _requirements[requirement.requirementId] = requirement;
  }

  void bind({
    required AvoraReferenceCoverageBinding binding,
    required bool actorCanManageRoadmap,
  }) {
    if (!actorCanManageRoadmap) {
      throw StateError('roadmap_management_permission_required');
    }

    binding.validate();

    if (!_requirements.containsKey(binding.requirementId)) {
      throw StateError('reference_requirement_not_found');
    }

    final existing = _bindings.putIfAbsent(
      binding.requirementId,
      () => <AvoraReferenceCoverageBinding>[],
    );

    if (existing.any(
      (item) => item.bindingId == binding.bindingId,
    )) {
      throw StateError('duplicate_reference_coverage_binding');
    }

    existing.add(binding);
  }

  AvoraReferenceRequirement? requirementById(String requirementId) =>
      _requirements[requirementId];

  List<AvoraReferenceRequirement> get allRequirements =>
      List<AvoraReferenceRequirement>.unmodifiable(
        _requirements.values,
      );

  List<AvoraReferenceCoverageBinding> bindingsFor(
    String requirementId,
  ) =>
      List<AvoraReferenceCoverageBinding>.unmodifiable(
        _bindings[requirementId] ?? const <AvoraReferenceCoverageBinding>[],
      );

  bool hasLaunchEligibleBinding(String requirementId) =>
      bindingsFor(requirementId).any(
        (binding) => binding.launchEligible,
      );

  static bool screenshotVideoAndIdeaMayUseSameRequirementRegistry() => true;

  static bool repeatedReferenceMustNotCreateDuplicateWork() => true;

  static bool referenceMustBecomeRequirementNotDesignCopy() => true;

  static bool avoraImplementationMustRemainIndependentlyEditable() => true;
}

class AvoraReferenceLaunchGap {
  const AvoraReferenceLaunchGap({
    required this.requirementId,
    required this.title,
    required this.reason,
  });

  final String requirementId;
  final String title;
  final String reason;
}

class AvoraReferenceLaunchCoverageReport {
  const AvoraReferenceLaunchCoverageReport({
    required this.ready,
    required this.requiredCount,
    required this.readyCount,
    required this.gaps,
  });

  final bool ready;
  final int requiredCount;
  final int readyCount;
  final List<AvoraReferenceLaunchGap> gaps;
}

class AvoraReferenceLaunchGate {
  const AvoraReferenceLaunchGate();

  AvoraReferenceLaunchCoverageReport evaluate(
    AvoraReferenceCoverageRegistry registry,
  ) {
    final required = registry.allRequirements
        .where((requirement) => requirement.requiredForLaunch)
        .toList(growable: false);

    final gaps = <AvoraReferenceLaunchGap>[];
    var readyCount = 0;

    for (final requirement in required) {
      if (requirement.status ==
          AvoraReferenceCoverageStatus.intentionallyDeferred) {
        readyCount++;
        continue;
      }

      if (requirement.status != AvoraReferenceCoverageStatus.launchReady) {
        gaps.add(
          AvoraReferenceLaunchGap(
            requirementId: requirement.requirementId,
            title: requirement.title,
            reason: 'requirement_not_launch_ready',
          ),
        );
        continue;
      }

      if (!registry.hasLaunchEligibleBinding(
        requirement.requirementId,
      )) {
        gaps.add(
          AvoraReferenceLaunchGap(
            requirementId: requirement.requirementId,
            title: requirement.title,
            reason: 'missing_approved_avora_implementation_binding',
          ),
        );
        continue;
      }

      readyCount++;
    }

    return AvoraReferenceLaunchCoverageReport(
      ready: gaps.isEmpty,
      requiredCount: required.length,
      readyCount: readyCount,
      gaps: List<AvoraReferenceLaunchGap>.unmodifiable(gaps),
    );
  }

  static bool launchMustCrossCheckCapturedReferences() => true;

  static bool launchCriticalGapMustBlockReadiness() => true;

  static bool launchImportantGapMustBlockReadiness() => true;

  static bool intentionalDeferralMustRemainExplicit() => true;

  static bool screenshotsVideosAndRoadmapMustConvergeIntoOneGate() => true;
}

class AvoraReferenceOriginalityPolicy {
  const AvoraReferenceOriginalityPolicy._();

  static bool competitorApplicationNameMustNotBecomeAvoraAssetName() => true;

  static bool competitorLogoMustNotBeCopied() => true;

  static bool exactCompetitorVisualDesignMustNotBeCopied() => true;

  static bool usefulInteractionPatternMayInspireOriginalImplementation() =>
      true;

  static bool avoraNeedsOwnBrandLanguageAndCreativeIdentity() => true;

  static bool referenceIsForCapabilityDiscoveryNotCloning() => true;
}

class AvoraReferenceCoverageArchitecture {
  const AvoraReferenceCoverageArchitecture._();

  static bool entryReferencesMustBeTrackable() => true;

  static bool frameReferencesMustBeTrackable() => true;

  static bool bubbleReferencesMustBeTrackable() => true;

  static bool giftReferencesMustBeTrackable() => true;

  static bool emojiGifReactionReferencesMustBeTrackable() => true;

  static bool soundMusicReferencesMustBeTrackable() => true;

  static bool roomAndProfileEffectReferencesMustBeTrackable() => true;

  static bool badgeThemeDecorationReferencesMustBeTrackable() => true;

  static bool gameAndSocialExperienceReferencesMustBeTrackable() => true;

  static bool futureUnknownReferenceTypesMustFitWithoutCoreDemolition() => true;
}
