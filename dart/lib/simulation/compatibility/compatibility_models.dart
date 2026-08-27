import '../input/player_input.dart';

/// A versioned scenario document from `compatibility/schemas`.
final class CompatibilityScenarioDocument {
  CompatibilityScenarioDocument({
    required this.schemaVersion,
    required List<CompatibilityScenario> scenarios,
  }) : scenarios = List<CompatibilityScenario>.unmodifiable(scenarios);

  final int schemaVersion;
  final List<CompatibilityScenario> scenarios;
}

/// Fully parsed, device-independent input for one deterministic replay.
final class CompatibilityScenario {
  CompatibilityScenario({
    required this.schemaVersion,
    required this.id,
    required this.seed,
    required this.trackId,
    required this.playerCar,
    required this.inputOrigin,
    required List<String> tags,
    required this.ticks,
    required this.snapshotIntervalTicks,
    required List<CompatibilityInputSegment> inputSegments,
    required List<CompatibilityInputTweak> inputTweaks,
    required List<CompatibilityInitialState> initialStates,
    required this.fullRace,
  }) : tags = List<String>.unmodifiable(tags),
       inputSegments = List<CompatibilityInputSegment>.unmodifiable(
         inputSegments,
       ),
       inputTweaks = List<CompatibilityInputTweak>.unmodifiable(inputTweaks),
       initialStates = List<CompatibilityInitialState>.unmodifiable(
         initialStates,
       );

  final int schemaVersion;
  final String id;

  /// Exact decimal text for the signed 64-bit scenario identity.
  final String seed;
  final String trackId;
  final String playerCar;
  final String inputOrigin;
  final List<String> tags;
  final int ticks;
  final int snapshotIntervalTicks;
  final List<CompatibilityInputSegment> inputSegments;
  final List<CompatibilityInputTweak> inputTweaks;
  final List<CompatibilityInitialState> initialStates;
  final bool fullRace;

  BigInt get seedValue => BigInt.parse(seed);

  /// Returns the command for [tick] after its optional tweak and one clamp.
  PlayerInput inputForTick(int tick) {
    PlayerInput? segmentInput;
    for (final segment in inputSegments) {
      if (segment.contains(tick)) {
        segmentInput = segment.input;
        break;
      }
    }
    CompatibilityInputTweak? tweak;
    for (final candidate in inputTweaks) {
      if (candidate.tick == tick) {
        tweak = candidate;
        break;
      }
    }
    final base = segmentInput ?? PlayerInput.none;
    return tweak == null ? base.normalized() : base.withTweak(tweak.delta);
  }
}

/// Version 1 input script referenced from a scenario's own directory.
final class CompatibilityInputScript {
  CompatibilityInputScript({required List<CompatibilityInputSegment> segments})
    : segments = List<CompatibilityInputSegment>.unmodifiable(segments);

  static const int schemaVersion = 1;

  final List<CompatibilityInputSegment> segments;
}

/// An inclusive interval of raw player controls.
final class CompatibilityInputSegment {
  const CompatibilityInputSegment({
    required this.fromTick,
    required this.toTick,
    required this.input,
  });

  final int fromTick;
  final int toTick;
  final PlayerInput input;

  bool contains(int tick) => tick >= fromTick && tick <= toTick;
}

/// An additive control adjustment applied to one physical tick.
final class CompatibilityInputTweak {
  const CompatibilityInputTweak({required this.tick, required this.delta});

  final int tick;
  final PlayerInput delta;
}

/// Optional state injected before the first physical simulation tick.
final class CompatibilityInitialState {
  const CompatibilityInitialState({
    required this.id,
    this.x,
    this.y,
    this.rotationDeg,
    this.speed,
    this.velocityX,
    this.velocityY,
    this.angularVelocity,
    this.lateralSpeed,
    this.driftAmount,
    this.surfaceSpeedMultiplier,
    this.currentCheckpointIndex,
    this.completedLaps,
    this.lapStartTime,
    this.totalRaceTime,
    this.bestLapTime,
    this.finished,
    this.finishPosition,
  });

  final String id;
  final double? x;
  final double? y;
  final double? rotationDeg;
  final double? speed;
  final double? velocityX;
  final double? velocityY;
  final double? angularVelocity;
  final double? lateralSpeed;
  final double? driftAmount;
  final double? surfaceSpeedMultiplier;
  final int? currentCheckpointIndex;
  final int? completedLaps;
  final double? lapStartTime;
  final double? totalRaceTime;
  final double? bestLapTime;
  final bool? finished;
  final int? finishPosition;
}

/// One normalized snapshot that is valid for `snapshot.schema.json` version 2.
final class CompatibilitySnapshot {
  CompatibilitySnapshot({
    required this.simulationTick,
    required this.raceState,
    required this.countdown,
    required this.elapsedSimulationTime,
    required this.currentLap,
    required this.currentProgress,
    required List<CompatibilityParticipantSnapshot> participants,
    required List<String> ranking,
    required List<String> finishedParticipants,
    required List<CompatibilityFinishResult> finishResults,
  }) : participants = List<CompatibilityParticipantSnapshot>.unmodifiable(
         participants,
       ),
       ranking = List<String>.unmodifiable(ranking),
       finishedParticipants = List<String>.unmodifiable(finishedParticipants),
       finishResults = List<CompatibilityFinishResult>.unmodifiable(
         finishResults,
       );

  static const int schemaVersion = 2;

  final int simulationTick;
  final String raceState;
  final CompatibilityCountdown countdown;
  final double elapsedSimulationTime;
  final int currentLap;
  final CompatibilityProgress currentProgress;
  final List<CompatibilityParticipantSnapshot> participants;
  final List<String> ranking;
  final List<String> finishedParticipants;
  final List<CompatibilityFinishResult> finishResults;
}

/// The race countdown state recorded by a compatibility snapshot.
final class CompatibilityCountdown {
  const CompatibilityCountdown({
    required this.state,
    required this.remainingSeconds,
  });

  final String state;
  final double remainingSeconds;
}

/// Player checkpoint and completed-lap state recorded by a snapshot.
final class CompatibilityProgress {
  const CompatibilityProgress({
    required this.checkpoint,
    required this.completedLaps,
  });

  final int checkpoint;
  final int completedLaps;
}

/// Rendering-independent state for a participant in a snapshot.
final class CompatibilityParticipantSnapshot {
  const CompatibilityParticipantSnapshot({
    required this.id,
    required this.surface,
    required this.x,
    required this.y,
    required this.rotation,
    required this.velocityX,
    required this.velocityY,
    required this.angularVelocity,
    required this.longitudinalSpeed,
    required this.lateralSpeed,
    required this.driftAmount,
    required this.checkpoint,
    required this.lap,
    required this.racePosition,
    required this.finished,
  });

  final String id;
  final String surface;
  final double x;
  final double y;
  final double rotation;
  final double velocityX;
  final double velocityY;
  final double angularVelocity;
  final double longitudinalSpeed;
  final double lateralSpeed;
  final double driftAmount;
  final int checkpoint;
  final int lap;
  final int racePosition;
  final bool finished;
}

/// One participant's immutable finish timing.
final class CompatibilityFinishResult {
  const CompatibilityFinishResult({
    required this.participantId,
    required this.finishPosition,
    required this.elapsedSimulationTime,
    required this.bestLapTime,
  });

  final String participantId;
  final int finishPosition;
  final double elapsedSimulationTime;
  final double? bestLapTime;
}

/// Ordered samples encoded into `trace.schema.json` version 3.
final class CompatibilityTrace {
  CompatibilityTrace({
    required this.scenarioId,
    required this.seed,
    required List<CompatibilityTraceSample> samples,
  }) : samples = List<CompatibilityTraceSample>.unmodifiable(samples);

  static const int schemaVersion = 3;

  final String scenarioId;
  final String seed;
  final List<CompatibilityTraceSample> samples;

  BigInt get seedValue => BigInt.parse(seed);
}

/// A labeled observation at a trace tick.
final class CompatibilityTraceSample {
  const CompatibilityTraceSample({
    required this.label,
    required this.tick,
    required this.snapshot,
  });

  final String label;
  final int tick;
  final CompatibilitySnapshot snapshot;
}
