enum AvoraPublicContactContentType {
  phoneNumber,
  externalLink,
  qrCode,
  promotionalText,
  unknown,
}

enum AvoraPublicContactAction {
  allow,
  blur,
  block,
  review,
}

class AvoraPublicContactContentSignal {
  const AvoraPublicContactContentSignal({
    required this.type,
    required this.confidence,
    required this.isPublicRoom,
    required this.isOwnerApproved,
  });

  final AvoraPublicContactContentType type;

  /// 0.0 - 1.0
  final double confidence;

  final bool isPublicRoom;
  final bool isOwnerApproved;
}

class AvoraPublicContactContentDecision {
  const AvoraPublicContactContentDecision({
    required this.action,
    required this.reason,
  });

  final AvoraPublicContactAction action;
  final String reason;
}

class AvoraPublicContactContentGuard {
  const AvoraPublicContactContentGuard();

  AvoraPublicContactContentDecision evaluate(
    AvoraPublicContactContentSignal signal,
  ) {
    if (!signal.isPublicRoom) {
      return const AvoraPublicContactContentDecision(
        action: AvoraPublicContactAction.allow,
        reason: 'private_context_uses_separate_policy',
      );
    }

    if (signal.isOwnerApproved) {
      return const AvoraPublicContactContentDecision(
        action: AvoraPublicContactAction.allow,
        reason: 'owner_approved_public_contact_content',
      );
    }

    if (signal.confidence < 0.60) {
      return const AvoraPublicContactContentDecision(
        action: AvoraPublicContactAction.review,
        reason: 'low_confidence_contact_signal',
      );
    }

    switch (signal.type) {
      case AvoraPublicContactContentType.phoneNumber:
        return const AvoraPublicContactContentDecision(
          action: AvoraPublicContactAction.blur,
          reason: 'public_phone_number_redacted',
        );

      case AvoraPublicContactContentType.externalLink:
        return const AvoraPublicContactContentDecision(
          action: AvoraPublicContactAction.review,
          reason: 'external_link_requires_review',
        );

      case AvoraPublicContactContentType.qrCode:
        return const AvoraPublicContactContentDecision(
          action: AvoraPublicContactAction.blur,
          reason: 'public_qr_code_redacted',
        );

      case AvoraPublicContactContentType.promotionalText:
        return const AvoraPublicContactContentDecision(
          action: AvoraPublicContactAction.review,
          reason: 'promotion_requires_policy_review',
        );

      case AvoraPublicContactContentType.unknown:
        return const AvoraPublicContactContentDecision(
          action: AvoraPublicContactAction.review,
          reason: 'unknown_contact_content_review',
        );
    }
  }

  static bool publicPhoneNumbersMayBeRedacted() => true;

  static bool publicQrCodesMayBeRedacted() => true;

  static bool promotionSignalsMustBeReviewable() => true;

  static bool lowConfidenceSignalMustNotAutoPunish() => true;

  static bool privateMessagingMustUseSeparatePrivacyPolicy() => true;

  static bool ownerMustSeeModerationEvidence() => true;
}
