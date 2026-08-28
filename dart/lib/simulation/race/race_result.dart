import '../math/float32.dart';

/// Immutable result of one completed participant's race.
final class RaceResult {
  RaceResult({
    required this.finishPosition,
    required this.competitorCount,
    required double totalRaceTime,
    required double? bestLapTime,
    this.isNewRecord = false,
  }) : totalRaceTime = Float32.narrow(totalRaceTime),
       bestLapTime = bestLapTime == null ? null : Float32.narrow(bestLapTime);

  final int finishPosition;
  final int competitorCount;
  final double totalRaceTime;
  final double? bestLapTime;
  final bool isNewRecord;
}

/// Couples a stable participant ID with its gameplay [RaceResult].
final class ParticipantRaceResult {
  const ParticipantRaceResult({
    required this.participantId,
    required this.result,
  });

  final String participantId;
  final RaceResult result;
}
