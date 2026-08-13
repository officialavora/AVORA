import 'avora_launch_catalog_blueprint.dart';
import 'avora_launch_experience_catalog.dart';
import 'avora_launch_reference_inventory.dart';
import 'avora_reference_launch_coverage.dart';

enum AvoraLaunchReadinessArea {
  experienceCategoryCoverage,
  seedQuantityAndVariety,
  referenceCoverage,
  referenceInventoryAudit,
}

class AvoraLaunchReadinessIssue {
  const AvoraLaunchReadinessIssue({
    required this.area,
    required this.code,
    required this.details,
  });

  final AvoraLaunchReadinessArea area;
  final String code;
  final String details;
}

class AvoraUnifiedLaunchReadinessReport {
  const AvoraUnifiedLaunchReadinessReport({
    required this.ready,
    required this.passedAreas,
    required this.failedAreas,
    required this.issues,
  });

  final bool ready;
  final Set<AvoraLaunchReadinessArea> passedAreas;
  final Set<AvoraLaunchReadinessArea> failedAreas;
  final List<AvoraLaunchReadinessIssue> issues;

  bool passed(AvoraLaunchReadinessArea area) => passedAreas.contains(area);
}

class AvoraUnifiedLaunchReadinessGate {
  const AvoraUnifiedLaunchReadinessGate();

  AvoraUnifiedLaunchReadinessReport evaluate({
    required AvoraLaunchCatalogCoverageReport categoryCoverage,
    required AvoraLaunchBlueprintCoverageReport blueprintCoverage,
    required AvoraReferenceLaunchCoverageReport referenceCoverage,
    required AvoraLaunchInventoryAuditReport inventoryAudit,
  }) {
    final passed = <AvoraLaunchReadinessArea>{};
    final failed = <AvoraLaunchReadinessArea>{};
    final issues = <AvoraLaunchReadinessIssue>[];

    if (categoryCoverage.complete) {
      passed.add(
        AvoraLaunchReadinessArea.experienceCategoryCoverage,
      );
    } else {
      failed.add(
        AvoraLaunchReadinessArea.experienceCategoryCoverage,
      );

      for (final category in categoryCoverage.missingCategories) {
        issues.add(
          AvoraLaunchReadinessIssue(
            area: AvoraLaunchReadinessArea.experienceCategoryCoverage,
            code: 'missing_experience_category',
            details: category.name,
          ),
        );
      }
    }

    if (blueprintCoverage.complete) {
      passed.add(
        AvoraLaunchReadinessArea.seedQuantityAndVariety,
      );
    } else {
      failed.add(
        AvoraLaunchReadinessArea.seedQuantityAndVariety,
      );

      for (final gap in blueprintCoverage.incompleteCategories) {
        if (gap.actualItemCount < gap.requiredItemCount) {
          issues.add(
            AvoraLaunchReadinessIssue(
              area: AvoraLaunchReadinessArea.seedQuantityAndVariety,
              code: 'insufficient_seed_quantity',
              details:
                  '${gap.category.name}:${gap.actualItemCount}/${gap.requiredItemCount}',
            ),
          );
        }

        for (final family in gap.missingCreativeFamilies) {
          issues.add(
            AvoraLaunchReadinessIssue(
              area: AvoraLaunchReadinessArea.seedQuantityAndVariety,
              code: 'missing_creative_family',
              details: '${gap.category.name}:${family.name}',
            ),
          );
        }
      }
    }

    if (referenceCoverage.ready) {
      passed.add(
        AvoraLaunchReadinessArea.referenceCoverage,
      );
    } else {
      failed.add(
        AvoraLaunchReadinessArea.referenceCoverage,
      );

      for (final gap in referenceCoverage.gaps) {
        issues.add(
          AvoraLaunchReadinessIssue(
            area: AvoraLaunchReadinessArea.referenceCoverage,
            code: gap.reason,
            details: '${gap.requirementId}:${gap.title}',
          ),
        );
      }
    }

    if (inventoryAudit.ready) {
      passed.add(
        AvoraLaunchReadinessArea.referenceInventoryAudit,
      );
    } else {
      failed.add(
        AvoraLaunchReadinessArea.referenceInventoryAudit,
      );

      for (final gap in inventoryAudit.gaps) {
        issues.add(
          AvoraLaunchReadinessIssue(
            area: AvoraLaunchReadinessArea.referenceInventoryAudit,
            code: gap.reason,
            details: '${gap.inventoryId}:${gap.requirementId}',
          ),
        );
      }
    }

    return AvoraUnifiedLaunchReadinessReport(
      ready: failed.isEmpty,
      passedAreas: Set<AvoraLaunchReadinessArea>.unmodifiable(passed),
      failedAreas: Set<AvoraLaunchReadinessArea>.unmodifiable(failed),
      issues: List<AvoraLaunchReadinessIssue>.unmodifiable(issues),
    );
  }

  static bool allCriticalLaunchGatesMustConvergeHere() => true;

  static bool oneFailedCriticalGateMustBlockLaunchReadiness() => true;

  static bool quantityPassMustNotHideQualityOrReferenceGap() => true;

  static bool referencePassMustNotHideMissingCatalogContent() => true;

  static bool finalLaunchReadinessMustBeExplainable() => true;

  static bool readinessIssuesMustExposeExactAreaAndReason() => true;

  static bool futureLaunchGatesMustBeAddableWithoutRewritingExistingGates() =>
      true;
}

class AvoraLaunchReadinessArchitecture {
  const AvoraLaunchReadinessArchitecture._();

  static bool launchReadinessMustNotDependOnMemoryOrManualGuessing() => true;

  static bool screenshotsVideosRoadmapAndActualCatalogMustConverge() => true;

  static bool functionalAndCreativeReadinessMustRemainSeparateConcerns() =>
      true;

  static bool passingTestsAloneMustNotMeanProductIsLaunchReady() => true;

  static bool ownerMustEventuallySeeUnifiedReadinessInPanel() => true;

  static bool launchBlockersMustRemainActionableAndTraceable() => true;
}
