enum AvoraFutureModuleAuditRequirement {
  ownerVisibility,
  ownerOperationalAccess,
  immutableAudit,
  sensitiveAccessAudit,
  searchableHistory,
  serverAuthority,
}

class AvoraFutureModuleAuditContract {
  const AvoraFutureModuleAuditContract._();

  static Set<AvoraFutureModuleAuditRequirement> requiredForEveryModule() {
    return const <AvoraFutureModuleAuditRequirement>{
      AvoraFutureModuleAuditRequirement.ownerVisibility,
      AvoraFutureModuleAuditRequirement.ownerOperationalAccess,
      AvoraFutureModuleAuditRequirement.immutableAudit,
      AvoraFutureModuleAuditRequirement.sensitiveAccessAudit,
      AvoraFutureModuleAuditRequirement.searchableHistory,
      AvoraFutureModuleAuditRequirement.serverAuthority,
    };
  }

  static bool everyFutureModuleMustRegisterAutomatically() => true;

  static bool missingOwnerAuditIntegrationMustFailReview() => true;

  static bool futureEconomyEventsMustBeAuditable() => true;

  static bool futureRolePolicyEventsMustBeAuditable() => true;

  static bool futureRoomLiveCallGameEventsMustBeAuditable() => true;

  static bool rawSecretsRemainExcludedFromVisibility() => true;
}
