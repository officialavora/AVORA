import 'avora_call_duration.dart';
import 'avora_call_state.dart';

enum AvoraCallingPointRounding {
  /// Example: 90 sec at 10 points/min => 15 points.
  proportionalFloor,

  /// Only fully completed time units earn points.
  completedUnits,

  /// Any started unit earns the full configured unit reward.
  startedUnits,
}

class AvoraCallingPointRule {
  const AvoraCallingPointRule({
    required this.ruleId,
    required this.version,
    required this.active,
    required this.pointsPerUnit,
    this.unitSeconds = 60,
    this.callType,
    this.countryCode = '',
    this.includeHeldTime = false,
    this.includeReconnectingTime = false,
    this.rounding = AvoraCallingPointRounding.proportionalFloor,
    this.maxPointsPerCall,
    required this.effectiveFromUtc,
    this.effectiveUntilUtc,
    required this.configuredByAvoraId,
    required this.reasonCode,
  });

  final String ruleId;

  /// Every admin edit should create a new immutable version.
  final int version;
  final bool active;

  /// Admin-editable reward value.
  final int pointsPerUnit;

  /// Default 60 sec = points per minute.
  /// Can later support other configured time units without app changes.
  final int unitSeconds;

  /// Null means both voice and video.
  final AvoraCallType? callType;

  /// Empty means global.
  final String countryCode;

  /// Waiting/ringing/setup never enter this calculation.
  final bool includeHeldTime;
  final bool includeReconnectingTime;

  final AvoraCallingPointRounding rounding;

  /// Optional anti-abuse/business cap.
  final int? maxPointsPerCall;

  final DateTime effectiveFromUtc;
  final DateTime? effectiveUntilUtc;

  /// Immutable admin/configuration audit snapshots.
  final String configuredByAvoraId;
  final String reasonCode;

  bool get valid {
    if (ruleId.trim().isEmpty ||
        version <= 0 ||
        pointsPerUnit < 0 ||
        unitSeconds <= 0 ||
        configuredByAvoraId.trim().isEmpty ||
        reasonCode.trim().isEmpty) {
      return false;
    }

    final cap = maxPointsPerCall;
    if (cap != null && cap < 0) {
      return false;
    }

    final until = effectiveUntilUtc;
    if (until != null && !until.toUtc().isAfter(effectiveFromUtc.toUtc())) {
      return false;
    }

    return true;
  }

  bool appliesTo({
    required AvoraCallType actualCallType,
    required String actualCountryCode,
    required DateTime atUtc,
  }) {
    if (!valid || !active) {
      return false;
    }

    final at = atUtc.toUtc();
    final from = effectiveFromUtc.toUtc();

    if (at.isBefore(from)) {
      return false;
    }

    final until = effectiveUntilUtc;
    if (until != null && !at.isBefore(until.toUtc())) {
      return false;
    }

    if (callType != null && callType != actualCallType) {
      return false;
    }

    final configuredCountry = countryCode.trim().toUpperCase();
    final actualCountry = actualCountryCode.trim().toUpperCase();

    if (configuredCountry.isNotEmpty && configuredCountry != actualCountry) {
      return false;
    }

    return true;
  }

  int specificityScore({
    required AvoraCallType actualCallType,
    required String actualCountryCode,
  }) {
    var score = 0;

    if (callType == actualCallType) {
      score += 2;
    }

    final configuredCountry = countryCode.trim().toUpperCase();
    final actualCountry = actualCountryCode.trim().toUpperCase();

    if (configuredCountry.isNotEmpty && configuredCountry == actualCountry) {
      score += 1;
    }

    return score;
  }
}

class AvoraCallingPointResult {
  const AvoraCallingPointResult({
    required this.callId,
    required this.callerAvoraId,
    required this.calleeAvoraId,
    required this.ruleMatched,
    required this.ruleId,
    required this.ruleVersion,
    required this.pointsPerUnit,
    required this.unitSeconds,
    required this.eligibleDuration,
    required this.points,
    required this.capped,
    required this.includeHeldTime,
    required this.includeReconnectingTime,
    required this.rounding,
  });

  final String callId;
  final String callerAvoraId;
  final String calleeAvoraId;

  final bool ruleMatched;

  /// Immutable pricing/reward rule snapshot for later audit.
  final String ruleId;
  final int ruleVersion;
  final int pointsPerUnit;
  final int unitSeconds;

  final Duration eligibleDuration;
  final int points;
  final bool capped;

  final bool includeHeldTime;
  final bool includeReconnectingTime;
  final AvoraCallingPointRounding rounding;
}

class AvoraCallingPointEngine {
  const AvoraCallingPointEngine._();

  static AvoraCallingPointRule? resolveRule({
    required List<AvoraCallingPointRule> rules,
    required AvoraCallType callType,
    required String countryCode,
    required DateTime atUtc,
  }) {
    final candidates = rules
        .where(
          (rule) => rule.appliesTo(
            actualCallType: callType,
            actualCountryCode: countryCode,
            atUtc: atUtc,
          ),
        )
        .toList(growable: false);

    if (candidates.isEmpty) {
      return null;
    }

    final sorted = [...candidates];

    sorted.sort((left, right) {
      final rightScore = right.specificityScore(
        actualCallType: callType,
        actualCountryCode: countryCode,
      );

      final leftScore = left.specificityScore(
        actualCallType: callType,
        actualCountryCode: countryCode,
      );

      final scoreCompare = rightScore.compareTo(leftScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }

      final effectiveCompare = right.effectiveFromUtc
          .toUtc()
          .compareTo(left.effectiveFromUtc.toUtc());

      if (effectiveCompare != 0) {
        return effectiveCompare;
      }

      final versionCompare = right.version.compareTo(left.version);
      if (versionCompare != 0) {
        return versionCompare;
      }

      return right.ruleId.compareTo(left.ruleId);
    });

    return sorted.first;
  }

  static AvoraCallingPointResult calculate({
    required AvoraCallDurationSnapshot duration,
    required AvoraCallType callType,
    required String countryCode,
    required List<AvoraCallingPointRule> rules,
    required DateTime evaluatedAtUtc,
  }) {
    final rule = resolveRule(
      rules: rules,
      callType: callType,
      countryCode: countryCode,
      atUtc: evaluatedAtUtc,
    );

    if (rule == null) {
      return AvoraCallingPointResult(
        callId: duration.callId,
        callerAvoraId: duration.callerAvoraId,
        calleeAvoraId: duration.calleeAvoraId,
        ruleMatched: false,
        ruleId: '',
        ruleVersion: 0,
        pointsPerUnit: 0,
        unitSeconds: 60,
        eligibleDuration: Duration.zero,
        points: 0,
        capped: false,
        includeHeldTime: false,
        includeReconnectingTime: false,
        rounding: AvoraCallingPointRounding.proportionalFloor,
      );
    }

    var eligible = duration.activeDuration;

    if (rule.includeHeldTime) {
      eligible += duration.heldDuration;
    }

    if (rule.includeReconnectingTime) {
      eligible += duration.reconnectingDuration;
    }

    // setupDuration and waitingDuration are intentionally impossible
    // to add here. Busy calls have zero connected duration.
    final unitMicros = Duration(seconds: rule.unitSeconds).inMicroseconds;

    final eligibleMicros = eligible.inMicroseconds;

    int calculated;

    switch (rule.rounding) {
      case AvoraCallingPointRounding.proportionalFloor:
        calculated = eligibleMicros * rule.pointsPerUnit ~/ unitMicros;

      case AvoraCallingPointRounding.completedUnits:
        final completedUnits = eligibleMicros ~/ unitMicros;
        calculated = completedUnits * rule.pointsPerUnit;

      case AvoraCallingPointRounding.startedUnits:
        if (eligibleMicros <= 0) {
          calculated = 0;
        } else {
          final startedUnits = (eligibleMicros + unitMicros - 1) ~/ unitMicros;

          calculated = startedUnits * rule.pointsPerUnit;
        }
    }

    var capped = false;
    final cap = rule.maxPointsPerCall;

    if (cap != null && calculated > cap) {
      calculated = cap;
      capped = true;
    }

    return AvoraCallingPointResult(
      callId: duration.callId,
      callerAvoraId: duration.callerAvoraId,
      calleeAvoraId: duration.calleeAvoraId,
      ruleMatched: true,
      ruleId: rule.ruleId.trim(),
      ruleVersion: rule.version,
      pointsPerUnit: rule.pointsPerUnit,
      unitSeconds: rule.unitSeconds,
      eligibleDuration: eligible,
      points: calculated,
      capped: capped,
      includeHeldTime: rule.includeHeldTime,
      includeReconnectingTime: rule.includeReconnectingTime,
      rounding: rule.rounding,
    );
  }

  /// Admin changes create new rule versions; old call results keep their
  /// historical rule snapshot.
  static bool historicalCallPointsCanBeRetroactivelyRepriced() => false;

  static bool waitingTimeCanEarnCallingPoints() => false;

  static bool ringingTimeCanEarnCallingPoints() => false;

  static bool busyTimeCanEarnCallingPoints() => false;

  static bool clientReportedDurationIsAuthoritative() => false;
}
