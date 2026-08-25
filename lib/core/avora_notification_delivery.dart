enum AvoraNotificationCategory {
  message,
  roomInvite,
  gift,
  recharge,
  safety,
  account,
  system,
}

enum AvoraNotificationPriority { normal, important, critical }
enum AvoraNotificationDeliveryStatus { queued, sent, delivered, read, failed }

class AvoraNotificationEnvelope {
  const AvoraNotificationEnvelope({
    required this.notificationId,
    required this.recipientAvoraId,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAtUtc,
    this.referenceId,
    this.requiresAcknowledgement = false,
  });

  final String notificationId;
  final String recipientAvoraId;
  final AvoraNotificationCategory category;
  final AvoraNotificationPriority priority;
  final String title;
  final String body;
  final String? referenceId;
  final AvoraNotificationDeliveryStatus status;
  final DateTime createdAtUtc;
  final bool requiresAcknowledgement;

  bool get isStructurallyValid =>
      notificationId.trim().isNotEmpty &&
      recipientAvoraId.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      body.trim().isNotEmpty &&
      (!requiresAcknowledgement || priority == AvoraNotificationPriority.critical);
}

class AvoraPushDeviceRegistration {
  const AvoraPushDeviceRegistration({
    required this.registrationId,
    required this.avoraId,
    required this.platform,
    required this.tokenReference,
    required this.active,
    required this.updatedAtUtc,
  });

  final String registrationId;
  final String avoraId;
  final String platform;
  final String tokenReference;
  final bool active;
  final DateTime updatedAtUtc;

  static bool rawDeviceTokenMustNotBePublicProfileData() => true;
  static bool signOutMustDeactivateTheDeviceRegistration() => true;
}

class AvoraNotificationDeliveryPolicy {
  const AvoraNotificationDeliveryPolicy._();

  static bool backgroundPushMayBeUsedWhenAppIsClosed() => true;
  static bool criticalAcknowledgementMustBeServerRecorded() => true;
  static bool blockedUsersCannotSendDirectNotifications() => true;
  static bool duplicateReferenceMustBeIdempotent() => true;
}
