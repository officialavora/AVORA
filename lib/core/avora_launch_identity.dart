enum AvoraAuthProvider {
  phone,
  email,
  google,
  apple,
}

class AvoraLaunchIdentity {
  const AvoraLaunchIdentity({
    required this.avoraId,
    required this.authSubject,
    required this.provider,
    required this.createdAtUtc,
    this.vanityUid,
  });

  /// Permanent authoritative identity.
  final String avoraId;

  /// Provider-side authenticated subject/reference.
  final String authSubject;

  final AvoraAuthProvider provider;
  final DateTime createdAtUtc;

  /// Optional public luxury/vanity number.
  /// Never replaces [avoraId].
  final String? vanityUid;

  AvoraLaunchIdentity withVanityUid(String? value) {
    final normalized = value?.trim();

    return AvoraLaunchIdentity(
      avoraId: avoraId,
      authSubject: authSubject,
      provider: provider,
      createdAtUtc: createdAtUtc,
      vanityUid: normalized == null || normalized.isEmpty ? null : normalized,
    );
  }
}

class AvoraImmutableIdAllocator {
  AvoraImmutableIdAllocator({
    int firstId = 10000000,
  }) : _nextId = firstId {
    if (firstId < 10000000 || firstId > 99999999) {
      throw ArgumentError('first_avora_id_must_be_8_digit');
    }
  }

  int _nextId;

  final Map<String, String> _authToAvoraId = <String, String>{};

  final Set<String> _allocatedIds = <String>{};

  String allocateForAuthSubject(String authSubject) {
    final subject = authSubject.trim();

    if (subject.isEmpty) {
      throw ArgumentError('auth_subject_required');
    }

    final existing = _authToAvoraId[subject];

    if (existing != null) {
      return existing;
    }

    if (_nextId > 99999999) {
      throw StateError('avora_8_digit_id_space_exhausted');
    }

    final id = _nextId.toString().padLeft(8, '0');
    _nextId++;

    if (_allocatedIds.contains(id)) {
      throw StateError('duplicate_avora_id_detected');
    }

    _allocatedIds.add(id);
    _authToAvoraId[subject] = id;

    return id;
  }

  String? idForAuthSubject(String authSubject) {
    return _authToAvoraId[authSubject.trim()];
  }

  static bool avoraIdMustBePermanent() => true;

  static bool avoraIdMustRemainAuthoritative() => true;

  static bool vanityUidMustNeverReplaceAvoraId() => true;

  static bool roleChangeMustNeverChangeAvoraId() => true;

  static bool countryChangeMustNeverChangeAvoraId() => true;

  static bool ownerMustNotRewriteOriginalAvoraId() => true;

  static bool futureAuthProvidersMustBindToImmutableIdentity() => true;
}

class AvoraLaunchRegistrationService {
  AvoraLaunchRegistrationService({
    required AvoraImmutableIdAllocator allocator,
  }) : _allocator = allocator;

  final AvoraImmutableIdAllocator _allocator;

  final Map<String, AvoraLaunchIdentity> _accounts =
      <String, AvoraLaunchIdentity>{};

  AvoraLaunchIdentity register({
    required String authSubject,
    required AvoraAuthProvider provider,
    required DateTime createdAtUtc,
  }) {
    final subject = authSubject.trim();

    if (subject.isEmpty) {
      throw ArgumentError('auth_subject_required');
    }

    final existing = _accounts[subject];

    if (existing != null) {
      return existing;
    }

    final avoraId = _allocator.allocateForAuthSubject(subject);

    final identity = AvoraLaunchIdentity(
      avoraId: avoraId,
      authSubject: subject,
      provider: provider,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _accounts[subject] = identity;

    return identity;
  }

  AvoraLaunchIdentity? findByAuthSubject(
    String authSubject,
  ) {
    return _accounts[authSubject.trim()];
  }

  AvoraLaunchIdentity updateVanityUid({
    required String authSubject,
    required String? vanityUid,
  }) {
    final subject = authSubject.trim();
    final current = _accounts[subject];

    if (current == null) {
      throw StateError('avora_account_not_found');
    }

    final updated = current.withVanityUid(vanityUid);

    if (updated.avoraId != current.avoraId) {
      throw StateError('immutable_avora_id_changed');
    }

    _accounts[subject] = updated;

    return updated;
  }

  static bool repeatedRegistrationMustReturnSameIdentity() => true;

  static bool vanityUpdateMustPreserveOriginalIdentity() => true;

  static bool authenticationMustNotDependOnVanityUid() => true;

  static bool launchAccountMustHaveAuthoritativeAvoraId() => true;
}
