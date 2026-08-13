import 'avora_gifting.dart';

enum AvoraGiftRewardTrack {
  receiver,
  room,
  cp,
  family,
  event,
  festival,
}

class AvoraGiftAttributionContext {
  /// Optional eligible CP/Couple relationship.
  final String? cpId;

  /// Optional eligible family/community.
  final String? familyId;

  /// Optional active event/campaign.
  final String? eventId;

  /// Optional active festival/seasonal campaign.
  final String? festivalId;

  const AvoraGiftAttributionContext({
    this.cpId,
    this.familyId,
    this.eventId,
    this.festivalId,
  });
}

class AvoraGiftAttributionConfig {
  /// 10000 basis points = 100%.

  final int standardReceiverBps;
  final int standardRoomBps;
  final int standardCpBps;
  final int standardFamilyBps;
  final int standardEventBps;
  final int standardFestivalBps;

  final int luckyReceiverBps;
  final int luckyRoomBps;
  final int luckyCpBps;
  final int luckyFamilyBps;
  final int luckyEventBps;
  final int luckyFestivalBps;

  /// Prevent self-gifting from farming receiver progression.
  final bool allowSelfReceiverCredit;

  /// Prevent self-gifting from farming room/CP/family/event rewards.
  final bool allowSelfCommunityCredit;

  const AvoraGiftAttributionConfig({
    this.standardReceiverBps = 10000,
    this.standardRoomBps = 10000,
    this.standardCpBps = 10000,
    this.standardFamilyBps = 10000,
    this.standardEventBps = 10000,
    this.standardFestivalBps = 10000,
    this.luckyReceiverBps = 1000,
    this.luckyRoomBps = 1000,
    this.luckyCpBps = 1000,
    this.luckyFamilyBps = 1000,
    this.luckyEventBps = 1000,
    this.luckyFestivalBps = 1000,
    this.allowSelfReceiverCredit = false,
    this.allowSelfCommunityCredit = false,
  })  : assert(standardReceiverBps >= 0 && standardReceiverBps <= 10000),
        assert(standardRoomBps >= 0 && standardRoomBps <= 10000),
        assert(standardCpBps >= 0 && standardCpBps <= 10000),
        assert(standardFamilyBps >= 0 && standardFamilyBps <= 10000),
        assert(standardEventBps >= 0 && standardEventBps <= 10000),
        assert(standardFestivalBps >= 0 && standardFestivalBps <= 10000),
        assert(luckyReceiverBps >= 0 && luckyReceiverBps <= 10000),
        assert(luckyRoomBps >= 0 && luckyRoomBps <= 10000),
        assert(luckyCpBps >= 0 && luckyCpBps <= 10000),
        assert(luckyFamilyBps >= 0 && luckyFamilyBps <= 10000),
        assert(luckyEventBps >= 0 && luckyEventBps <= 10000),
        assert(luckyFestivalBps >= 0 && luckyFestivalBps <= 10000);

  int bpsFor({
    required AvoraGiftKind kind,
    required AvoraGiftRewardTrack track,
  }) {
    if (kind == AvoraGiftKind.standard) {
      switch (track) {
        case AvoraGiftRewardTrack.receiver:
          return standardReceiverBps;
        case AvoraGiftRewardTrack.room:
          return standardRoomBps;
        case AvoraGiftRewardTrack.cp:
          return standardCpBps;
        case AvoraGiftRewardTrack.family:
          return standardFamilyBps;
        case AvoraGiftRewardTrack.event:
          return standardEventBps;
        case AvoraGiftRewardTrack.festival:
          return standardFestivalBps;
      }
    }

    switch (track) {
      case AvoraGiftRewardTrack.receiver:
        return luckyReceiverBps;
      case AvoraGiftRewardTrack.room:
        return luckyRoomBps;
      case AvoraGiftRewardTrack.cp:
        return luckyCpBps;
      case AvoraGiftRewardTrack.family:
        return luckyFamilyBps;
      case AvoraGiftRewardTrack.event:
        return luckyEventBps;
      case AvoraGiftRewardTrack.festival:
        return luckyFestivalBps;
    }
  }
}

class AvoraGiftAttributionEntry {
  final String transactionId;
  final AvoraGiftRewardTrack track;

  /// User ID, room ID, CP ID, family ID, event ID or festival ID.
  final String subjectId;

  final int creditedAmount;

  final DateTime createdAt;

  const AvoraGiftAttributionEntry({
    required this.transactionId,
    required this.track,
    required this.subjectId,
    required this.creditedAmount,
    required this.createdAt,
  });
}

class AvoraGiftAttributionEngine {
  const AvoraGiftAttributionEngine._();

  static List<AvoraGiftAttributionEntry> build({
    required AvoraGiftTransaction transaction,
    required AvoraGiftAttributionContext attribution,
    AvoraGiftAttributionConfig config = const AvoraGiftAttributionConfig(),
  }) {
    if (!transaction.isConfirmed) {
      return const [];
    }

    final entries = <AvoraGiftAttributionEntry>[];

    void add(
      AvoraGiftRewardTrack track,
      String? subjectId,
    ) {
      if (subjectId == null || subjectId.trim().isEmpty) {
        return;
      }

      final bps = config.bpsFor(
        kind: transaction.kind,
        track: track,
      );

      final amount = (transaction.totalAmount * bps) ~/ 10000;

      if (amount <= 0) {
        return;
      }

      entries.add(
        AvoraGiftAttributionEntry(
          transactionId: transaction.id,
          track: track,
          subjectId: subjectId,
          creditedAmount: amount,
          createdAt: transaction.confirmedAt ?? transaction.createdAt,
        ),
      );
    }

    if (!transaction.isSelfGift || config.allowSelfReceiverCredit) {
      add(
        AvoraGiftRewardTrack.receiver,
        transaction.receiverUserId,
      );
    }

    final communityAllowed =
        !transaction.isSelfGift || config.allowSelfCommunityCredit;

    if (!communityAllowed) {
      return entries;
    }

    if (transaction.context == AvoraEconomyContext.room) {
      add(
        AvoraGiftRewardTrack.room,
        transaction.contextId,
      );
    }

    add(
      AvoraGiftRewardTrack.cp,
      attribution.cpId,
    );

    add(
      AvoraGiftRewardTrack.family,
      attribution.familyId,
    );

    add(
      AvoraGiftRewardTrack.event,
      attribution.eventId,
    );

    add(
      AvoraGiftRewardTrack.festival,
      attribution.festivalId,
    );

    return entries;
  }
}
