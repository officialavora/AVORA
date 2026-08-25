enum AvoraPolicyDocumentType {
  termsOfService,
  privacyPolicy,
  communityRules,
  childSafety,
  rechargePolicy,
}

class AvoraPolicyDocumentVersion {
  const AvoraPolicyDocumentVersion({
    required this.type,
    required this.version,
    required this.effectiveAtUtc,
    required this.requiredForSignup,
  });

  final AvoraPolicyDocumentType type;
  final String version;
  final DateTime effectiveAtUtc;
  final bool requiredForSignup;
}

class AvoraPolicyAcceptance {
  const AvoraPolicyAcceptance({
    required this.avoraId,
    required this.documentType,
    required this.documentVersion,
    required this.acceptedAtUtc,
  });

  final String avoraId;
  final AvoraPolicyDocumentType documentType;
  final String documentVersion;
  final DateTime acceptedAtUtc;
}

class AvoraCommunityRule {
  const AvoraCommunityRule({
    required this.code,
    required this.title,
    required this.summary,
  });

  final String code;
  final String title;
  final String summary;
}

class AvoraCommunityRules {
  const AvoraCommunityRules._();

  static final DateTime effectiveAtUtc = DateTime.utc(2026, 8, 25);

  static const List<AvoraCommunityRule> current = <AvoraCommunityRule>[
    AvoraCommunityRule(
      code: 'respect',
      title: 'Respect and safety',
      summary: 'Abuse, hate, harassment, threats and obscene content are prohibited.',
    ),
    AvoraCommunityRule(
      code: 'child_safety',
      title: 'Child safety',
      summary: 'Child exploitation, grooming and CSAM are strictly prohibited.',
    ),
    AvoraCommunityRule(
      code: 'identity',
      title: 'Authentic identity',
      summary: 'Impersonation, deceptive identity and account fraud are prohibited.',
    ),
    AvoraCommunityRule(
      code: 'commerce',
      title: 'Authorized commerce',
      summary: 'Fake recharge, wallet fraud and unauthorized selling are prohibited.',
    ),
    AvoraCommunityRule(
      code: 'privacy',
      title: 'Privacy',
      summary: 'Do not expose private information or record others unlawfully.',
    ),
    AvoraCommunityRule(
      code: 'platform_integrity',
      title: 'Platform integrity',
      summary: 'Scams, manipulation, ban evasion and promotion of harmful services are prohibited.',
    ),
  ];

  static final List<AvoraPolicyDocumentVersion> requiredSignupDocuments =
      <AvoraPolicyDocumentVersion>[
    AvoraPolicyDocumentVersion(
      type: AvoraPolicyDocumentType.termsOfService,
      version: '2026-08-25',
      effectiveAtUtc: effectiveAtUtc,
      requiredForSignup: true,
    ),
    AvoraPolicyDocumentVersion(
      type: AvoraPolicyDocumentType.privacyPolicy,
      version: '2026-08-25',
      effectiveAtUtc: effectiveAtUtc,
      requiredForSignup: true,
    ),
    AvoraPolicyDocumentVersion(
      type: AvoraPolicyDocumentType.communityRules,
      version: '2026-08-25',
      effectiveAtUtc: effectiveAtUtc,
      requiredForSignup: true,
    ),
    AvoraPolicyDocumentVersion(
      type: AvoraPolicyDocumentType.childSafety,
      version: '2026-08-25',
      effectiveAtUtc: effectiveAtUtc,
      requiredForSignup: true,
    ),
  ];

  static bool hasAcceptedEveryRequiredDocument({
    required Iterable<AvoraPolicyAcceptance> acceptances,
  }) {
    final accepted = <String>{
      for (final item in acceptances)
        '${item.documentType.name}:${item.documentVersion}',
    };

    return requiredSignupDocuments.every(
      (document) => accepted.contains('${document.type.name}:${document.version}'),
    );
  }

  static bool acceptanceMustBeVersioned() => true;
  static bool policyUpdatesMustNotRewriteHistoricalAcceptance() => true;
  static bool enforcementMustReferenceRuleCode() => true;
}
