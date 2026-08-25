enum AvoraSocialConnectionType { follow, friend, block }
enum AvoraSocialConnectionStatus { pending, active, declined, ended }

class AvoraSocialConnection {
  const AvoraSocialConnection({
    required this.connectionId,
    required this.sourceAvoraId,
    required this.targetAvoraId,
    required this.type,
    required this.status,
    required this.createdAtUtc,
  });

  final String connectionId;
  final String sourceAvoraId;
  final String targetAvoraId;
  final AvoraSocialConnectionType type;
  final AvoraSocialConnectionStatus status;
  final DateTime createdAtUtc;

  bool get isStructurallyValid =>
      connectionId.trim().isNotEmpty &&
      sourceAvoraId.trim().isNotEmpty &&
      targetAvoraId.trim().isNotEmpty &&
      sourceAvoraId != targetAvoraId;
}

class AvoraSocialGraphPolicy {
  const AvoraSocialGraphPolicy._();

  static bool areFriends({
    required String firstAvoraId,
    required String secondAvoraId,
    required Iterable<AvoraSocialConnection> connections,
  }) {
    return connections.any(
      (item) =>
          item.type == AvoraSocialConnectionType.friend &&
          item.status == AvoraSocialConnectionStatus.active &&
          ((item.sourceAvoraId == firstAvoraId &&
                  item.targetAvoraId == secondAvoraId) ||
              (item.sourceAvoraId == secondAvoraId &&
                  item.targetAvoraId == firstAvoraId)),
    );
  }

  static bool blockedEitherDirection({
    required String firstAvoraId,
    required String secondAvoraId,
    required Iterable<AvoraSocialConnection> connections,
  }) {
    return connections.any(
      (item) =>
          item.type == AvoraSocialConnectionType.block &&
          item.status == AvoraSocialConnectionStatus.active &&
          ((item.sourceAvoraId == firstAvoraId &&
                  item.targetAvoraId == secondAvoraId) ||
              (item.sourceAvoraId == secondAvoraId &&
                  item.targetAvoraId == firstAvoraId)),
    );
  }

  static bool blockOverridesFollowFriendAndMessaging() => true;
  static bool friendAcceptanceRequiresTheTargetUser() => true;
}
