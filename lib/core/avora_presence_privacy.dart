enum AvoraPresenceVisibility { everyone, followers, friends, nobody }

class AvoraPresencePrivacySettings {
  const AvoraPresencePrivacySettings({
    this.visibility = AvoraPresenceVisibility.friends,
    this.allowOnlineAlerts = false,
    this.showLastSeen = false,
  });

  final AvoraPresenceVisibility visibility;
  final bool allowOnlineAlerts;
  final bool showLastSeen;
}

class AvoraPresenceViewerContext {
  const AvoraPresenceViewerContext({
    required this.sameUser,
    required this.viewerFollows,
    required this.friends,
    required this.blockedEitherDirection,
  });

  final bool sameUser;
  final bool viewerFollows;
  final bool friends;
  final bool blockedEitherDirection;
}

class AvoraPresencePrivacyPolicy {
  const AvoraPresencePrivacyPolicy._();

  static bool canView({
    required AvoraPresencePrivacySettings settings,
    required AvoraPresenceViewerContext viewer,
  }) {
    if (viewer.blockedEitherDirection) return false;
    if (viewer.sameUser) return true;
    return switch (settings.visibility) {
      AvoraPresenceVisibility.everyone => true,
      AvoraPresenceVisibility.followers => viewer.viewerFollows,
      AvoraPresenceVisibility.friends => viewer.friends,
      AvoraPresenceVisibility.nobody => false,
    };
  }

  static bool clientCannotBypassPresencePrivacy() => true;
}
