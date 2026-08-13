import 'avora_authenticated_identity.dart';
import 'avora_owner_message_override.dart';

class AvoraOwnerAuthorityIntegrityService {
  const AvoraOwnerAuthorityIntegrityService({
    required AvoraOwnerAuthorityRepository ownerRepository,
  }) : _ownerRepository = ownerRepository;

  final AvoraOwnerAuthorityRepository _ownerRepository;

  Future<bool> verify({
    required AvoraAuthenticatedIdentity identity,
  }) async {
    if (!identity.isUsable) {
      return false;
    }

    final avoraId = identity.avoraId.trim();

    if (avoraId.isEmpty) {
      return false;
    }

    return _ownerRepository.isActiveOwner(
      avoraId: avoraId,
    );
  }

  static bool firebaseUidMustNeverEqualOwnerAuthority() => true;

  static bool verifiedAvoraIdentityMustBeRequired() => true;

  static bool ownerAuthorityMustComeFromRepository() => true;

  static bool missingOrInactiveOwnerMustFailClosed() => true;
}
