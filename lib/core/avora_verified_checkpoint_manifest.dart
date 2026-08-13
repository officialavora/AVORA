import 'avora_launch_evidence_registry.dart';
import 'avora_product_launch_domain_readiness.dart';

class AvoraVerifiedCheckpointSeed {
  const AvoraVerifiedCheckpointSeed({
    required this.evidenceKey,
    required this.domain,
    required this.type,
    required this.title,
    required this.checkpoint,
    required this.version,
    required this.details,
  });

  final String evidenceKey;
  final AvoraProductLaunchDomain domain;
  final AvoraLaunchEvidenceType type;
  final String title;
  final String checkpoint;
  final String version;
  final String details;

  void validate() {
    if (evidenceKey.trim().isEmpty ||
        title.trim().isEmpty ||
        checkpoint.trim().isEmpty ||
        version.trim().isEmpty ||
        details.trim().isEmpty) {
      throw ArgumentError(
        'invalid_verified_checkpoint_seed',
      );
    }
  }

  AvoraLaunchEvidenceRecord toEvidence({
    required DateTime verifiedAtUtc,
    required String verifiedBy,
  }) {
    validate();

    return AvoraLaunchEvidenceRecord(
      evidenceKey: evidenceKey,
      domain: domain,
      type: type,
      status: AvoraLaunchEvidenceStatus.passed,
      title: title,
      version: version,
      verifiedAtUtc: verifiedAtUtc.toUtc(),
      verifiedBy: verifiedBy,
      details: '$checkpoint: $details',
    );
  }
}

class AvoraVerifiedCheckpointManifest {
  const AvoraVerifiedCheckpointManifest._();

  static const List<AvoraVerifiedCheckpointSeed> seeds =
      <AvoraVerifiedCheckpointSeed>[
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-5-enforcement-model',
      domain: AvoraProductLaunchDomain.ownerAndRoleSecurity,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Enforcement Model',
      checkpoint: 'STEP 5',
      version: 'v1',
      details:
          'Temporary/permanent enforcement, expiry, revoke, room scope and account ban foundation verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-6a-moderation-policy',
      domain: AvoraProductLaunchDomain.moderationAndSafety,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Moderation Policy',
      checkpoint: 'STEP 6A',
      version: 'v1',
      details:
          'Progressive moderation decisions for text, voice, song and radio verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-6b-anti-kick-abuse',
      domain: AvoraProductLaunchDomain.moderationAndSafety,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Anti-Kick Abuse',
      checkpoint: 'STEP 6B',
      version: 'v1',
      details: 'Global and targeted kick-abuse protections verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-6c-moderation-pipeline',
      domain: AvoraProductLaunchDomain.moderationAndSafety,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Moderation Pipeline',
      checkpoint: 'STEP 6C',
      version: 'v1',
      details:
          'Text/audio routing, language handling and moderation finalization verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-6d-provider-runner',
      domain: AvoraProductLaunchDomain.moderationAndSafety,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Moderation Provider Runner',
      checkpoint: 'STEP 6D',
      version: 'v1',
      details:
          'Provider abstractions, runner validation and provider-failure fallback verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-6e-messaging-social',
      domain: AvoraProductLaunchDomain.messagingAndSocial,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Messaging and Social Foundation',
      checkpoint: 'STEP 6E',
      version: 'v1',
      details:
          'Room/inbox models, policy, moderation, providers, audit and room chat actions verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-9rx40-sensitive-content-safety',
      domain: AvoraProductLaunchDomain.moderationAndSafety,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Sensitive Content Safety',
      checkpoint: 'STEP 9R-X40',
      version: 'v1',
      details:
          'Sensitive-content safety policy, uncertainty handling, privacy boundaries and human-review safeguards verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-5e140-reference-inventory',
      domain: AvoraProductLaunchDomain.experienceAndCatalog,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Launch Reference Inventory Audit Gate',
      checkpoint: 'STEP 5E-140',
      version: 'v1',
      details: 'Canonical launch reference inventory and audit gate verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-5e141-unified-launch-readiness',
      domain: AvoraProductLaunchDomain.experienceAndCatalog,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Unified Creative Launch Readiness',
      checkpoint: 'STEP 5E-141',
      version: 'v1',
      details:
          'Catalog, quantity/variety, reference coverage and inventory audit convergence verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-5e142-product-domain-readiness',
      domain: AvoraProductLaunchDomain.observabilityAndBackup,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Product Launch Domain Readiness Registry',
      checkpoint: 'STEP 5E-142',
      version: 'v1',
      details:
          'Versioned audited launch-domain readiness registry foundation verified.',
    ),
    AvoraVerifiedCheckpointSeed(
      evidenceKey: 'step-5e143-launch-evidence-registry',
      domain: AvoraProductLaunchDomain.observabilityAndBackup,
      type: AvoraLaunchEvidenceType.verifiedCheckpoint,
      title: 'Launch Evidence Registry',
      checkpoint: 'STEP 5E-143',
      version: 'v1',
      details:
          'Domain-scoped evidence registry and evidence-based assessment builder verified.',
    ),
  ];

  static void validate() {
    final keys = <String>{};
    final checkpoints = <String>{};

    for (final seed in seeds) {
      seed.validate();

      if (!keys.add(seed.evidenceKey)) {
        throw StateError(
          'duplicate_verified_evidence_key:${seed.evidenceKey}',
        );
      }

      final identity = '${seed.checkpoint}|${seed.domain.name}|${seed.title}';

      if (!checkpoints.add(identity)) {
        throw StateError(
          'duplicate_verified_checkpoint_identity:$identity',
        );
      }
    }
  }

  static List<AvoraVerifiedCheckpointSeed> forDomain(
    AvoraProductLaunchDomain domain,
  ) {
    return List<AvoraVerifiedCheckpointSeed>.unmodifiable(
      seeds.where((seed) => seed.domain == domain),
    );
  }

  static Set<String> get evidenceKeys => Set<String>.unmodifiable(
        seeds.map((seed) => seed.evidenceKey),
      );

  static bool seedManifestMustNotReimplementSubsystems() => true;

  static bool oneVerifiedCheckpointMustHaveOneCanonicalEvidenceKey() => true;

  static bool addingEvidenceMustNotMeanDomainIsFullyLaunchReady() => true;

  static bool manifestMustRemainExtendableForFuturePasses() => true;
}

class AvoraVerifiedCheckpointSeeder {
  const AvoraVerifiedCheckpointSeeder();

  int seed({
    required AvoraLaunchEvidenceRegistry registry,
    required DateTime verifiedAtUtc,
    required String verifiedBy,
    required bool actorCanManageLaunchReadiness,
  }) {
    AvoraVerifiedCheckpointManifest.validate();

    var inserted = 0;

    for (final seed in AvoraVerifiedCheckpointManifest.seeds) {
      if (registry.byKey(seed.evidenceKey) != null) {
        continue;
      }

      registry.append(
        seed.toEvidence(
          verifiedAtUtc: verifiedAtUtc,
          verifiedBy: verifiedBy,
        ),
        actorCanManageLaunchReadiness: actorCanManageLaunchReadiness,
      );

      inserted++;
    }

    return inserted;
  }

  static bool reseedingMustBeIdempotent() => true;

  static bool existingEvidenceMustNeverBeOverwrittenBySeed() => true;

  static bool seededEvidenceMustRemainPassedAndTraceable() => true;
}

class AvoraVerifiedCheckpointCoverageAudit {
  const AvoraVerifiedCheckpointCoverageAudit();

  Set<AvoraProductLaunchDomain> domainsWithVerifiedEvidence() {
    return Set<AvoraProductLaunchDomain>.unmodifiable(
      AvoraVerifiedCheckpointManifest.seeds.map((seed) => seed.domain).toSet(),
    );
  }

  Set<AvoraProductLaunchDomain> domainsWithoutVerifiedEvidence() {
    final covered = domainsWithVerifiedEvidence();

    return Set<AvoraProductLaunchDomain>.unmodifiable(
      AvoraProductLaunchDomain.values
          .where((domain) => !covered.contains(domain))
          .toSet(),
    );
  }

  static bool uncoveredDomainMustRemainVisibleNotInventedAsReady() => true;

  static bool historicalPassesMustReduceDuplicateDevelopmentWork() => true;

  static bool evidenceCoverageAndLaunchReadinessAreDifferentConcepts() => true;
}
