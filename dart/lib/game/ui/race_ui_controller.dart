import 'package:flutter/foundation.dart';
import 'package:toy_racers/simulation.dart';

/// Read-only race data rendered by Flutter widgets.
///
/// A fresh value is created by the Flame adapter whenever a presentation frame
/// is published. It keeps widgets from reaching into [RaceSession] and making
/// gameplay changes directly.
final class RaceUiState {
  RaceUiState({
    required this.phase,
    required this.countdownRemainingSeconds,
    required this.position,
    required this.competitorCount,
    required this.displayedLap,
    required this.requiredLaps,
    required this.totalRaceTime,
    required this.bestLapTime,
    required this.playerResult,
    required List<RaceStanding> standings,
  }) : standings = List<RaceStanding>.unmodifiable(standings);

  final RacePhase phase;
  final double countdownRemainingSeconds;
  final int position;
  final int competitorCount;
  final int displayedLap;
  final int requiredLaps;
  final double totalRaceTime;
  final double? bestLapTime;
  final RaceStanding? playerResult;
  final List<RaceStanding> standings;

  /// Captures only display values from the deterministic simulation.
  factory RaceUiState.fromSession(RaceSession session) {
    final player = session.player;
    return RaceUiState(
      phase: session.raceState.phase,
      countdownRemainingSeconds: session.raceState.countdownRemainingSeconds,
      position: session.playerPosition,
      competitorCount: session.participants.length,
      displayedLap: (player.progress.completedLaps + 1)
          .clamp(1, session.requiredLaps)
          .toInt(),
      requiredLaps: session.requiredLaps,
      totalRaceTime: player.progress.totalRaceTime,
      bestLapTime: player.progress.bestLapTime,
      playerResult: _standingFor(session.playerResult, 'player'),
      standings: session.finishResults
          .map((entry) => _standingFor(entry.result, entry.participantId)!)
          .toList(growable: false),
    );
  }

  static RaceStanding? _standingFor(RaceResult? result, String participantId) =>
      result == null
      ? null
      : RaceStanding(
          participantId: participantId,
          finishPosition: result.finishPosition,
          competitorCount: result.competitorCount,
          totalRaceTime: result.totalRaceTime,
        );
}

/// One immutable row in the results panel.
final class RaceStanding {
  const RaceStanding({
    required this.participantId,
    required this.finishPosition,
    required this.competitorCount,
    required this.totalRaceTime,
  });

  final String participantId;
  final int finishPosition;
  final int competitorCount;
  final double totalRaceTime;
}

/// The documented presentation-to-simulation boundary for Flutter widgets.
///
/// Widgets may observe [uiState] and [presentationFrame], and may only change
/// a race through [togglePause] and [restartRace]. Continuous driving input is
/// sent separately through [PlayerInputAdapter] by the Flame game adapter.
abstract interface class RaceUiController {
  RaceUiState get uiState;
  ValueListenable<int> get presentationFrame;

  void togglePause();
  void restartRace();
}
