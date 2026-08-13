enum AvoraPowerCode {
  userOperationalView,
  roomManage,
  agencyManage,
  countryTeamManage,
  moderation,
  support,
  accountRecovery,
  bannerManage,
  eventManage,
  talentManage,
  analyticsView,

  sellerGlobalRecharge,
  rechargeManage,
  earningsAdvanceManage,
  payoutManage,
  coinTreasuryManage,

  officialNotificationSend,
  notificationManage,
  roleManage,
  powerManage,
}

enum AvoraPowerScope {
  global,
  country,
  region,
  agency,
  room,
  user,
}

class AvoraIdPowerGrant {
  const AvoraIdPowerGrant({
    required this.grantId,
    required this.subjectAvoraId,
    required this.grantedByAvoraId,
    required this.power,
    required this.scope,
    this.scopeId,
    required this.validFrom,
    this.validUntil,
    this.canDelegate = false,
    this.active = true,
    required this.reason,
  });

  final String grantId;
  final String subjectAvoraId;
  final String grantedByAvoraId;
  final AvoraPowerCode power;
  final AvoraPowerScope scope;
  final String? scopeId;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool canDelegate;
  final bool active;
  final String reason;

  bool isActiveAt(DateTime now) {
    if (!active || now.isBefore(validFrom)) return false;
    final end = validUntil;
    return end == null || now.isBefore(end);
  }

  bool covers(AvoraPowerScope targetScope, String? targetScopeId) {
    if (scope == AvoraPowerScope.global) return true;
    return scope == targetScope && scopeId != null && scopeId == targetScopeId;
  }
}

class AvoraPowerCenterEngine {
  static bool canUse({
    required bool actorIsOwner,
    required String actorAvoraId,
    required Iterable<AvoraIdPowerGrant> grants,
    required AvoraPowerCode power,
    required AvoraPowerScope targetScope,
    String? targetScopeId,
    required DateTime now,
  }) {
    if (actorIsOwner) return true;

    return grants.any(
      (grant) =>
          grant.subjectAvoraId == actorAvoraId &&
          grant.power == power &&
          grant.isActiveAt(now) &&
          grant.covers(targetScope, targetScopeId),
    );
  }

  static bool canDelegate({
    required bool actorIsOwner,
    required String actorAvoraId,
    required Iterable<AvoraIdPowerGrant> grants,
    required AvoraPowerCode power,
    required AvoraPowerScope targetScope,
    String? targetScopeId,
    required DateTime now,
  }) {
    if (actorIsOwner) return true;

    return grants.any(
      (grant) =>
          grant.subjectAvoraId == actorAvoraId &&
          grant.power == power &&
          grant.canDelegate &&
          grant.isActiveAt(now) &&
          grant.covers(targetScope, targetScopeId),
    );
  }

  /// Seller with this global grant may recharge an eligible user
  /// anywhere in AVORA without friendship/follow-back.
  static bool sellerCanRechargeGlobally({
    required String sellerAvoraId,
    required Iterable<AvoraIdPowerGrant> grants,
    required DateTime now,
  }) {
    return grants.any(
      (grant) =>
          grant.subjectAvoraId == sellerAvoraId &&
          grant.power == AvoraPowerCode.sellerGlobalRecharge &&
          grant.scope == AvoraPowerScope.global &&
          grant.isActiveAt(now),
    );
  }

  /// Public badge/title/frame never creates backend authority.
  static bool presentationGrantsAuthority() => false;

  /// Mobile client cannot mint its own powers.
  static bool clientCanSelfGrantPower() => false;

  /// Passwords/tokens/signing secrets are never exposed.
  static bool exposesRawSecrets() => false;
}
