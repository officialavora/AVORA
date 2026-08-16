class AvoraRtcRuntimeConfig {
  const AvoraRtcRuntimeConfig._();

  static const String _appIdText =
      String.fromEnvironment('AVORA_ZEGO_APP_ID');
  static const String appSign =
      String.fromEnvironment('AVORA_ZEGO_APP_SIGN');
  static const String tokenEndpoint =
      String.fromEnvironment('AVORA_RTC_TOKEN_ENDPOINT');

  static int get appId => int.tryParse(_appIdText) ?? 0;

  static bool get hasProviderIdentity =>
      appId > 0 && appSign.trim().isNotEmpty;

  static bool get hasProductionTokenService =>
      Uri.tryParse(tokenEndpoint)?.hasAbsolutePath == true;

  static bool get demoVoiceCanStart => hasProviderIdentity;

  static bool get productionVoiceCanStart =>
      hasProviderIdentity && hasProductionTokenService;

  static String get setupStatus {
    if (!hasProviderIdentity) {
      return 'AVORA voice provider is not configured.';
    }
    if (!hasProductionTokenService) {
      return 'Demo voice is configured; production token service is pending.';
    }
    return 'AVORA secure realtime voice is configured.';
  }

  static bool permanentProviderSecretsMustNotBeLogged() => true;
  static bool productionTokensMustComeFromBackend() => true;
}
