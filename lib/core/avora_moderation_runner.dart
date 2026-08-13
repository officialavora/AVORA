import 'avora_moderation_pipeline.dart';
import 'avora_moderation_providers.dart';

class AvoraModerationRunner {
  final AvoraModerationProviders providers;

  const AvoraModerationRunner({
    required this.providers,
  });

  Future<AvoraModerationPipelineResult> run({
    required AvoraModerationInput input,
    int priorViolations = 0,
  }) async {
    final plan = AvoraModerationPipelinePlanner.plan(input);

    if (!plan.validInput) {
      return AvoraModerationPipelineResult(
        stage: AvoraModerationPipelineStage.failed,
        input: input,
        errorCode: plan.errorCode,
      );
    }

    try {
      if (input.isText) {
        final analysis = await providers.text.analyzeText(
          text: input.text!,
          languageCode: plan.languageCode,
        );

        return AvoraModerationPipelineFinalizer.complete(
          input: input,
          analysis: analysis,
          priorViolations: priorViolations,
        );
      }

      final transcription = await providers.transcription.transcribe(
        audioRef: input.audioRef!,
        languageHint: input.languageHint,
      );

      final analysis = await providers.audio.analyzeTranscript(
        transcript: transcription.text,
        languageCode: transcription.languageCode,
        source: input.source,
      );

      return AvoraModerationPipelineFinalizer.complete(
        input: input,
        transcription: transcription,
        analysis: analysis,
        priorViolations: priorViolations,
      );
    } catch (_) {
      return AvoraModerationPipelineResult(
        stage: AvoraModerationPipelineStage.failed,
        input: input,
        errorCode: 'provider_error',
      );
    }
  }
}
