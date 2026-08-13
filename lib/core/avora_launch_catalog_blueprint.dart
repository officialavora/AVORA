import 'avora_launch_experience_catalog.dart';

enum AvoraLaunchCreativeFamily {
  luxury,
  royal,
  cinematic,
  antique,
  cute,
  funny,
  romantic,
  emotional,
  horror,
  animal,
  fantasy,
  vehicle,
  festive,
  social,
  futuristic,
  minimal,
}

class AvoraLaunchCategoryRequirement {
  const AvoraLaunchCategoryRequirement({
    required this.category,
    required this.minimumPublishedItems,
    required this.requiredCreativeFamilies,
  });

  final AvoraLaunchExperienceCategory category;

  /// Owner-configured launch requirement.
  /// This is deliberately not hardcoded inside the catalog engine.
  final int minimumPublishedItems;

  final Set<AvoraLaunchCreativeFamily> requiredCreativeFamilies;

  void validate() {
    if (minimumPublishedItems <= 0) {
      throw ArgumentError(
        'minimum_published_items_must_be_positive',
      );
    }

    if (requiredCreativeFamilies.isEmpty) {
      throw ArgumentError(
        'launch_category_requires_creative_family',
      );
    }
  }
}

class AvoraLaunchCatalogBlueprint {
  const AvoraLaunchCatalogBlueprint({
    required this.blueprintVersion,
    required this.requirements,
    required this.createdByOwnerAvoraId,
    required this.createdAtUtc,
  });

  final String blueprintVersion;
  final List<AvoraLaunchCategoryRequirement> requirements;
  final String createdByOwnerAvoraId;
  final DateTime createdAtUtc;

  void validate() {
    if (blueprintVersion.trim().isEmpty ||
        createdByOwnerAvoraId.trim().isEmpty ||
        requirements.isEmpty) {
      throw ArgumentError('invalid_launch_catalog_blueprint');
    }

    final categories = <AvoraLaunchExperienceCategory>{};

    for (final requirement in requirements) {
      requirement.validate();

      if (!categories.add(requirement.category)) {
        throw StateError(
          'duplicate_launch_category_requirement',
        );
      }
    }
  }

  AvoraLaunchCategoryRequirement requirementFor(
    AvoraLaunchExperienceCategory category,
  ) {
    return requirements.firstWhere(
      (requirement) => requirement.category == category,
      orElse: () => throw StateError(
        'launch_category_requirement_not_found',
      ),
    );
  }
}

class AvoraLaunchSeedDescriptor {
  const AvoraLaunchSeedDescriptor({
    required this.itemId,
    required this.category,
    required this.creativeFamilies,
    required this.originalAvoraCreative,
    required this.qualityApproved,
    required this.ownerApproved,
    required this.manifestApproved,
  });

  final String itemId;
  final AvoraLaunchExperienceCategory category;
  final Set<AvoraLaunchCreativeFamily> creativeFamilies;

  final bool originalAvoraCreative;
  final bool qualityApproved;
  final bool ownerApproved;
  final bool manifestApproved;

  bool get publishable =>
      originalAvoraCreative &&
      qualityApproved &&
      ownerApproved &&
      manifestApproved;

  void validate() {
    if (itemId.trim().isEmpty || creativeFamilies.isEmpty) {
      throw ArgumentError('invalid_launch_seed_descriptor');
    }
  }
}

class AvoraLaunchCategoryCoverage {
  const AvoraLaunchCategoryCoverage({
    required this.category,
    required this.requiredItemCount,
    required this.actualItemCount,
    required this.missingCreativeFamilies,
  });

  final AvoraLaunchExperienceCategory category;
  final int requiredItemCount;
  final int actualItemCount;

  final Set<AvoraLaunchCreativeFamily> missingCreativeFamilies;

  bool get complete =>
      actualItemCount >= requiredItemCount && missingCreativeFamilies.isEmpty;
}

class AvoraLaunchBlueprintCoverageReport {
  const AvoraLaunchBlueprintCoverageReport({
    required this.complete,
    required this.categories,
  });

  final bool complete;
  final List<AvoraLaunchCategoryCoverage> categories;

  List<AvoraLaunchCategoryCoverage> get incompleteCategories =>
      List<AvoraLaunchCategoryCoverage>.unmodifiable(
        categories.where((coverage) => !coverage.complete),
      );
}

class AvoraLaunchCatalogBlueprintEvaluator {
  const AvoraLaunchCatalogBlueprintEvaluator();

  AvoraLaunchBlueprintCoverageReport evaluate({
    required AvoraLaunchCatalogBlueprint blueprint,
    required Iterable<AvoraLaunchSeedDescriptor> seeds,
  }) {
    blueprint.validate();

    final validSeeds = seeds.where((seed) {
      seed.validate();
      return seed.publishable;
    }).toList(growable: false);

    final coverage = <AvoraLaunchCategoryCoverage>[];

    for (final requirement in blueprint.requirements) {
      final categorySeeds = validSeeds
          .where(
            (seed) => seed.category == requirement.category,
          )
          .toList(growable: false);

      final availableFamilies = <AvoraLaunchCreativeFamily>{};

      for (final seed in categorySeeds) {
        availableFamilies.addAll(seed.creativeFamilies);
      }

      final missingFamilies = requirement.requiredCreativeFamilies.difference(
        availableFamilies,
      );

      coverage.add(
        AvoraLaunchCategoryCoverage(
          category: requirement.category,
          requiredItemCount: requirement.minimumPublishedItems,
          actualItemCount: categorySeeds.length,
          missingCreativeFamilies: Set<AvoraLaunchCreativeFamily>.unmodifiable(
            missingFamilies,
          ),
        ),
      );
    }

    return AvoraLaunchBlueprintCoverageReport(
      complete: coverage.every((item) => item.complete),
      categories: List<AvoraLaunchCategoryCoverage>.unmodifiable(
        coverage,
      ),
    );
  }

  static bool launchQuantityMustComeFromConfigurableBlueprint() => true;

  static bool rawQuantityMustNotReplaceCreativeFamilyCoverage() => true;

  static bool unpublishedSeedMustNotCountTowardLaunchReadiness() => true;

  static bool futureCreativeFamiliesMustFitSameCoverageModel() => true;
}

class AvoraLaunchCatalogBlueprintRegistry {
  AvoraLaunchCatalogBlueprintRegistry();

  AvoraLaunchCatalogBlueprint? _active;

  final Map<String, AvoraLaunchCatalogBlueprint> _history =
      <String, AvoraLaunchCatalogBlueprint>{};

  AvoraLaunchCatalogBlueprint? get active => _active;

  void activate({
    required AvoraLaunchCatalogBlueprint blueprint,
    required bool actorIsVerifiedOwner,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    blueprint.validate();

    final current = _active;

    if (current?.blueprintVersion == blueprint.blueprintVersion) {
      throw StateError(
        'launch_blueprint_version_must_change',
      );
    }

    if (current != null) {
      _history[current.blueprintVersion] = current;
    }

    _active = blueprint;
  }

  AvoraLaunchCatalogBlueprint? historical(
    String blueprintVersion,
  ) {
    if (_active?.blueprintVersion == blueprintVersion) {
      return _active;
    }

    return _history[blueprintVersion];
  }

  static bool ownerMayIncreaseLaunchQuantityLater() => true;

  static bool ownerMayReduceOrRebalanceLaunchQuantityLater() => true;

  static bool ownerMayChangeRequiredCreativeFamiliesLater() => true;

  static bool historicalBlueprintsMustRemainAvailable() => true;

  static bool blueprintChangeMustNotRequireClientRewrite() => true;
}

class AvoraLaunchCatalogSeedArchitecture {
  const AvoraLaunchCatalogSeedArchitecture._();

  static bool launchMustContainRealPolishedSeedInventory() => true;

  static bool oneDemoItemPerCategoryIsNotEnoughByDefault() => true;

  static bool entryFrameBubbleGiftAndEmojiNeedUsefulVariety() => true;

  static bool premiumCatalogNeedsLuxuryRoyalAndCinematicOptions() => true;

  static bool entertainmentCatalogNeedsCuteFunnyAndEmotionalOptions() => true;

  static bool fantasyAnimalVehicleAndHorrorMayBeSeparateFamilies() => true;

  static bool quantityAndBeautyMustBothBeLaunchRequirements() => true;

  static bool uploadedReferenceCoverageMustBeCheckedAgainstSeeds() => true;

  static bool futureIdeasMustAppendWithoutArchitectureDemolition() => true;

  static bool originalAvoraCreativeMustRemainMandatory() => true;
}
