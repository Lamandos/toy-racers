import 'package:toy_racers/simulation.dart';

/// Immutable track geometry reused by every minimap presentation frame.
///
/// Simulation coordinates are kept upward-positive here. The Flutter painter
/// performs the final Y-axis inversion so this model remains platform-neutral.
final class RaceMinimapTrack {
  RaceMinimapTrack({
    required this.worldBounds,
    Iterable<TrackPoint>? outerRoad,
    Iterable<TrackPoint>? innerRoad,
  }) : outerRoad = outerRoad == null
           ? null
           : List<TrackPoint>.unmodifiable(outerRoad),
       innerRoad = innerRoad == null
           ? null
           : List<TrackPoint>.unmodifiable(innerRoad);

  factory RaceMinimapTrack.fromTrack(Track track) => RaceMinimapTrack(
    worldBounds: track.worldBounds,
    outerRoad: track.roadOuter?.vertices,
    innerRoad: track.roadInner?.vertices,
  );

  final TrackRectangle worldBounds;
  final List<TrackPoint>? outerRoad;
  final List<TrackPoint>? innerRoad;
}

/// Dynamic marker data copied from render-only car poses.
final class RaceMinimapParticipant {
  const RaceMinimapParticipant({
    required this.x,
    required this.y,
    required this.rotationDegrees,
    required this.role,
  });

  final double x;
  final double y;
  final double rotationDegrees;
  final RaceMinimapParticipantRole role;
}

enum RaceMinimapParticipantRole { player, opponent }

/// One visual minimap observation. It never exposes mutable simulation state.
final class RaceMinimapState {
  RaceMinimapState({
    required this.track,
    required Iterable<RaceMinimapParticipant> participants,
  }) : participants = List<RaceMinimapParticipant>.unmodifiable(participants);

  final RaceMinimapTrack track;
  final List<RaceMinimapParticipant> participants;
}
