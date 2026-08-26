import '../ai/ai_driver.dart';
import '../car/car_config.dart';
import '../car/car_state.dart';
import '../snapshot/simulation_snapshot.dart';
import '../surface/surface_speed_system.dart';
import '../track/track.dart';
import 'race_phase.dart';

/// A stable participant in a [RaceSession].
final class RaceParticipant {
  RaceParticipant({
    required String id,
    required this.carState,
    required this.carConfig,
    this.aiDriver,
    SurfaceSpeedState? surfaceSpeedState,
  }) : id = _requireId(id),
       surfaceSpeedState = surfaceSpeedState ?? SurfaceSpeedState();

  final String id;
  final CarState carState;
  final CarConfig carConfig;
  final AiDriver? aiDriver;
  final SurfaceSpeedState surfaceSpeedState;

  static String _requireId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    return id;
  }
}

/// Headless assembly root for a deterministic race simulation.
///
/// This class is deliberately free of frame loops, bindings, and clocks. A
/// later fixed-step pipeline will own physics, collision, surface, rule, and
/// AI execution here in the order documented by the behavioral contract.
final class RaceSession {
  RaceSession({
    required this.track,
    required Iterable<RaceParticipant> participants,
    RaceState? raceState,
  }) : participants = List<RaceParticipant>.unmodifiable(participants),
       raceState = raceState ?? RaceState() {
    if (this.participants.isEmpty) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must not be empty',
      );
    }
    final participantIds = this.participants
        .map((participant) => participant.id)
        .toSet();
    if (participantIds.length != this.participants.length) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must have unique IDs',
      );
    }
  }

  final Track track;
  final List<RaceParticipant> participants;
  final RaceState raceState;

  /// Exposes the initial deterministic state without advancing a clock.
  SimulationSnapshot get snapshot => SimulationSnapshot(
    simulationTick: 0,
    racePhase: raceState.phase,
    countdownRemainingSeconds: raceState.countdownRemainingSeconds,
    elapsedSimulationTime: 0,
  );
}
