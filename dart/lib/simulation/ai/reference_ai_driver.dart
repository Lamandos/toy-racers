import '../car/car_state.dart';
import '../input/player_input.dart';
import '../math/float32.dart';
import '../track/track.dart';
import '../track/track_point.dart';
import 'ai_config.dart';
import 'ai_driver.dart';
import 'ai_obstacle_detector.dart';
import 'ai_path_follower.dart';
import 'ai_race_context.dart';
import 'ai_recovery_controller.dart';

/// Kotlin-compatible deterministic AI path following and recovery driver.
final class ReferenceAiDriver
    implements
        AiDriver,
        ResettableAiDriver,
        RaceResettableAiDriver,
        RouteAwareAiDriver {
  ReferenceAiDriver({
    required Iterable<TrackPoint> racingLine,
    required TrackPoint initialPosition,
    AiConfig? config,
    this.difficulty = AiDifficulty.normal,
    double racingLineBias = 0,
    this.track,
    int? randomSeed,
  }) : racingLineBias = Float32.narrow(racingLineBias),
       _config = (config ?? AiConfig()).forDifficulty(difficulty),
       _initialRandomState = _randomStateFor(
         initialPosition,
         racingLineBias,
         randomSeed,
       ),
       _randomState = _randomStateFor(
         initialPosition,
         racingLineBias,
         randomSeed,
       ) {
    if (this.racingLineBias < -1 || this.racingLineBias > 1) {
      throw ArgumentError.value(
        racingLineBias,
        'racingLineBias',
        'must be normalized',
      );
    }
    _pathFollower = AiPathFollower(
      racingLine: racingLine,
      initialPosition: initialPosition,
      config: _config,
      racingLineBias: this.racingLineBias,
    );
    _obstacleDetector = AiObstacleDetector(_config);
    _recoveryController = AiRecoveryController(_config);
  }

  final AiDifficulty difficulty;
  final double racingLineBias;
  final Track? track;
  final AiConfig _config;
  late final AiPathFollower _pathFollower;
  late final AiObstacleDetector _obstacleDetector;
  late final AiRecoveryController _recoveryController;
  final int _initialRandomState;
  double _smoothedSteering = 0;
  double _mistakeCheckAccumulator = 0;
  double _mistakeTimeRemaining = 0;
  int _randomState;

  AiBehaviorState behaviorState = AiBehaviorState.followRoute;
  AiDebugSnapshot? debugSnapshot;
  bool _respawnRequested = false;

  int get targetWaypointIndex => _pathFollower.targetWaypointIndex;

  @override
  bool isFacingRoute(CarState carState) =>
      _pathFollower.headingError(carState).abs() <=
      _config.wrongWayAngleDegrees;

  @override
  void reset(TrackPoint restoredPosition) {
    _pathFollower.reset(restoredPosition);
    _recoveryController.reset();
    _smoothedSteering = 0;
    _respawnRequested = false;
    behaviorState = AiBehaviorState.followRoute;
    debugSnapshot = null;
  }

  @override
  void resetForRace(TrackPoint initialPosition) {
    reset(initialPosition);
    _mistakeCheckAccumulator = 0;
    _mistakeTimeRemaining = 0;
    _randomState = _initialRandomState;
  }

  @override
  AiDriverDecision update({
    required CarState carState,
    required double deltaSeconds,
    required AiRaceContext context,
  }) {
    final delta = Float32.narrow(deltaSeconds);
    if (delta < 0) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must not be negative',
      );
    }
    _pathFollower.update(TrackPoint(carState.x, carState.y));
    final target = _pathFollower.target();
    final rays = _obstacleDetector.scanTrack(carState, track);
    if (context.finished) {
      if (!context.isOnTrack) {
        _respawnRequested = true;
      }
      behaviorState = AiBehaviorState.finished;
      final input = carState.longitudinalSpeed > _finishedBrakingMinimumSpeed
          ? PlayerInput(brake: 1)
          : PlayerInput.none;
      return _publish(carState, input, target, null, rays);
    }

    final headingError = _pathFollower.headingError(
      carState,
      targetPoint: target,
    );
    switch (_recoveryController.update(
      carState: carState,
      headingErrorDegrees: headingError,
      isOnTrack: context.isOnTrack,
      deltaSeconds: delta,
    )) {
      case AiRecoveryAction.reverse:
        behaviorState = AiBehaviorState.recover;
        return _publish(
          carState,
          PlayerInput(
            brake: 1,
            steering: Float32.clamp(
              Float32.divide(-headingError, _config.fullSteeringAngleDegrees),
              -1,
              1,
            ),
          ),
          target,
          null,
          rays,
        );
      case AiRecoveryAction.respawn:
        _respawnRequested = true;
        behaviorState = AiBehaviorState.recover;
        return _publish(carState, PlayerInput.none, target, null, rays);
      case AiRecoveryAction.none:
        break;
    }

    final routeSteering = Float32.clamp(
      Float32.divide(-headingError, _config.fullSteeringAngleDegrees),
      -1,
      1,
    );
    final obstacleDecision = _obstacleDecision(
      carState,
      context.obstacles,
      rays,
    );
    behaviorState = obstacleDecision.behaviorState;
    final steering = _steeringDecision(routeSteering, obstacleDecision, delta);
    final shouldBrake = _shouldBrake(carState, headingError, obstacleDecision);
    return _publish(
      carState,
      PlayerInput(
        throttle: shouldBrake ? 0 : 1,
        brake: shouldBrake ? 1 : 0,
        steering: steering,
      ),
      target,
      obstacleDecision.movingObstacle,
      rays,
    );
  }

  _ObstacleDecision _obstacleDecision(
    CarState carState,
    List<AiObstacle> obstacles,
    List<AiSensorRay> rays,
  ) {
    final movingObstacle = _obstacleDetector.nearestAhead(carState, obstacles);
    AiSensorRay? staticThreat;
    for (final ray in rays) {
      if (ray.hit &&
          ray.distance() <= _config.staticObstacleReactionDistance &&
          (staticThreat == null || ray.distance() < staticThreat.distance())) {
        staticThreat = ray;
      }
    }
    final passingDirection = movingObstacle == null
        ? null
        : _safestPassingDirection(carState, obstacles, rays, movingObstacle);
    final canOvertake =
        movingObstacle != null &&
        passingDirection != null &&
        Float32.add(
              movingObstacle.obstacle.speed,
              _config.overtakeSpeedAdvantage,
            ) <
            carState.longitudinalSpeed;
    final state = canOvertake
        ? AiBehaviorState.overtake
        : movingObstacle != null || staticThreat != null
        ? AiBehaviorState.avoid
        : AiBehaviorState.followRoute;
    return _ObstacleDecision(
      movingObstacle: movingObstacle,
      staticThreat: staticThreat,
      passingDirection: passingDirection,
      behaviorState: state,
      rays: rays,
    );
  }

  double _steeringDecision(
    double routeSteering,
    _ObstacleDecision obstacleDecision,
    double deltaSeconds,
  ) {
    _updateMistake(deltaSeconds);
    final routeContribution =
        obstacleDecision.staticThreat != null &&
            routeSteering.abs() < _config.routeTurnPriority
        ? 0.0
        : routeSteering;
    final dynamicAvoidance = obstacleDecision.passingDirection == null
        ? 0.0
        : Float32.multiply(
            obstacleDecision.passingDirection!,
            _config.avoidanceSteering,
          );
    final staticAvoidance = obstacleDecision.staticThreat == null
        ? 0.0
        : Float32.multiply(
            _safestTrackDirection(obstacleDecision.rays),
            _config.avoidanceSteering,
          );
    final mistakeSteering = _mistakeTimeRemaining > 0
        ? _config.mistakeSteering
        : 0.0;
    final desired = Float32.clamp(
      Float32.add(
        Float32.add(
          Float32.add(routeContribution, dynamicAvoidance),
          staticAvoidance,
        ),
        mistakeSteering,
      ),
      -1,
      1,
    );
    final blend = Float32.clamp(
      Float32.multiply(_config.steeringResponse, deltaSeconds),
      0,
      1,
    );
    _smoothedSteering = Float32.add(
      _smoothedSteering,
      Float32.multiply(Float32.subtract(desired, _smoothedSteering), blend),
    );
    return _smoothedSteering;
  }

  bool _shouldBrake(
    CarState carState,
    double headingError,
    _ObstacleDecision obstacleDecision,
  ) {
    final cornerAmount = Float32.clamp(
      Float32.divide(
        _maximum(headingError.abs(), _pathFollower.turnAheadDegrees(carState)),
        90,
      ),
      0,
      1,
    );
    final desiredSpeed = Float32.add(
      _config.straightSpeed,
      Float32.multiply(
        Float32.subtract(_config.cornerSpeed, _config.straightSpeed),
        cornerAmount,
      ),
    );
    final safeSpeed = obstacleDecision.distance == null
        ? desiredSpeed
        : _safeSpeedForObstacle(desiredSpeed, obstacleDecision.distance!);
    return carState.longitudinalSpeed >
        Float32.add(safeSpeed, _config.brakingMargin);
  }

  double _safeSpeedForObstacle(double desiredSpeed, double distance) {
    final proximity = Float32.subtract(
      1,
      Float32.divide(distance, _config.obstacleDetectionDistance),
    );
    return Float32.multiply(
      desiredSpeed,
      Float32.subtract(
        1,
        Float32.multiply(
          Float32.clamp(proximity, 0, 1),
          _config.obstacleSpeedReduction,
        ),
      ),
    );
  }

  void _updateMistake(double deltaSeconds) {
    _mistakeTimeRemaining = _maximum(
      Float32.subtract(_mistakeTimeRemaining, deltaSeconds),
      0,
    );
    _mistakeCheckAccumulator = Float32.add(
      _mistakeCheckAccumulator,
      deltaSeconds,
    );
    while (_mistakeCheckAccumulator >= _config.mistakeCheckIntervalSeconds) {
      _mistakeCheckAccumulator = Float32.subtract(
        _mistakeCheckAccumulator,
        _config.mistakeCheckIntervalSeconds,
      );
      _randomState =
          (_randomState * _randomMultiplier + _randomIncrement) &
          _unsignedIntMask;
      final sample = Float32.divide(
        (_randomState >> 8).toDouble(),
        _randomSampleDivisor.toDouble(),
      );
      if (sample < _config.mistakeProbability) {
        _mistakeTimeRemaining = _config.mistakeDurationSeconds;
      }
    }
  }

  double? _safestPassingDirection(
    CarState carState,
    List<AiObstacle> obstacles,
    List<AiSensorRay> rays,
    DetectedAiObstacle detected,
  ) {
    final preferred = detected.lateralDistance > 0
        ? 1.0
        : detected.lateralDistance < 0
        ? -1.0
        : -_nonZeroSign(racingLineBias);
    final firstClearance = _minimum(
      _obstacleDetector.passingClearance(carState, obstacles, preferred),
      _trackClearance(rays, preferred),
    );
    final alternative = -preferred;
    final alternativeClearance = _minimum(
      _obstacleDetector.passingClearance(carState, obstacles, alternative),
      _trackClearance(rays, alternative),
    );
    final direction = firstClearance >= alternativeClearance
        ? preferred
        : alternative;
    final clearance = firstClearance >= alternativeClearance
        ? firstClearance
        : alternativeClearance;
    return clearance >= _config.overtakeMinimumClearance ? direction : null;
  }

  double _safestTrackDirection(List<AiSensorRay> rays) {
    final leftClearance = _trackClearance(rays, -1);
    final rightClearance = _trackClearance(rays, 1);
    return leftClearance >= rightClearance ? -1 : 1;
  }

  double _trackClearance(List<AiSensorRay> rays, double steeringDirection) {
    final wantedAngleSign = steeringDirection < 0 ? 1 : -1;
    for (final ray in rays) {
      if (_sign(ray.angleOffsetDegrees) == wantedAngleSign) {
        return ray.distance();
      }
    }
    return _config.obstacleDetectionDistance;
  }

  AiDriverDecision _publish(
    CarState carState,
    PlayerInput input,
    TrackPoint target,
    DetectedAiObstacle? obstacle,
    List<AiSensorRay> rays,
  ) {
    final normalized = input.normalized();
    debugSnapshot = AiDebugSnapshot(
      position: TrackPoint(carState.x, carState.y),
      speed: carState.longitudinalSpeed,
      targetPoint: target,
      behaviorState: behaviorState,
      detectedObstacle: obstacle,
      sensorRays: rays,
      input: normalized,
    );
    final requestRespawn = _respawnRequested;
    _respawnRequested = false;
    return AiDriverDecision(input: normalized, requestRespawn: requestRespawn);
  }

  static int _randomStateFor(
    TrackPoint initialPosition,
    double racingLineBias,
    int? randomSeed,
  ) =>
      Float32.bits(initialPosition.x) ^
      Float32.bits(initialPosition.y) ^
      Float32.bits(racingLineBias) ^
      _randomSeedBits(randomSeed);

  static int _randomSeedBits(int? seed) {
    if (seed == null) {
      return 0;
    }
    final narrowed = seed & _unsignedLongMask;
    return (narrowed ^ (narrowed >> 32)) & _unsignedIntMask;
  }

  static double _maximum(double left, double right) =>
      left > right ? left : right;

  static double _minimum(double left, double right) =>
      left < right ? left : right;

  static double _nonZeroSign(double value) => value < 0 ? -1 : 1;

  static int _sign(double value) => value < 0
      ? -1
      : value > 0
      ? 1
      : 0;

  static final double _finishedBrakingMinimumSpeed = Float32.narrow(0.01);
  static const int _randomMultiplier = 1664525;
  static const int _randomIncrement = 1013904223;
  static const int _randomSampleDivisor = 0x01000000;
  static const int _unsignedIntMask = 0xffffffff;
  static const int _unsignedLongMask = 0xffffffffffffffff;
}

/// Current observable AI behavior selected for a command.
enum AiBehaviorState { followRoute, avoid, overtake, recover, finished }

/// Immutable diagnostics for an AI command, without rendering dependencies.
final class AiDebugSnapshot {
  const AiDebugSnapshot({
    required this.position,
    required this.speed,
    required this.targetPoint,
    required this.behaviorState,
    required this.detectedObstacle,
    required this.sensorRays,
    required this.input,
  });

  final TrackPoint position;
  final double speed;
  final TrackPoint targetPoint;
  final AiBehaviorState behaviorState;
  final DetectedAiObstacle? detectedObstacle;
  final List<AiSensorRay> sensorRays;
  final PlayerInput input;
}

final class _ObstacleDecision {
  const _ObstacleDecision({
    required this.movingObstacle,
    required this.staticThreat,
    required this.passingDirection,
    required this.behaviorState,
    required this.rays,
  });

  final DetectedAiObstacle? movingObstacle;
  final AiSensorRay? staticThreat;
  final double? passingDirection;
  final AiBehaviorState behaviorState;
  final List<AiSensorRay> rays;

  double? get distance =>
      movingObstacle?.forwardDistance ?? staticThreat?.distance();
}
