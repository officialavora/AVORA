enum AvoraBannerType {
  promotion,
  officialAnnouncement,
  countryManager,
  birthday,
  event,
  festival,
  sellerMerchant,
  creatorFeatured,
  systemNotice,
  campaign,
  custom,
}

enum AvoraBannerScopeType {
  global,
  country,
  region,
}

enum AvoraBannerStatus {
  draft,
  active,
  paused,
  expired,
  revoked,
}

enum AvoraBannerPriority {
  normal,
  high,
  critical,
}

class AvoraBannerScope {
  final AvoraBannerScopeType type;

  /// ISO country code or region ID.
  final String? scopeId;

  /// Optional language targeting.
  final Set<String> languageCodes;

  const AvoraBannerScope._({
    required this.type,
    this.scopeId,
    this.languageCodes = const {},
  });

  const AvoraBannerScope.global({
    Set<String> languageCodes = const {},
  }) : this._(
          type: AvoraBannerScopeType.global,
          languageCodes: languageCodes,
        );

  const AvoraBannerScope.country(
    String countryCode, {
    Set<String> languageCodes = const {},
  }) : this._(
          type: AvoraBannerScopeType.country,
          scopeId: countryCode,
          languageCodes: languageCodes,
        );

  const AvoraBannerScope.region(
    String regionId, {
    Set<String> languageCodes = const {},
  }) : this._(
          type: AvoraBannerScopeType.region,
          scopeId: regionId,
          languageCodes: languageCodes,
        );
}

class AvoraBannerCampaign {
  final String id;

  final AvoraBannerType type;
  final AvoraBannerScope scope;

  final AvoraBannerStatus status;
  final AvoraBannerPriority priority;

  final String title;
  final String? subtitle;

  /// Asset/catalog references.
  final String? imageAssetId;
  final String? animationAssetId;

  /// Optional deep-link destination.
  final String? deepLink;

  /// Optional promoted entity:
  /// user, room, event, seller, merchant, etc.
  final String? targetEntityId;

  final bool requiresVerifiedTarget;
  final bool targetVerified;

  final DateTime startsAt;

  /// Null means permanent until paused/revoked.
  final DateTime? endsAt;

  /// Rotation order among banners with same priority.
  final int rotationOrder;

  final String createdByUserId;
  final DateTime createdAt;

  final String? revokedByUserId;
  final DateTime? revokedAt;
  final String? revokeReason;

  const AvoraBannerCampaign({
    required this.id,
    required this.type,
    required this.scope,
    required this.status,
    required this.priority,
    required this.title,
    required this.startsAt,
    required this.rotationOrder,
    required this.createdByUserId,
    required this.createdAt,
    this.subtitle,
    this.imageAssetId,
    this.animationAssetId,
    this.deepLink,
    this.targetEntityId,
    this.requiresVerifiedTarget = false,
    this.targetVerified = false,
    this.endsAt,
    this.revokedByUserId,
    this.revokedAt,
    this.revokeReason,
  }) : assert(rotationOrder >= 0);

  bool isActiveAt(DateTime time) {
    if (status != AvoraBannerStatus.active) {
      return false;
    }

    if (time.isBefore(startsAt)) {
      return false;
    }

    final end = endsAt;

    if (end != null && time.isAfter(end)) {
      return false;
    }

    if (requiresVerifiedTarget && !targetVerified) {
      return false;
    }

    return true;
  }

  bool matchesCountry(String countryCode) {
    if (scope.type == AvoraBannerScopeType.global) {
      return true;
    }

    if (scope.type != AvoraBannerScopeType.country) {
      return false;
    }

    return scope.scopeId?.trim().toUpperCase() ==
        countryCode.trim().toUpperCase();
  }

  bool matchesLanguage(String languageCode) {
    if (scope.languageCodes.isEmpty) {
      return true;
    }

    final requested = languageCode.trim().toLowerCase();

    return scope.languageCodes.any(
      (item) => item.trim().toLowerCase() == requested,
    );
  }
}

class AvoraBannerSelector {
  const AvoraBannerSelector._();

  static List<AvoraBannerCampaign> visibleBanners({
    required List<AvoraBannerCampaign> banners,
    required String countryCode,
    required String languageCode,
    required DateTime now,
  }) {
    final visible = banners.where((banner) {
      return banner.isActiveAt(now) &&
          banner.matchesCountry(countryCode) &&
          banner.matchesLanguage(languageCode);
    }).toList(growable: false);

    visible.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);

      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return a.rotationOrder.compareTo(b.rotationOrder);
    });

    return visible;
  }
}
