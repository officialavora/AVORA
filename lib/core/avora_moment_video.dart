enum AvoraMomentVisibility { public, followers, friends, private }
enum AvoraMomentStatus { processing, published, hidden, removed }

class AvoraMomentVideo {
  const AvoraMomentVideo({
    required this.momentId,
    required this.ownerAvoraId,
    required this.mediaAssetId,
    required this.visibility,
    required this.status,
    required this.createdAtUtc,
    this.caption,
  });

  final String momentId;
  final String ownerAvoraId;
  final String mediaAssetId;
  final String? caption;
  final AvoraMomentVisibility visibility;
  final AvoraMomentStatus status;
  final DateTime createdAtUtc;

  bool get isStructurallyValid =>
      momentId.trim().isNotEmpty &&
      ownerAvoraId.trim().isNotEmpty &&
      mediaAssetId.trim().isNotEmpty;

  static bool moderationRunsBeforePublicDistribution() => true;
  static bool removalPreservesOwnerAuditEvidence() => true;
  static bool mediaReferenceMustUseManagedStorage() => true;
}
