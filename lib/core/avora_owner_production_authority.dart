import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_authenticated_identity.dart';
import 'avora_owner_authority_integrity.dart';
import 'avora_owner_firestore_authority_repository.dart';

class AvoraOwnerProductionAuthority {
  AvoraOwnerProductionAuthority({
    required FirebaseFirestore firestore,
  }) : _integrityService = AvoraOwnerAuthorityIntegrityService(
          ownerRepository: AvoraFirestoreOwnerAuthorityRepository(
            firestore: firestore,
          ),
        );

  final AvoraOwnerAuthorityIntegrityService _integrityService;

  Future<bool> verifyOwner({
    required AvoraAuthenticatedIdentity identity,
  }) {
    return _integrityService.verify(
      identity: identity,
    );
  }

  static bool productionOwnerAuthorityMustUseFirestore() => true;

  static bool productionOwnerAuthorityMustUseVerifiedIdentity() => true;

  static bool ownerPowerMustNotComeFromClientRoleClaims() => true;

  static bool ownerAuthorityFailureMustFailClosed() => true;
}
