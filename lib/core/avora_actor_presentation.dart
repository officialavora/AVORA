enum AvoraActorKind {
  owner,
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  merchant,
  seller,
  user,
  system,
  other,
}

class AvoraActionActor {
  const AvoraActionActor({
    required this.avoraId,
    required this.kind,
    required this.displayName,
    this.countryCode,
    this.profileImageRef,
  });

  final String avoraId;
  final AvoraActorKind kind;
  final String displayName;
  final String? countryCode;
  final String? profileImageRef;

  bool get isOwner => kind == AvoraActorKind.owner;
}

class AvoraActorPublicPresentation {
  const AvoraActorPublicPresentation({
    required this.label,
    required this.exposeAvoraId,
    required this.exposeDisplayName,
    required this.exposeCountry,
    required this.exposeProfileImage,
  });

  final String label;
  final bool exposeAvoraId;
  final bool exposeDisplayName;
  final bool exposeCountry;
  final bool exposeProfileImage;
}

class AvoraActorPresentationPolicy {
  const AvoraActorPresentationPolicy._();

  static AvoraActorPublicPresentation forPublicNotification(
    AvoraActionActor actor,
  ) {
    if (actor.isOwner) {
      return const AvoraActorPublicPresentation(
        label: 'Owner',
        exposeAvoraId: false,
        exposeDisplayName: false,
        exposeCountry: false,
        exposeProfileImage: false,
      );
    }

    return AvoraActorPublicPresentation(
      label: actor.displayName.trim().isEmpty
          ? actor.kind.name
          : actor.displayName.trim(),
      exposeAvoraId: true,
      exposeDisplayName: true,
      exposeCountry: actor.countryCode != null,
      exposeProfileImage: actor.profileImageRef != null,
    );
  }

  static bool ownerPublicIdentityMustBeMasked() => true;
  static bool ownerAuditIdentityMustRemainAuthoritative() => true;
  static bool nonOwnerActionsMustRemainAccountable() => true;
  static bool futureActionsMustUseSamePresentationPolicy() => true;
}

enum AvoraOperationalActionType {
  recharge,
  coinCredit,
  coinDebit,
  ban,
  unban,
  invite,
  referral,
  agencyJoin,
  agencyLeave,
  roleGrant,
  roleRevoke,
  permissionGrant,
  permissionRevoke,
  other,
}

class AvoraOperationalActionRecord {
  const AvoraOperationalActionRecord({
    required this.recordId,
    required this.actionType,
    required this.actor,
    required this.targetAvoraId,
    required this.createdAtUtc,
    required this.reason,
    this.amountCoins,
    this.metadata = const <String, Object?>{},
  });

  final String recordId;
  final AvoraOperationalActionType actionType;
  final AvoraActionActor actor;
  final String targetAvoraId;
  final DateTime createdAtUtc;
  final String reason;
  final int? amountCoins;
  final Map<String, Object?> metadata;
}

class AvoraOperationalActionLedger {
  final Map<String, AvoraOperationalActionRecord> _records =
      <String, AvoraOperationalActionRecord>{};

  void append(AvoraOperationalActionRecord record) {
    if (record.recordId.trim().isEmpty ||
        record.actor.avoraId.trim().isEmpty ||
        record.targetAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_operational_action_record');
    }

    if (_records.containsKey(record.recordId)) {
      throw StateError('duplicate_operational_action_record');
    }

    _records[record.recordId] = record;
  }

  List<AvoraOperationalActionRecord> get allForOwner =>
      List<AvoraOperationalActionRecord>.unmodifiable(
        _records.values,
      );

  List<AvoraOperationalActionRecord> byActor(
    String actorAvoraId,
  ) {
    return List<AvoraOperationalActionRecord>.unmodifiable(
      _records.values.where(
        (record) => record.actor.avoraId == actorAvoraId,
      ),
    );
  }

  List<AvoraOperationalActionRecord> byTarget(
    String targetAvoraId,
  ) {
    return List<AvoraOperationalActionRecord>.unmodifiable(
      _records.values.where(
        (record) => record.targetAvoraId == targetAvoraId,
      ),
    );
  }

  static bool everyRechargeMustIdentifyActorInternally() => true;
  static bool everyRechargeMustPreserveAmountAndTimestamp() => true;
  static bool sellerMerchantActionsMustBeAccountable() => true;
  static bool inviteAndAgencyChangesMustBeTraceable() => true;
  static bool ownerPublicNotificationMustHidePersonalIdentity() => true;
  static bool futureOperationalActionsMustUseSameLedger() => true;
}

class AvoraActionNotificationFormatter {
  const AvoraActionNotificationFormatter._();

  static String format(
    AvoraOperationalActionRecord record,
  ) {
    final presentation = AvoraActorPresentationPolicy.forPublicNotification(
      record.actor,
    );

    final actorLabel = record.actor.isOwner ? 'Owner' : presentation.label;

    switch (record.actionType) {
      case AvoraOperationalActionType.recharge:
      case AvoraOperationalActionType.coinCredit:
        final amount = record.amountCoins ?? 0;
        return '$actorLabel added $amount coins';

      case AvoraOperationalActionType.coinDebit:
        final amount = record.amountCoins ?? 0;
        return '$actorLabel removed $amount coins';

      case AvoraOperationalActionType.ban:
        return '$actorLabel banned this ID';

      case AvoraOperationalActionType.unban:
        return '$actorLabel unbanned this ID';

      case AvoraOperationalActionType.invite:
      case AvoraOperationalActionType.referral:
        return '$actorLabel invited this user';

      case AvoraOperationalActionType.agencyJoin:
        return '$actorLabel added this user to an agency';

      case AvoraOperationalActionType.agencyLeave:
        return '$actorLabel removed this user from an agency';

      case AvoraOperationalActionType.roleGrant:
        return '$actorLabel granted a role';

      case AvoraOperationalActionType.roleRevoke:
        return '$actorLabel revoked a role';

      case AvoraOperationalActionType.permissionGrant:
        return '$actorLabel granted a permission';

      case AvoraOperationalActionType.permissionRevoke:
        return '$actorLabel revoked a permission';

      case AvoraOperationalActionType.other:
        return '$actorLabel performed an action';
    }
  }

  static bool ownerNotificationMustSayOwnerOnly() => true;
  static bool nonOwnerNotificationMayShowAccountableIdentity() => true;
  static bool notificationMustNeverExposeOwnerSensitiveDetails() => true;
}
