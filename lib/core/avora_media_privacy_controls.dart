enum AvoraAudioProcessingMode {
  voice,
  karaoke,
  music,
  lowDevice,
}

enum AvoraBlurStrength {
  off,
  light,
  medium,
  strong,
}

enum AvoraCameraFacing {
  front,
  rear,
}

enum AvoraCaptureProtectionPlatform {
  android,
  ios,
  other,
}

enum AvoraCaptureProtectionAction {
  none,
  secureSurfaceRequested,
  obscureSensitiveVideo,
  pauseSensitiveVideo,
}

class AvoraAudioProcessingPolicy {
  const AvoraAudioProcessingPolicy({
    required this.noiseReductionEnabled,
    required this.echoCancellationEnabled,
    required this.autoGainEnabled,
    required this.mode,
    required this.lowDeviceFallbackEnabled,
  });

  final bool noiseReductionEnabled;
  final bool echoCancellationEnabled;
  final bool autoGainEnabled;

  final AvoraAudioProcessingMode mode;

  final bool lowDeviceFallbackEnabled;

  bool get aggressiveSpeechProcessingAllowed =>
      mode == AvoraAudioProcessingMode.voice;

  bool get preserveMusicDynamics =>
      mode == AvoraAudioProcessingMode.karaoke ||
      mode == AvoraAudioProcessingMode.music;
}

class AvoraAudioProcessingDecision {
  const AvoraAudioProcessingDecision({
    required this.useNoiseReduction,
    required this.useEchoCancellation,
    required this.useAutoGain,
    required this.liteMode,
  });

  final bool useNoiseReduction;
  final bool useEchoCancellation;
  final bool useAutoGain;
  final bool liteMode;
}

class AvoraAudioProcessingEngine {
  const AvoraAudioProcessingEngine._();

  static AvoraAudioProcessingDecision resolve({
    required AvoraAudioProcessingPolicy policy,
    required bool deviceLowCapability,
  }) {
    final lite = deviceLowCapability && policy.lowDeviceFallbackEnabled;

    if (policy.preserveMusicDynamics) {
      return AvoraAudioProcessingDecision(
        useNoiseReduction: false,
        useEchoCancellation: policy.echoCancellationEnabled,
        useAutoGain: false,
        liteMode: lite,
      );
    }

    return AvoraAudioProcessingDecision(
      useNoiseReduction: lite ? false : policy.noiseReductionEnabled,
      useEchoCancellation: policy.echoCancellationEnabled,
      useAutoGain: lite ? false : policy.autoGainEnabled,
      liteMode: lite,
    );
  }

  static bool existingNoiseReductionCapabilityCanBeReused() => true;

  static bool existingEchoCancellationCapabilityCanBeReused() => true;

  static bool karaokeModeShouldAvoidAggressiveSpeechProcessing() => true;
}

class AvoraVideoPrivacyPolicy {
  const AvoraVideoPrivacyPolicy({
    required this.blurEnabled,
    required this.blurStrength,
    required this.personSegmentationEnabled,
    required this.lowDeviceFallbackEnabled,
  });

  final bool blurEnabled;
  final AvoraBlurStrength blurStrength;

  /// Provider/platform implementation remains pluggable.
  final bool personSegmentationEnabled;

  final bool lowDeviceFallbackEnabled;
}

class AvoraVideoPrivacyDecision {
  const AvoraVideoPrivacyDecision({
    required this.applyBlur,
    required this.usePersonSegmentation,
    required this.resolvedStrength,
    required this.liteMode,
  });

  final bool applyBlur;
  final bool usePersonSegmentation;
  final AvoraBlurStrength resolvedStrength;
  final bool liteMode;
}

class AvoraVideoPrivacyEngine {
  const AvoraVideoPrivacyEngine._();

  static AvoraVideoPrivacyDecision resolve({
    required AvoraVideoPrivacyPolicy policy,
    required bool deviceLowCapability,
    required bool segmentationSupported,
  }) {
    if (!policy.blurEnabled || policy.blurStrength == AvoraBlurStrength.off) {
      return const AvoraVideoPrivacyDecision(
        applyBlur: false,
        usePersonSegmentation: false,
        resolvedStrength: AvoraBlurStrength.off,
        liteMode: false,
      );
    }

    final lite = deviceLowCapability && policy.lowDeviceFallbackEnabled;

    final resolvedStrength =
        lite && policy.blurStrength == AvoraBlurStrength.strong
            ? AvoraBlurStrength.light
            : policy.blurStrength;

    return AvoraVideoPrivacyDecision(
      applyBlur: true,
      usePersonSegmentation:
          policy.personSegmentationEnabled && segmentationSupported && !lite,
      resolvedStrength: resolvedStrength,
      liteMode: lite,
    );
  }

  static bool blurIsUserControlledByDefault() => true;

  static bool blurIsIdentityVerificationSignal() => false;

  static bool faceLivenessMustUseSeparateVerificationPipeline() => true;

  static bool onDeviceSegmentationPreferredWhenAvailable() => true;
}

class AvoraCameraLightCapability {
  const AvoraCameraLightCapability({
    required this.facing,
    required this.hardwareTorchSupported,
    required this.screenFaceLightSupported,
  });

  final AvoraCameraFacing facing;
  final bool hardwareTorchSupported;
  final bool screenFaceLightSupported;
}

class AvoraCameraLightState {
  const AvoraCameraLightState({
    required this.torchEnabled,
    required this.faceLightEnabled,
    required this.previousBrightness,
  });

  final bool torchEnabled;
  final bool faceLightEnabled;

  /// Nullable because the host platform may own brightness automatically.
  final double? previousBrightness;
}

class AvoraCameraLightDecision {
  const AvoraCameraLightDecision({
    required this.enableHardwareTorch,
    required this.enableScreenFaceLight,
    required this.restorePreviousBrightnessOnExit,
  });

  final bool enableHardwareTorch;
  final bool enableScreenFaceLight;
  final bool restorePreviousBrightnessOnExit;
}

class AvoraCameraLightEngine {
  const AvoraCameraLightEngine._();

  static AvoraCameraLightDecision enableNightAssist({
    required AvoraCameraLightCapability capability,
  }) {
    if (capability.facing == AvoraCameraFacing.rear &&
        capability.hardwareTorchSupported) {
      return const AvoraCameraLightDecision(
        enableHardwareTorch: true,
        enableScreenFaceLight: false,
        restorePreviousBrightnessOnExit: true,
      );
    }

    if (capability.facing == AvoraCameraFacing.front &&
        capability.screenFaceLightSupported) {
      return const AvoraCameraLightDecision(
        enableHardwareTorch: false,
        enableScreenFaceLight: true,
        restorePreviousBrightnessOnExit: true,
      );
    }

    return const AvoraCameraLightDecision(
      enableHardwareTorch: false,
      enableScreenFaceLight: false,
      restorePreviousBrightnessOnExit: false,
    );
  }

  static bool torchCapabilityMustBeDetectedBeforeUse() => true;

  static bool frontCameraRequiresHardwareTorch() => false;

  static bool brightnessMustBeRestoredAfterCallOrCameraSwitch() => true;
}

class AvoraScreenCaptureProtectionContext {
  const AvoraScreenCaptureProtectionContext({
    required this.platform,
    required this.protectionEnabled,
    required this.captureDetected,
    required this.privateCall,
  });

  final AvoraCaptureProtectionPlatform platform;
  final bool protectionEnabled;
  final bool captureDetected;
  final bool privateCall;
}

class AvoraScreenCaptureProtectionDecision {
  const AvoraScreenCaptureProtectionDecision({
    required this.action,
    required this.showProtectedIndicator,
    required this.showCaptureDetectedIndicator,
  });

  final AvoraCaptureProtectionAction action;
  final bool showProtectedIndicator;
  final bool showCaptureDetectedIndicator;
}

class AvoraScreenCaptureProtectionEngine {
  const AvoraScreenCaptureProtectionEngine._();

  static AvoraScreenCaptureProtectionDecision resolve(
    AvoraScreenCaptureProtectionContext context,
  ) {
    if (!context.protectionEnabled) {
      return const AvoraScreenCaptureProtectionDecision(
        action: AvoraCaptureProtectionAction.none,
        showProtectedIndicator: false,
        showCaptureDetectedIndicator: false,
      );
    }

    switch (context.platform) {
      case AvoraCaptureProtectionPlatform.android:
        return AvoraScreenCaptureProtectionDecision(
          action: AvoraCaptureProtectionAction.secureSurfaceRequested,
          showProtectedIndicator: true,
          showCaptureDetectedIndicator: context.captureDetected,
        );

      case AvoraCaptureProtectionPlatform.ios:
        return AvoraScreenCaptureProtectionDecision(
          action: context.captureDetected
              ? AvoraCaptureProtectionAction.obscureSensitiveVideo
              : AvoraCaptureProtectionAction.none,
          showProtectedIndicator: true,
          showCaptureDetectedIndicator: context.captureDetected,
        );

      case AvoraCaptureProtectionPlatform.other:
        return AvoraScreenCaptureProtectionDecision(
          action: context.captureDetected
              ? AvoraCaptureProtectionAction.obscureSensitiveVideo
              : AvoraCaptureProtectionAction.none,
          showProtectedIndicator: true,
          showCaptureDetectedIndicator: context.captureDetected,
        );
    }
  }

  static bool androidSecureWindowOrSurfaceRequestedWhenEnabled() => true;

  static bool iosCaptureDetectionRequiresObscureOrPauseResponse() => true;

  static bool protectedUiShouldShowStatusIndicator() => true;

  static bool softwareCanGuaranteeBlockingExternalPhysicalCamera() => false;

  static bool captureProtectionReplacesBackgroundBlur() => false;

  static bool captureProtectionReplacesFaceVerification() => false;
}

class AvoraMediaPrivacySafety {
  const AvoraMediaPrivacySafety._();

  static bool clientEffectStateCanGrantBackendAuthority() => false;

  static bool privacyBlurMayModifyImmutableAvoraIdentity() => false;

  static bool mediaEffectsMayEndSessionAutomatically() => false;

  static bool existingSessionContinuityRemainsAuthoritative() => true;
}
