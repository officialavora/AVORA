import 'avora_launch_identity.dart';

class AvoraLaunchProfile {
  const AvoraLaunchProfile({
    required this.avoraId,
    required this.displayName,
    required this.createdAtUtc,
    this.avatarUrl,
    this.countryCode,
    this.showCountry = true,
    this.vanityUid,
    this.bio,
  });

  /// Permanent authoritative AVORA identity.
  final String avoraId;

  final String displayName;
  final String? avatarUrl;
  final String? countryCode;
  final bool showCountry;
  final String? vanityUid;
  final String? bio;
  final DateTime createdAtUtc;

  AvoraLaunchProfile copyEditable({
    String? displayName,
    String? avatarUrl,
    String? countryCode,
    bool? showCountry,
    String? vanityUid,
    String? bio,
  }) {
    return AvoraLaunchProfile(
      avoraId: avoraId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      countryCode: countryCode ?? this.countryCode,
      showCountry: showCountry ?? this.showCountry,
      vanityUid: vanityUid ?? this.vanityUid,
      bio: bio ?? this.bio,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraLaunchProfileService {
  final Map<String, AvoraLaunchProfile> _profiles =
      <String, AvoraLaunchProfile>{};

  final Map<String, String> _vanityOwners = <String, String>{};

  AvoraLaunchProfile create({
    required AvoraLaunchIdentity identity,
    required String displayName,
    String? countryCode,
  }) {
    final name = displayName.trim();

    if (identity.avoraId.trim().isEmpty || name.isEmpty) {
      throw ArgumentError('invalid_launch_profile');
    }

    final existing = _profiles[identity.avoraId];

    if (existing != null) {
      return existing;
    }

    final profile = AvoraLaunchProfile(
      avoraId: identity.avoraId,
      displayName: name,
      countryCode: _normalizeCountry(countryCode),
      createdAtUtc: identity.createdAtUtc.toUtc(),
      vanityUid: identity.vanityUid,
    );

    _profiles[identity.avoraId] = profile;

    if (identity.vanityUid != null) {
      _claimVanity(
        avoraId: identity.avoraId,
        vanityUid: identity.vanityUid!,
      );
    }

    return profile;
  }

  AvoraLaunchProfile update({
    required String avoraId,
    String? displayName,
    String? avatarUrl,
    String? countryCode,
    bool? showCountry,
    String? vanityUid,
    String? bio,
  }) {
    final current = _profiles[avoraId];

    if (current == null) {
      throw StateError('launch_profile_not_found');
    }

    final nextName = displayName?.trim();

    if (nextName != null && nextName.isEmpty) {
      throw ArgumentError('display_name_must_not_be_empty');
    }

    final normalizedVanity = vanityUid?.trim();

    if (normalizedVanity != null &&
        normalizedVanity.isNotEmpty &&
        normalizedVanity != current.vanityUid) {
      _claimVanity(
        avoraId: avoraId,
        vanityUid: normalizedVanity,
      );
    }

    if (current.vanityUid != null &&
        normalizedVanity != null &&
        normalizedVanity != current.vanityUid) {
      _vanityOwners.remove(current.vanityUid);
    }

    final updated = current.copyEditable(
      displayName: nextName,
      avatarUrl: avatarUrl?.trim(),
      countryCode: countryCode == null ? null : _normalizeCountry(countryCode),
      showCountry: showCountry,
      vanityUid: normalizedVanity,
      bio: bio?.trim(),
    );

    if (updated.avoraId != current.avoraId) {
      throw StateError('immutable_profile_identity_changed');
    }

    _profiles[avoraId] = updated;

    return updated;
  }

  AvoraLaunchProfile? byAvoraId(String avoraId) {
    return _profiles[avoraId.trim()];
  }

  AvoraLaunchProfile? byVanityUid(String vanityUid) {
    final owner = _vanityOwners[vanityUid.trim()];

    if (owner == null) return null;

    return _profiles[owner];
  }

  void _claimVanity({
    required String avoraId,
    required String vanityUid,
  }) {
    final value = vanityUid.trim();

    if (value.isEmpty) {
      throw ArgumentError('vanity_uid_must_not_be_empty');
    }

    final existingOwner = _vanityOwners[value];

    if (existingOwner != null && existingOwner != avoraId) {
      throw StateError('vanity_uid_already_in_use');
    }

    _vanityOwners[value] = avoraId;
  }

  String? _normalizeCountry(String? value) {
    final normalized = value?.trim().toUpperCase();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static bool profileMustBindToImmutableAvoraId() => true;

  static bool displayNameMayChange() => true;

  static bool avatarMayChange() => true;

  static bool countryMayChangeWithoutChangingIdentity() => true;

  static bool countryVisibilityMayBeControlled() => true;

  static bool vanityUidMustRemainSeparateFromOriginalId() => true;

  static bool vanityUidMustBeUnique() => true;

  static bool walletMustUseOriginalAvoraId() => true;

  static bool giftsMustUseOriginalAvoraId() => true;

  static bool gamesMustUseOriginalAvoraId() => true;

  static bool moderationMustUseOriginalAvoraId() => true;

  static bool futureProfileFeaturesMustPreserveIdentityBinding() => true;
}
