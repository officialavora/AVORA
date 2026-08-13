import 'avora_gifting.dart';

enum AvoraGiftTargetMode {
  single,
  allSeats,
  allRoom,
}

class AvoraGiftComboConfig {
  final List<int> presets;
  final int maxQuantity;

  const AvoraGiftComboConfig({
    this.presets = const [
      1,
      10,
      20,
      50,
      99,
      100,
      777,
      999,
    ],
    this.maxQuantity = 999,
  });

  bool isQuantityAllowed(int quantity) {
    return quantity >= 1 && quantity <= maxQuantity;
  }
}

class AvoraRoomGiftUser {
  final String userId;

  /// True when currently occupying a mic/seat.
  final bool isSeated;

  /// Server-side eligibility result.
  final bool eligibleForGift;

  const AvoraRoomGiftUser({
    required this.userId,
    required this.isSeated,
    this.eligibleForGift = true,
  });
}

class AvoraGiftTargetingPolicy {
  const AvoraGiftTargetingPolicy._();

  static bool targetModeAllowed({
    required AvoraEconomyContext context,
    required AvoraGiftTargetMode mode,
  }) {
    if (context == AvoraEconomyContext.room) {
      return true;
    }

    /// Inbox/Family/Global/Event do not automatically inherit
    /// room-wide targeting semantics.
    return mode == AvoraGiftTargetMode.single;
  }

  static List<String> resolveRoomRecipients({
    required AvoraGiftTargetMode mode,
    required List<AvoraRoomGiftUser> roomSnapshot,
    required String senderUserId,
    String? singleUserId,
    bool allowSelfGift = true,
  }) {
    bool valid(AvoraRoomGiftUser user) {
      if (!user.eligibleForGift) {
        return false;
      }

      if (!allowSelfGift && user.userId == senderUserId) {
        return false;
      }

      return true;
    }

    Iterable<AvoraRoomGiftUser> selected;

    switch (mode) {
      case AvoraGiftTargetMode.single:
        if (singleUserId == null || singleUserId.trim().isEmpty) {
          return const [];
        }

        selected = roomSnapshot.where(
          (user) => user.userId == singleUserId && valid(user),
        );

      case AvoraGiftTargetMode.allSeats:
        selected = roomSnapshot.where(
          (user) => user.isSeated && valid(user),
        );

      case AvoraGiftTargetMode.allRoom:
        selected = roomSnapshot.where(valid);
    }

    /// Deduplicate users while preserving snapshot order.
    final seen = <String>{};
    final recipients = <String>[];

    for (final user in selected) {
      if (seen.add(user.userId)) {
        recipients.add(user.userId);
      }
    }

    return recipients;
  }

  static int calculateTotalDebit({
    required int unitPrice,
    required int comboQuantity,
    required int recipientCount,
  }) {
    if (unitPrice <= 0 || comboQuantity <= 0 || recipientCount <= 0) {
      return 0;
    }

    return unitPrice * comboQuantity * recipientCount;
  }
}
