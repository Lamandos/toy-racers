import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/ui/race_minimap.dart';
import 'package:toy_racers/game/ui/race_minimap_state.dart';
import 'package:toy_racers/game/ui/race_ui_controller.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('minimap state retains immutable dynamic marker data', () {
    final state = RaceMinimapState(
      track: RaceMinimapTrack.fromTrack(_track()),
      participants: <RaceMinimapParticipant>[
        const RaceMinimapParticipant(
          x: 20,
          y: 25,
          rotationDegrees: 0,
          role: RaceMinimapParticipantRole.opponent,
        ),
      ],
    );

    expect(state.track.outerRoad, hasLength(4));
    expect(
      () => state.participants.add(
        const RaceMinimapParticipant(
          x: 30,
          y: 25,
          rotationDegrees: 0,
          role: RaceMinimapParticipantRole.player,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('minimap projection matches Kotlin padding and marker positions', () {
    final projection = RaceMinimapProjection(
      track: RaceMinimapTrack.fromTrack(_track()),
    );

    expect(projection.offsetFor(20, 25), const Offset(44, 71));
    expect(projection.offsetFor(50, 25), const Offset(95, 71));
    expect(projection.offsetFor(70, 25), const Offset(129, 71));
    expect(projection.offsetFor(0, 50), const Offset(10, 28.5));
    expect(projection.offsetFor(100, 0), const Offset(180, 113.5));
  });

  testWidgets('minimap updates its painter when marker data changes', (
    tester,
  ) async {
    final controller = _FakeMinimapController(_state());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: RaceMinimap(controller: controller)),
      ),
    );

    expect(tester.getSize(find.byType(RaceMinimap)), RaceMinimap.preferredSize);
    final initialPainter = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter;

    controller.minimapState = _state(playerX: 70);
    controller.minimapFrame.value++;
    await tester.pump();

    final updatedPainter = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter;
    expect(updatedPainter, isNot(same(initialPainter)));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.minimapFrame.dispose();
  });
}

RaceMinimapState _state({double playerX = 50}) => RaceMinimapState(
  track: RaceMinimapTrack.fromTrack(_track()),
  participants: <RaceMinimapParticipant>[
    const RaceMinimapParticipant(
      x: 20,
      y: 25,
      rotationDegrees: 0,
      role: RaceMinimapParticipantRole.opponent,
    ),
    RaceMinimapParticipant(
      x: playerX,
      y: 25,
      rotationDegrees: 0,
      role: RaceMinimapParticipantRole.player,
    ),
  ],
);

Track _track() => Track.fromDefinition(
  id: 'minimap-track',
  name: 'Minimap Track',
  worldBounds: TrackRectangle(0, 0, 100, 50),
  cameraBounds: TrackRectangle(0, 0, 100, 50),
  outerBoundary: TrackRectangle(0, 0, 100, 50),
  backgroundSurface: SurfaceType.asphalt,
  roadOuter: TrackPolygon(<TrackPoint>[
    TrackPoint(0, 0),
    TrackPoint(100, 0),
    TrackPoint(100, 50),
    TrackPoint(0, 50),
  ]),
  roadInner: TrackPolygon(<TrackPoint>[
    TrackPoint(35, 15),
    TrackPoint(65, 15),
    TrackPoint(65, 35),
    TrackPoint(35, 35),
  ]),
  startLine: StartLine(
    bounds: TrackRectangle(45, 20, 2, 8),
    forwardX: 1,
    forwardY: 0,
  ),
  checkpoints: <Checkpoint>[
    Checkpoint(
      order: 0,
      gate: TrackSegment(TrackPoint(90, 10), TrackPoint(90, 40)),
      forwardX: 1,
      forwardY: 0,
    ),
  ],
  startGrid: <StartGridPosition>[
    StartGridPosition(position: TrackPoint(50, 25), rotationDegrees: 0),
  ],
  racingLine: <TrackPoint>[
    TrackPoint(10, 10),
    TrackPoint(90, 10),
    TrackPoint(90, 40),
  ],
);

final class _FakeMinimapController implements RaceMinimapController {
  _FakeMinimapController(this.minimapState);

  @override
  RaceMinimapState minimapState;
  @override
  final ValueNotifier<int> minimapFrame = ValueNotifier<int>(0);
}
