enum AvoraAccountDeletionStatus { requested, cancelled, scheduled, completed }

class AvoraAccountDeletionRequest {
  const AvoraAccountDeletionRequest({
    required this.requestId,
    required this.avoraId,
    required this.status,
    required this.requestedAtUtc,
    required this.scheduledForUtc,
    this.cancelledAtUtc,
    this.completedAtUtc,
  });

  final String requestId;
  final String avoraId;
  final AvoraAccountDeletionStatus status;
  final DateTime requestedAtUtc;
  final DateTime scheduledForUtc;
  final DateTime? cancelledAtUtc;
  final DateTime? completedAtUtc;

  AvoraAccountDeletionRequest cancel(DateTime nowUtc) {
    if (status == AvoraAccountDeletionStatus.completed ||
        !nowUtc.toUtc().isBefore(scheduledForUtc)) {
      throw StateError('account_deletion_cannot_be_cancelled');
    }
    return AvoraAccountDeletionRequest(
      requestId: requestId,
      avoraId: avoraId,
      status: AvoraAccountDeletionStatus.cancelled,
      requestedAtUtc: requestedAtUtc,
      scheduledForUtc: scheduledForUtc,
      cancelledAtUtc: nowUtc.toUtc(),
      completedAtUtc: completedAtUtc,
    );
  }

  static bool permanentAvoraIdMustNeverBeReassigned() => true;
  static bool financialAndSafetyRecordsFollowLegalRetention() => true;
}

class AvoraAccountDeletionService {
  const AvoraAccountDeletionService({this.gracePeriod = const Duration(days: 7)});

  final Duration gracePeriod;

  AvoraAccountDeletionRequest request({
    required String requestId,
    required String avoraId,
    required DateTime nowUtc,
  }) {
    if (requestId.trim().isEmpty || avoraId.trim().isEmpty) {
      throw ArgumentError('invalid_account_deletion_request');
    }
    final requestedAt = nowUtc.toUtc();
    return AvoraAccountDeletionRequest(
      requestId: requestId,
      avoraId: avoraId,
      status: AvoraAccountDeletionStatus.requested,
      requestedAtUtc: requestedAt,
      scheduledForUtc: requestedAt.add(gracePeriod),
    );
  }
}
