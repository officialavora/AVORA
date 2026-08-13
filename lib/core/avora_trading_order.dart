import 'avora_trading_reservation.dart';

enum AvoraTradingOrderStatus {
  awaitingPayment,
  paymentSubmitted,
  paymentVerified,
  completed,
  cancelled,
  expired,
  failed,
}

enum AvoraTradingOrderFailure {
  none,
  invalidReservation,
  reservationExpired,
  invalidTransition,
  paymentWindowExpired,
  invalidPaymentReference,
  paymentNotVerified,
}

class AvoraTradingOrder {
  final String id;
  final String buyerUserId;

  final AvoraTradingReservation reservation;

  final int requestedUnits;

  final AvoraTradingOrderStatus status;

  final DateTime createdAt;

  /// Buyer must submit payment before this time.
  final DateTime paymentDeadline;

  /// Provider/order transaction reference.
  final String? paymentReference;

  final DateTime? paymentSubmittedAt;
  final DateTime? paymentVerifiedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const AvoraTradingOrder({
    required this.id,
    required this.buyerUserId,
    required this.reservation,
    required this.requestedUnits,
    required this.status,
    required this.createdAt,
    required this.paymentDeadline,
    this.paymentReference,
    this.paymentSubmittedAt,
    this.paymentVerifiedAt,
    this.completedAt,
    this.cancelledAt,
  }) : assert(requestedUnits > 0);

  bool isPaymentWindowOpenAt(DateTime time) {
    return !time.isAfter(paymentDeadline);
  }

  bool get isFinal =>
      status == AvoraTradingOrderStatus.completed ||
      status == AvoraTradingOrderStatus.cancelled ||
      status == AvoraTradingOrderStatus.expired ||
      status == AvoraTradingOrderStatus.failed;
}

class AvoraTradingOrderResult {
  final AvoraTradingOrder? order;

  final AvoraTradingReservation? reservation;

  final AvoraTradingOrderFailure failure;

  const AvoraTradingOrderResult({
    required this.order,
    required this.reservation,
    required this.failure,
  });

  bool get success => failure == AvoraTradingOrderFailure.none;
}

class AvoraTradingOrderEngine {
  const AvoraTradingOrderEngine._();

  static AvoraTradingOrderResult create({
    required String orderId,
    required String buyerUserId,
    required AvoraTradingReservation reservation,
    required DateTime now,
    Duration paymentWindow = const Duration(minutes: 8),
  }) {
    if (reservation.status != AvoraTradingReservationStatus.reserved) {
      return const AvoraTradingOrderResult(
        order: null,
        reservation: null,
        failure: AvoraTradingOrderFailure.invalidReservation,
      );
    }

    if (!reservation.isActiveAt(now)) {
      return const AvoraTradingOrderResult(
        order: null,
        reservation: null,
        failure: AvoraTradingOrderFailure.reservationExpired,
      );
    }

    final requestedDeadline = now.add(paymentWindow);

    /// Payment deadline must never outlive
    /// the underlying inventory reservation.
    final deadline = requestedDeadline.isBefore(reservation.expiresAt)
        ? requestedDeadline
        : reservation.expiresAt;

    final order = AvoraTradingOrder(
      id: orderId,
      buyerUserId: buyerUserId,
      reservation: reservation,
      requestedUnits: reservation.reservedUnits,
      status: AvoraTradingOrderStatus.awaitingPayment,
      createdAt: now,
      paymentDeadline: deadline,
    );

    return AvoraTradingOrderResult(
      order: order,
      reservation: reservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrderResult submitPayment({
    required AvoraTradingOrder order,
    required String paymentReference,
    required DateTime now,
  }) {
    if (order.status != AvoraTradingOrderStatus.awaitingPayment) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.invalidTransition,
      );
    }

    if (!order.isPaymentWindowOpenAt(now)) {
      final released = order.reservation.release(
        time: now,
        releaseStatus: AvoraTradingReservationStatus.expired,
      );

      final expiredOrder = _copy(
        order,
        reservation: released,
        status: AvoraTradingOrderStatus.expired,
      );

      return AvoraTradingOrderResult(
        order: expiredOrder,
        reservation: released,
        failure: AvoraTradingOrderFailure.paymentWindowExpired,
      );
    }

    final reference = paymentReference.trim();

    if (reference.isEmpty) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.invalidPaymentReference,
      );
    }

    final updated = _copy(
      order,
      status: AvoraTradingOrderStatus.paymentSubmitted,
      paymentReference: reference,
      paymentSubmittedAt: now,
    );

    return AvoraTradingOrderResult(
      order: updated,
      reservation: order.reservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrderResult verifyPayment({
    required AvoraTradingOrder order,

    /// Must be supplied by trusted backend/provider verification.
    required bool providerPaymentVerified,
    required DateTime now,
  }) {
    if (order.status != AvoraTradingOrderStatus.paymentSubmitted) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.invalidTransition,
      );
    }

    if (!providerPaymentVerified) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.paymentNotVerified,
      );
    }

    final updated = _copy(
      order,
      status: AvoraTradingOrderStatus.paymentVerified,
      paymentVerifiedAt: now,
    );

    return AvoraTradingOrderResult(
      order: updated,
      reservation: order.reservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrderResult complete({
    required AvoraTradingOrder order,
    required DateTime now,
  }) {
    if (order.status != AvoraTradingOrderStatus.paymentVerified) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.invalidTransition,
      );
    }

    final completedReservation = order.reservation.complete(now);

    final completedOrder = _copy(
      order,
      reservation: completedReservation,
      status: AvoraTradingOrderStatus.completed,
      completedAt: now,
    );

    return AvoraTradingOrderResult(
      order: completedOrder,
      reservation: completedReservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrderResult cancel({
    required AvoraTradingOrder order,
    required DateTime now,
  }) {
    if (order.isFinal) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.invalidTransition,
      );
    }

    final releasedReservation = order.reservation.release(
      time: now,
      releaseStatus: AvoraTradingReservationStatus.cancelled,
    );

    final cancelledOrder = _copy(
      order,
      reservation: releasedReservation,
      status: AvoraTradingOrderStatus.cancelled,
      cancelledAt: now,
    );

    return AvoraTradingOrderResult(
      order: cancelledOrder,
      reservation: releasedReservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrderResult expireIfNeeded({
    required AvoraTradingOrder order,
    required DateTime now,
  }) {
    /// A submitted payment is not auto-released here.
    /// It must first be resolved by payment verification/review.
    if (order.status != AvoraTradingOrderStatus.awaitingPayment) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.none,
      );
    }

    if (order.isPaymentWindowOpenAt(now)) {
      return AvoraTradingOrderResult(
        order: order,
        reservation: order.reservation,
        failure: AvoraTradingOrderFailure.none,
      );
    }

    final releasedReservation = order.reservation.release(
      time: now,
      releaseStatus: AvoraTradingReservationStatus.expired,
    );

    final expiredOrder = _copy(
      order,
      reservation: releasedReservation,
      status: AvoraTradingOrderStatus.expired,
    );

    return AvoraTradingOrderResult(
      order: expiredOrder,
      reservation: releasedReservation,
      failure: AvoraTradingOrderFailure.none,
    );
  }

  static AvoraTradingOrder _copy(
    AvoraTradingOrder order, {
    AvoraTradingReservation? reservation,
    AvoraTradingOrderStatus? status,
    String? paymentReference,
    DateTime? paymentSubmittedAt,
    DateTime? paymentVerifiedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return AvoraTradingOrder(
      id: order.id,
      buyerUserId: order.buyerUserId,
      reservation: reservation ?? order.reservation,
      requestedUnits: order.requestedUnits,
      status: status ?? order.status,
      createdAt: order.createdAt,
      paymentDeadline: order.paymentDeadline,
      paymentReference: paymentReference ?? order.paymentReference,
      paymentSubmittedAt: paymentSubmittedAt ?? order.paymentSubmittedAt,
      paymentVerifiedAt: paymentVerifiedAt ?? order.paymentVerifiedAt,
      completedAt: completedAt ?? order.completedAt,
      cancelledAt: cancelledAt ?? order.cancelledAt,
    );
  }
}
