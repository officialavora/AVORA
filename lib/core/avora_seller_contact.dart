import 'avora_seller_capacity.dart';

enum AvoraSellerContactChannel {
  inApp,
  whatsapp,
}

enum AvoraSellerContactDenyReason {
  none,
  sellerNotListed,
  sellerNotVerified,
  contactDisabled,
  blocked,
  requesterRiskBlocked,
  rateLimited,
  externalContactNotVerified,
}

class AvoraSellerContactProfile {
  final String sellerUserId;

  final AvoraTradingRole role;

  final bool listed;
  final bool verified;

  final bool online;

  /// In-app Seller Inquiry inbox.
  final bool inAppContactEnabled;

  /// Optional external fallback.
  final bool whatsappEnabled;

  /// Contact number/account has been verified/approved.
  final bool whatsappContactVerified;

  /// Opaque backend reference.
  /// Do not expose raw personal phone number publicly.
  final String? whatsappContactReference;

  const AvoraSellerContactProfile({
    required this.sellerUserId,
    required this.role,
    required this.listed,
    required this.verified,
    required this.online,
    this.inAppContactEnabled = true,
    this.whatsappEnabled = false,
    this.whatsappContactVerified = false,
    this.whatsappContactReference,
  });
}

class AvoraSellerContactRequest {
  final String requesterUserId;

  /// Seller contact never requires follow/friendship.
  final bool blockedEitherDirection;

  final bool requesterRiskBlocked;
  final bool rateLimited;

  /// Optional AVORA order reference for safe support context.
  final String? orderId;

  const AvoraSellerContactRequest({
    required this.requesterUserId,
    this.blockedEitherDirection = false,
    this.requesterRiskBlocked = false,
    this.rateLimited = false,
    this.orderId,
  });
}

class AvoraSellerContactDecision {
  final bool allowed;

  final AvoraSellerContactChannel channel;

  final AvoraSellerContactDenyReason reason;

  /// Seller Inquiry bypasses normal friendship/message-request flow.
  final bool requiresFriendship;
  final bool requiresFollow;
  final bool requiresMessageRequest;

  /// Safe context that may be included in an external handoff.
  final String? safeOrderReference;

  const AvoraSellerContactDecision({
    required this.allowed,
    required this.channel,
    required this.reason,
    required this.requiresFriendship,
    required this.requiresFollow,
    required this.requiresMessageRequest,
    this.safeOrderReference,
  });
}

class AvoraSellerContactPolicy {
  const AvoraSellerContactPolicy._();

  static AvoraSellerContactDecision evaluate({
    required AvoraSellerContactProfile seller,
    required AvoraSellerContactRequest request,
    required AvoraSellerContactChannel channel,
  }) {
    AvoraSellerContactDecision deny(
      AvoraSellerContactDenyReason reason,
    ) {
      return AvoraSellerContactDecision(
        allowed: false,
        channel: channel,
        reason: reason,
        requiresFriendship: false,
        requiresFollow: false,
        requiresMessageRequest: false,
      );
    }

    if (!seller.listed) {
      return deny(
        AvoraSellerContactDenyReason.sellerNotListed,
      );
    }

    if (!seller.verified) {
      return deny(
        AvoraSellerContactDenyReason.sellerNotVerified,
      );
    }

    if (request.blockedEitherDirection) {
      return deny(
        AvoraSellerContactDenyReason.blocked,
      );
    }

    if (request.requesterRiskBlocked) {
      return deny(
        AvoraSellerContactDenyReason.requesterRiskBlocked,
      );
    }

    if (request.rateLimited) {
      return deny(
        AvoraSellerContactDenyReason.rateLimited,
      );
    }

    switch (channel) {
      case AvoraSellerContactChannel.inApp:
        if (!seller.inAppContactEnabled) {
          return deny(
            AvoraSellerContactDenyReason.contactDisabled,
          );
        }

      case AvoraSellerContactChannel.whatsapp:
        if (!seller.whatsappEnabled) {
          return deny(
            AvoraSellerContactDenyReason.contactDisabled,
          );
        }

        if (!seller.whatsappContactVerified ||
            seller.whatsappContactReference == null ||
            seller.whatsappContactReference!.trim().isEmpty) {
          return deny(
            AvoraSellerContactDenyReason.externalContactNotVerified,
          );
        }
    }

    return AvoraSellerContactDecision(
      allowed: true,
      channel: channel,
      reason: AvoraSellerContactDenyReason.none,
      requiresFriendship: false,
      requiresFollow: false,
      requiresMessageRequest: false,
      safeOrderReference: request.orderId?.trim(),
    );
  }

  /// UI recommendation:
  /// In-app remains primary.
  /// WhatsApp becomes more prominent when seller is offline.
  static AvoraSellerContactChannel preferredChannel({
    required AvoraSellerContactProfile seller,
  }) {
    if (!seller.online &&
        seller.whatsappEnabled &&
        seller.whatsappContactVerified &&
        seller.whatsappContactReference != null) {
      return AvoraSellerContactChannel.whatsapp;
    }

    return AvoraSellerContactChannel.inApp;
  }
}
