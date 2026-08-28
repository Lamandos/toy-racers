import '../math/float32.dart';

/// Tunable waypoint-following, avoidance, and recovery behavior for one AI.
final class AiConfig {
  AiConfig({
    double waypointRadius = 3,
    double fullSteeringAngleDegrees = 60,
    double straightSpeed = 13,
    double cornerSpeed = 6,
    double brakingMargin = 2,
    double stuckSpeed = 1,
    double stuckDurationSeconds = 2,
    double recoveryDurationSeconds = 1.25,
    double steeringResponse = 60,
    this.lookAheadPoints = 1,
    double obstacleDetectionDistance = 7,
    double obstacleLaneHalfWidth = 1.4,
    double staticObstacleReactionDistance = 5,
    double avoidanceSteering = 0.7,
    double overtakeSpeedAdvantage = 1.5,
    double overtakeLaneOffset = 2,
    double overtakeLaneHalfWidth = 0.8,
    double overtakeMinimumClearance = 3,
    double wrongWayAngleDegrees = 110,
    double wrongWayDurationSeconds = 1.25,
    double offTrackDurationSeconds = 4,
    double sensorRayAngleDegrees = 32,
    double sensorRayStep = 0.35,
    double racingLineBiasDistance = 0.45,
    double obstacleSpeedReduction = 0.65,
    double mistakeCheckIntervalSeconds = 1,
    double mistakeProbability = 0.08,
    double mistakeDurationSeconds = 0.25,
    double mistakeSteering = 0.18,
    double routeTurnPriority = 0.25,
  }) : waypointRadius = Float32.narrow(waypointRadius),
       fullSteeringAngleDegrees = Float32.narrow(fullSteeringAngleDegrees),
       straightSpeed = Float32.narrow(straightSpeed),
       cornerSpeed = Float32.narrow(cornerSpeed),
       brakingMargin = Float32.narrow(brakingMargin),
       stuckSpeed = Float32.narrow(stuckSpeed),
       stuckDurationSeconds = Float32.narrow(stuckDurationSeconds),
       recoveryDurationSeconds = Float32.narrow(recoveryDurationSeconds),
       steeringResponse = Float32.narrow(steeringResponse),
       obstacleDetectionDistance = Float32.narrow(obstacleDetectionDistance),
       obstacleLaneHalfWidth = Float32.narrow(obstacleLaneHalfWidth),
       staticObstacleReactionDistance = Float32.narrow(
         staticObstacleReactionDistance,
       ),
       avoidanceSteering = Float32.narrow(avoidanceSteering),
       overtakeSpeedAdvantage = Float32.narrow(overtakeSpeedAdvantage),
       overtakeLaneOffset = Float32.narrow(overtakeLaneOffset),
       overtakeLaneHalfWidth = Float32.narrow(overtakeLaneHalfWidth),
       overtakeMinimumClearance = Float32.narrow(overtakeMinimumClearance),
       wrongWayAngleDegrees = Float32.narrow(wrongWayAngleDegrees),
       wrongWayDurationSeconds = Float32.narrow(wrongWayDurationSeconds),
       offTrackDurationSeconds = Float32.narrow(offTrackDurationSeconds),
       sensorRayAngleDegrees = Float32.narrow(sensorRayAngleDegrees),
       sensorRayStep = Float32.narrow(sensorRayStep),
       racingLineBiasDistance = Float32.narrow(racingLineBiasDistance),
       obstacleSpeedReduction = Float32.narrow(obstacleSpeedReduction),
       mistakeCheckIntervalSeconds = Float32.narrow(
         mistakeCheckIntervalSeconds,
       ),
       mistakeProbability = Float32.narrow(mistakeProbability),
       mistakeDurationSeconds = Float32.narrow(mistakeDurationSeconds),
       mistakeSteering = Float32.narrow(mistakeSteering),
       routeTurnPriority = Float32.narrow(routeTurnPriority) {
    _validate();
  }

  final double waypointRadius;
  final double fullSteeringAngleDegrees;
  final double straightSpeed;
  final double cornerSpeed;
  final double brakingMargin;
  final double stuckSpeed;
  final double stuckDurationSeconds;
  final double recoveryDurationSeconds;
  final double steeringResponse;
  final int lookAheadPoints;
  final double obstacleDetectionDistance;
  final double obstacleLaneHalfWidth;
  final double staticObstacleReactionDistance;
  final double avoidanceSteering;
  final double overtakeSpeedAdvantage;
  final double overtakeLaneOffset;
  final double overtakeLaneHalfWidth;
  final double overtakeMinimumClearance;
  final double wrongWayAngleDegrees;
  final double wrongWayDurationSeconds;
  final double offTrackDurationSeconds;
  final double sensorRayAngleDegrees;
  final double sensorRayStep;
  final double racingLineBiasDistance;
  final double obstacleSpeedReduction;
  final double mistakeCheckIntervalSeconds;
  final double mistakeProbability;
  final double mistakeDurationSeconds;
  final double mistakeSteering;
  final double routeTurnPriority;

  /// Derives the reference difficulty profile without sharing mutable state.
  AiConfig forDifficulty(AiDifficulty difficulty) => switch (difficulty) {
    AiDifficulty.easy => _easyConfig(),
    AiDifficulty.normal => this,
    AiDifficulty.hard => _hardConfig(),
  };

  AiConfig _easyConfig() {
    final adjustedStraightSpeed = Float32.multiply(straightSpeed, 0.78);
    final adjustedDetectionDistance = _maximum(
      Float32.multiply(obstacleDetectionDistance, 0.75),
      sensorRayStep,
    );
    return _copy(
      straightSpeed: adjustedStraightSpeed,
      cornerSpeed: _minimum(
        Float32.multiply(cornerSpeed, 0.85),
        adjustedStraightSpeed,
      ),
      steeringResponse: Float32.multiply(steeringResponse, 0.65),
      obstacleDetectionDistance: adjustedDetectionDistance,
      staticObstacleReactionDistance: _clamp(
        Float32.multiply(staticObstacleReactionDistance, 0.75),
        sensorRayStep,
        adjustedDetectionDistance,
      ),
      avoidanceSteering: Float32.multiply(avoidanceSteering, 0.75),
      overtakeMinimumClearance: Float32.multiply(
        overtakeMinimumClearance,
        0.75,
      ),
      mistakeProbability: 0.18,
      mistakeDurationSeconds: 0.4,
      mistakeSteering: 0.28,
    );
  }

  AiConfig _hardConfig() {
    final adjustedStraightSpeed = Float32.multiply(straightSpeed, 1.08);
    return _copy(
      straightSpeed: adjustedStraightSpeed,
      cornerSpeed: _minimum(
        Float32.multiply(cornerSpeed, 1.12),
        adjustedStraightSpeed,
      ),
      steeringResponse: Float32.multiply(steeringResponse, 1.25),
      obstacleDetectionDistance: Float32.multiply(
        obstacleDetectionDistance,
        1.2,
      ),
      staticObstacleReactionDistance: Float32.multiply(
        staticObstacleReactionDistance,
        1.2,
      ),
      overtakeSpeedAdvantage: Float32.multiply(overtakeSpeedAdvantage, 0.75),
      overtakeMinimumClearance: Float32.multiply(overtakeMinimumClearance, 1.2),
      mistakeProbability: 0.02,
      mistakeDurationSeconds: 0.12,
      mistakeSteering: 0.08,
    );
  }

  AiConfig _copy({
    double? straightSpeed,
    double? cornerSpeed,
    double? steeringResponse,
    double? obstacleDetectionDistance,
    double? staticObstacleReactionDistance,
    double? avoidanceSteering,
    double? overtakeSpeedAdvantage,
    double? overtakeMinimumClearance,
    double? mistakeProbability,
    double? mistakeDurationSeconds,
    double? mistakeSteering,
  }) => AiConfig(
    waypointRadius: waypointRadius,
    fullSteeringAngleDegrees: fullSteeringAngleDegrees,
    straightSpeed: straightSpeed ?? this.straightSpeed,
    cornerSpeed: cornerSpeed ?? this.cornerSpeed,
    brakingMargin: brakingMargin,
    stuckSpeed: stuckSpeed,
    stuckDurationSeconds: stuckDurationSeconds,
    recoveryDurationSeconds: recoveryDurationSeconds,
    steeringResponse: steeringResponse ?? this.steeringResponse,
    lookAheadPoints: lookAheadPoints,
    obstacleDetectionDistance:
        obstacleDetectionDistance ?? this.obstacleDetectionDistance,
    obstacleLaneHalfWidth: obstacleLaneHalfWidth,
    staticObstacleReactionDistance:
        staticObstacleReactionDistance ?? this.staticObstacleReactionDistance,
    avoidanceSteering: avoidanceSteering ?? this.avoidanceSteering,
    overtakeSpeedAdvantage:
        overtakeSpeedAdvantage ?? this.overtakeSpeedAdvantage,
    overtakeLaneOffset: overtakeLaneOffset,
    overtakeLaneHalfWidth: overtakeLaneHalfWidth,
    overtakeMinimumClearance:
        overtakeMinimumClearance ?? this.overtakeMinimumClearance,
    wrongWayAngleDegrees: wrongWayAngleDegrees,
    wrongWayDurationSeconds: wrongWayDurationSeconds,
    offTrackDurationSeconds: offTrackDurationSeconds,
    sensorRayAngleDegrees: sensorRayAngleDegrees,
    sensorRayStep: sensorRayStep,
    racingLineBiasDistance: racingLineBiasDistance,
    obstacleSpeedReduction: obstacleSpeedReduction,
    mistakeCheckIntervalSeconds: mistakeCheckIntervalSeconds,
    mistakeProbability: mistakeProbability ?? this.mistakeProbability,
    mistakeDurationSeconds:
        mistakeDurationSeconds ?? this.mistakeDurationSeconds,
    mistakeSteering: mistakeSteering ?? this.mistakeSteering,
    routeTurnPriority: routeTurnPriority,
  );

  void _validate() {
    if (waypointRadius <= 0 || fullSteeringAngleDegrees <= 0) {
      throw ArgumentError(
        'Waypoint radius and steering angle must be positive.',
      );
    }
    if (straightSpeed <= 0 || cornerSpeed <= 0 || cornerSpeed > straightSpeed) {
      throw ArgumentError(
        'Corner speed must be positive and not exceed straight speed.',
      );
    }
    if (brakingMargin < 0 || stuckSpeed < 0 || lookAheadPoints <= 0) {
      throw ArgumentError('AI speed margins and look-ahead must be valid.');
    }
    if (stuckDurationSeconds <= 0 ||
        recoveryDurationSeconds <= 0 ||
        steeringResponse <= 0 ||
        obstacleDetectionDistance <= 0 ||
        obstacleLaneHalfWidth <= 0 ||
        overtakeLaneOffset <= 0 ||
        overtakeLaneHalfWidth <= 0 ||
        wrongWayDurationSeconds <= 0 ||
        offTrackDurationSeconds <= 0 ||
        sensorRayStep <= 0 ||
        mistakeCheckIntervalSeconds <= 0) {
      throw ArgumentError(
        'AI durations, distances, and response values must be positive.',
      );
    }
    if (staticObstacleReactionDistance < sensorRayStep ||
        staticObstacleReactionDistance > obstacleDetectionDistance ||
        overtakeSpeedAdvantage < 0 ||
        overtakeMinimumClearance < 0 ||
        overtakeMinimumClearance > obstacleDetectionDistance ||
        wrongWayAngleDegrees < 90 ||
        wrongWayAngleDegrees > 180 ||
        sensorRayAngleDegrees < 0 ||
        sensorRayAngleDegrees > 90 ||
        racingLineBiasDistance < 0 ||
        mistakeDurationSeconds < 0) {
      throw ArgumentError(
        'AI geometry values are outside the supported range.',
      );
    }
    _requireUnitInterval(avoidanceSteering, 'avoidanceSteering');
    _requireUnitInterval(obstacleSpeedReduction, 'obstacleSpeedReduction');
    _requireUnitInterval(mistakeProbability, 'mistakeProbability');
    _requireUnitInterval(mistakeSteering, 'mistakeSteering');
    _requireUnitInterval(routeTurnPriority, 'routeTurnPriority');
  }

  static void _requireUnitInterval(double value, String name) {
    if (value < 0 || value > 1) {
      throw ArgumentError.value(value, name, 'must be between zero and one');
    }
  }

  static double _clamp(double value, double minimum, double maximum) =>
      Float32.clamp(value, minimum, maximum);

  static double _maximum(double left, double right) =>
      left > right ? left : right;

  static double _minimum(double left, double right) =>
      left < right ? left : right;
}

/// Reference AI difficulty profile.
enum AiDifficulty { easy, normal, hard }
