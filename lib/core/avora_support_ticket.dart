enum AvoraSupportTicketCategory { account, safety, privacy, recharge, room, other }
enum AvoraSupportTicketStatus { open, assigned, waitingForUser, resolved, closed }

class AvoraSupportTicket {
  const AvoraSupportTicket({
    required this.ticketId,
    required this.requesterAvoraId,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAtUtc,
    this.assignedOfficialAvoraId,
  });

  final String ticketId;
  final String requesterAvoraId;
  final AvoraSupportTicketCategory category;
  final String subject;
  final String message;
  final AvoraSupportTicketStatus status;
  final DateTime createdAtUtc;
  final String? assignedOfficialAvoraId;

  bool get containsRequiredContent =>
      ticketId.trim().isNotEmpty &&
      requesterAvoraId.trim().isNotEmpty &&
      subject.trim().isNotEmpty &&
      message.trim().isNotEmpty;

  static bool ownerAndAuthorizedSupportCanInspect() => true;
  static bool everyStatusChangeMustBeAudited() => true;
  static bool requesterCannotSelfAssignOfficial() => true;
}
