import 'avora_message_moderation.dart';
import 'avora_message_moderation_providers.dart';
import 'avora_messaging.dart';

class AvoraMessageModerationRunResult {
  final AvoraMessageModerationSignal? signal;
  final AvoraMessageModerationDecision? decision;
  final String? errorCode;

  const AvoraMessageModerationRunResult({
    this.signal,
    this.decision,
    this.errorCode,
  });

  bool get isSuccess => decision != null && errorCode == null;
}

class AvoraMessageModerationRunner {
  final AvoraMessageModerationProviders providers;

  const AvoraMessageModerationRunner({
    required this.providers,
  });

  Future<AvoraMessageModerationRunResult> run({
    required AvoraMessageRecord message,
    int priorViolations = 0,
  }) async {
    final context = switch (message.conversationType) {
      AvoraConversationType.room => AvoraMessageModerationContext.room,
      AvoraConversationType.inbox => AvoraMessageModerationContext.inbox,
    };

    try {
      if (message.type == AvoraMessageType.system) {
        return const AvoraMessageModerationRunResult(
          decision: AvoraMessageModerationDecision(
            action: AvoraMessageModerationAction.allow,
            storeEvidence: false,
            requiresHumanReview: false,
          ),
        );
      }

      late final AvoraMessageContentAnalysisResult analysis;
      late final AvoraMessageContentKind contentKind;

      if (message.type == AvoraMessageType.text) {
        final text = message.text?.trim();

        if (text == null || text.isEmpty) {
          return const AvoraMessageModerationRunResult(
            errorCode: 'missing_text',
          );
        }

        contentKind = AvoraMessageContentKind.text;

        analysis = await providers.text.analyzeText(
          text: text,
          context: context,
        );
      } else {
        final mediaRef = message.mediaRef?.trim();

        if (mediaRef == null || mediaRef.isEmpty) {
          return const AvoraMessageModerationRunResult(
            errorCode: 'missing_media',
          );
        }

        contentKind = message.type == AvoraMessageType.image
            ? AvoraMessageContentKind.image
            : AvoraMessageContentKind.video;

        analysis = await providers.media.analyzeMedia(
          mediaRef: mediaRef,
          contentKind: contentKind,
          context: context,
        );
      }

      final signal = AvoraMessageModerationSignal(
        id: '${message.id}:moderation',
        context: context,
        contentKind: contentKind,
        senderUserId: message.senderUserId,
        conversationId: message.conversationId,
        violation: analysis.violation,
        severity: analysis.severity,
        confidence: analysis.confidence,
        detectedAt: message.sentAt,
        evidenceRef: analysis.evidenceRef,
        detectedPromotionRef: analysis.detectedPromotionRef,
      );

      final decision = AvoraMessageModerationPolicy.decide(
        signal: signal,
        priorViolations: priorViolations,
      );

      return AvoraMessageModerationRunResult(
        signal: signal,
        decision: decision,
      );
    } catch (_) {
      return const AvoraMessageModerationRunResult(
        errorCode: 'provider_error',
      );
    }
  }
}
