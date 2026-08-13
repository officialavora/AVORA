import 'avora_seller_capacity.dart';
import 'avora_seller_order_guard.dart';

enum AvoraTradingReservationStatus {
  reserved,
  completed,
  released,
  expired,
  cancelled,
}

enum AvoraTradingReservationFailure {
  none,
  orderNotAllowed,
  insufficientCapacity,
  alreadyFinalized,
  expired,
}

class AvoraTradingReservation {
  final String id;

  final String orderId;
  final String tradingUserId;

  final AvoraTradingRole role;

  final int reservedUnits;

  final DateTime createdAt;
  final DateTime expiresAt;

  final AvoraTradingReservationStatus status;

  final DateTime? finalizedAt;

  const AvoraTradingReservation({
    required this.id,
    required this.orderId,
    required this.tradingUserId,
    required this.role,
    required this.reservedUnits,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.finalizedAt,
  }) : assert(reservedUnits > 0);

  bool isActiveAt(DateTime time) {
    return status == AvoraTradingReservationStatus.reserved &&
        !time.isAfter(expiresAt);
  }

  AvoraTradingReservation complete(DateTime time) {
    return AvoraTradingReservation(
      id: id,
      orderId: orderId,
      tradingUserId: tradingUserId,
      role: role,
      reservedUnits: reservedUnits,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: AvoraTradingReservationStatus.completed,
      finalizedAt: time,
    );
  }

  AvoraTradingReservation release({
    required DateTime time,
    AvoraTradingReservationStatus releaseStatus =
        AvoraTradingReservationStatus.released,
  }) {
    return AvoraTradingReservation(
      id: id,
      orderId: orderId,
      tradingUserId: tradingUserId,
      role: role,
      reservedUnits: reservedUnits,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: releaseStatus,
      finalizedAt: time,
    );
  }
}

class AvoraTradingReservationDecision {
  final bool reserved;

  final AvoraTradingReservation? reservation;

  final AvoraTradingReservationFailure failure;

  const AvoraTradingReservationDecision({
    required this.reserved,
    required this.reservation,
    required this.failure,
  });
}

class AvoraTradingReservationEngine {
  const AvoraTradingReservationEngine._();

  static AvoraTradingReservationDecision reserve({
    required String reservationId,
    required String orderId,
    required int requestedUnits,
    required AvoraTradingCapacitySnapshot seller,
    required DateTime now,
    Duration reservationDuration = const Duration(minutes: 10),
  }) {
    final guard = AvoraTradingOrderGuard.evaluate(
      requestedUnits: requestedUnits,
      seller: seller,
    );

    if (!guard.allowed) {
      return const AvoraTradingReservationDecision(
        reserved: false,
        reservation: null,
        failure: AvoraTradingReservationFailure.orderNotAllowed,
      );
    }

    if (requestedUnits > seller.availableOrderCapacityUnits) {
      return const AvoraTradingReservationDecision(
        reserved: false,
        reservation: null,
        failure: AvoraTradingReservationFailure.insufficientCapacity,
      );
    }

    final reservation = AvoraTradingReservation(
      id: reservationId,
      orderId: orderId,
      tradingUserId: seller.userId,
      role: seller.role,
      reservedUnits: requestedUnits,
      createdAt: now,
      expiresAt: now.add(reservationDuration),
      status: AvoraTradingReservationStatus.reserved,
    );

    return AvoraTradingReservationDecision(
      reserved: true,
      reservation: reservation,
      failure: AvoraTradingReservationFailure.none,
    );
  }

  static int calculateAvailableAfterReservations({
    required AvoraTradingCapacitySnapshot seller,
    required List<AvoraTradingReservation> reservations,
    required DateTime now,
  }) {
    final activeReserved = reservations
        .where(
          (item) => item.tradingUserId == seller.userId && item.isActiveAt(now),
        )
        .fold<int>(
          0,
          (sum, item) => sum + item.reservedUnits,
        );

    final value = seller.availableOrderCapacityUnits - activeReserved;

    return value > 0 ? value : 0;
  }

  static AvoraTradingReservation expireIfNeeded({
    required AvoraTradingReservation reservation,
    required DateTime now,
  }) {
    if (reservation.status != AvoraTradingReservationStatus.reserved) {
      return reservation;
    }

    if (!now.isAfter(reservation.expiresAt)) {
      return reservation;
    }

    return reservation.release(
      time: now,
      releaseStatus: AvoraTradingReservationStatus.expired,
    );
  }
}
