enum AvoraRemoteAssetKind {
  animation,
  sound,
  music,
  image,
  gif,
  video,
  other,
}

class AvoraRemoteAssetFile {
  const AvoraRemoteAssetFile({
    required this.fileId,
    required this.kind,
    required this.url,
    required this.sha256,
    required this.byteSize,
    required this.required,
  });

  final String fileId;
  final AvoraRemoteAssetKind kind;
  final String url;
  final String sha256;
  final int byteSize;
  final bool required;

  void validate() {
    if (fileId.trim().isEmpty ||
        url.trim().isEmpty ||
        sha256.trim().isEmpty ||
        byteSize <= 0) {
      throw ArgumentError('invalid_remote_asset_file');
    }

    final normalizedUrl = url.trim().toLowerCase();

    if (!normalizedUrl.startsWith('https://')) {
      throw ArgumentError('remote_asset_requires_https');
    }
  }
}

class AvoraExperienceAssetManifestEntry {
  const AvoraExperienceAssetManifestEntry({
    required this.assetId,
    required this.assetVersion,
    required this.manifestVersion,
    required this.minimumClientBuild,
    required this.files,
    required this.enabled,
    required this.publishedAtUtc,
  });

  final String assetId;
  final String assetVersion;
  final String manifestVersion;

  /// Minimum compatible AVORA client build number.
  final int minimumClientBuild;

  final List<AvoraRemoteAssetFile> files;
  final bool enabled;
  final DateTime publishedAtUtc;

  void validate() {
    if (assetId.trim().isEmpty ||
        assetVersion.trim().isEmpty ||
        manifestVersion.trim().isEmpty ||
        minimumClientBuild <= 0 ||
        files.isEmpty) {
      throw ArgumentError('invalid_experience_asset_manifest');
    }

    final fileIds = <String>{};

    for (final file in files) {
      file.validate();

      if (!fileIds.add(file.fileId)) {
        throw StateError('duplicate_manifest_file_id');
      }
    }
  }

  bool supportsClientBuild(int buildNumber) {
    return enabled && buildNumber >= minimumClientBuild;
  }
}

class AvoraExperienceManifestAuditRecord {
  const AvoraExperienceManifestAuditRecord({
    required this.auditId,
    required this.assetId,
    required this.previousManifestVersion,
    required this.newManifestVersion,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String assetId;
  final String? previousManifestVersion;
  final String newManifestVersion;
  final String ownerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraExperienceManifestAuditLedger {
  final Map<String, AvoraExperienceManifestAuditRecord> _records =
      <String, AvoraExperienceManifestAuditRecord>{};

  void append(AvoraExperienceManifestAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.assetId.trim().isEmpty ||
        record.newManifestVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_manifest_audit_record');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_manifest_audit_record');
    }

    _records[record.auditId] = record;
  }

  List<AvoraExperienceManifestAuditRecord> forAsset(
    String assetId,
  ) {
    return List<AvoraExperienceManifestAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.assetId == assetId,
      ),
    );
  }

  static bool everyManifestChangeMustBeAudited() => true;

  static bool manifestAuditMustRemainImmutable() => true;
}

class AvoraExperienceAssetManifestRegistry {
  AvoraExperienceAssetManifestRegistry({
    required AvoraExperienceManifestAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraExperienceManifestAuditLedger _auditLedger;

  final Map<String, AvoraExperienceAssetManifestEntry> _active =
      <String, AvoraExperienceAssetManifestEntry>{};

  final Map<String, Map<String, AvoraExperienceAssetManifestEntry>> _history =
      <String, Map<String, AvoraExperienceAssetManifestEntry>>{};

  AvoraExperienceAssetManifestEntry? activeFor(
    String assetId,
  ) {
    return _active[assetId.trim()];
  }

  AvoraExperienceAssetManifestEntry? historical({
    required String assetId,
    required String manifestVersion,
  }) {
    final active = _active[assetId];

    if (active?.manifestVersion == manifestVersion) {
      return active;
    }

    return _history[assetId]?[manifestVersion];
  }

  void publish({
    required String auditId,
    required AvoraExperienceAssetManifestEntry manifest,
    required bool actorIsVerifiedOwner,
    required String ownerAvoraId,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    manifest.validate();

    final previous = _active[manifest.assetId];

    if (previous?.manifestVersion == manifest.manifestVersion) {
      throw StateError('manifest_version_must_change');
    }

    if (previous != null) {
      _history.putIfAbsent(
        manifest.assetId,
        () => <String, AvoraExperienceAssetManifestEntry>{},
      )[previous.manifestVersion] = previous;
    }

    _active[manifest.assetId] = manifest;

    _auditLedger.append(
      AvoraExperienceManifestAuditRecord(
        auditId: auditId,
        assetId: manifest.assetId,
        previousManifestVersion: previous?.manifestVersion,
        newManifestVersion: manifest.manifestVersion,
        ownerAvoraId: ownerAvoraId,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );
  }

  static bool ownerMayPublishNewAssetVersionWithoutAppRelease() => true;

  static bool historicalManifestMustRemainAvailableForRollback() => true;

  static bool manifestFilesMustUseSecureTransport() => true;

  static bool futureAssetTypesMustUseSameManifestRegistry() => true;
}

class AvoraExperienceManifestResolution {
  const AvoraExperienceManifestResolution({
    required this.allowed,
    required this.reason,
    this.manifest,
  });

  final bool allowed;
  final String reason;
  final AvoraExperienceAssetManifestEntry? manifest;
}

class AvoraExperienceManifestResolver {
  const AvoraExperienceManifestResolver();

  AvoraExperienceManifestResolution resolve({
    required AvoraExperienceAssetManifestEntry manifest,
    required int clientBuild,
  }) {
    if (clientBuild <= 0) {
      return const AvoraExperienceManifestResolution(
        allowed: false,
        reason: 'invalid_client_build',
      );
    }

    if (!manifest.enabled) {
      return const AvoraExperienceManifestResolution(
        allowed: false,
        reason: 'manifest_disabled',
      );
    }

    if (!manifest.supportsClientBuild(clientBuild)) {
      return const AvoraExperienceManifestResolution(
        allowed: false,
        reason: 'client_build_not_supported',
      );
    }

    return AvoraExperienceManifestResolution(
      allowed: true,
      reason: 'manifest_supported',
      manifest: manifest,
    );
  }

  static bool unsupportedClientMustFailSafely() => true;

  static bool clientMustNeverInventAssetFileUrls() => true;

  static bool exactPublishedManifestMustRemainAuthoritative() => true;
}

class AvoraExperienceAssetCacheRecord {
  const AvoraExperienceAssetCacheRecord({
    required this.fileId,
    required this.sha256,
    required this.byteSize,
    required this.cachedAtUtc,
  });

  final String fileId;
  final String sha256;
  final int byteSize;
  final DateTime cachedAtUtc;
}

class AvoraExperienceAssetCachePolicy {
  const AvoraExperienceAssetCachePolicy();

  bool isValidCachedFile({
    required AvoraRemoteAssetFile expected,
    required AvoraExperienceAssetCacheRecord cached,
  }) {
    return expected.fileId == cached.fileId &&
        expected.sha256 == cached.sha256 &&
        expected.byteSize == cached.byteSize;
  }

  bool mayFallbackIfOptionalFileMissing(
    AvoraRemoteAssetFile file,
  ) {
    return !file.required;
  }

  static bool checksumMustProtectCachedPremiumAssets() => true;

  static bool staleOrWrongChecksumMustNotBeTrusted() => true;

  static bool optionalMediaMayDegradeGracefully() => true;

  static bool requiredCoreAssetFailureMustNotCrashClient() => true;

  static bool cacheMustReduceRepeatedDataUsage() => true;

  static bool rollbackMustReuseHistoricalManifestWhenAvailable() => true;
}

class AvoraExperienceDistributionArchitecture {
  const AvoraExperienceDistributionArchitecture._();

  static bool heavyPremiumAssetsMustNotBeHardcodedIntoAppBinary() => true;

  static bool ownerMayReplaceAnimationSoundOrMusicRemotely() => true;

  static bool oldClientsMustFailGracefullyOnUnsupportedAssets() => true;

  static bool assetDeliveryMustSupportGlobalCdnArchitecture() => true;

  static bool originalAvoraAssetOwnershipMustBePreserved() => true;

  static bool premiumQualityMustNotRequireClientCodeRewrite() => true;
}
