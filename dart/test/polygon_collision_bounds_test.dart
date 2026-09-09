import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';
import 'package:toy_racers/simulation/collision/collision_geometry.dart';
import 'package:toy_racers/simulation/collision/polygon_collision_bounds.dart';

void main() {
  test('never excludes an outside circle touching a reference edge', () {
    final random = Random(7281);
    var excluded = 0;
    for (var polygonIndex = 0; polygonIndex < 40; polygonIndex++) {
      final vertices = <TrackPoint>[
        for (var index = 0; index < 8; index++)
          TrackPoint(
            20 + (2 + random.nextDouble() * 6) * cos(index * pi / 4),
            20 + (2 + random.nextDouble() * 6) * sin(index * pi / 4),
          ),
      ];
      final polygon = TrackPolygon(
        polygonIndex.isEven ? vertices : vertices.reversed,
      );
      final bounds = PolygonCollisionBounds(polygon);
      for (var sample = 0; sample < 100; sample++) {
        final point = TrackPoint(
          random.nextDouble() * 40,
          random.nextDouble() * 40,
        );
        if (polygon.contains(point.x, point.y)) {
          continue;
        }
        final distance = CollisionGeometry.closestPolygonEdge(
          point,
          polygon,
        ).distance;
        // Include just-inside, exact tangent, and just-outside radii.
        for (final radius in <double>[
          1,
          Float32.narrow(distance * 1.000001 + 0.000001),
          distance,
          Float32.narrow(distance * 0.999999),
        ]) {
          if (bounds.excludes(point.x, point.y, radius)) {
            excluded++;
            expect(distance, greaterThanOrEqualTo(radius));
          }
        }
      }
    }
    expect(excluded, greaterThan(1000));
  });

  test('leaves extreme and degenerate shapes to the reference resolver', () {
    for (final vertices in <List<TrackPoint>>[
      [TrackPoint(0, 0), TrackPoint(0, 0), TrackPoint(1, 1)],
      [TrackPoint(0, 0), TrackPoint(1e-20, 0), TrackPoint(1, 1)],
      [TrackPoint(0, 0), TrackPoint(1e8, 0), TrackPoint(1, 1)],
    ]) {
      expect(
        PolygonCollisionBounds(TrackPolygon(vertices)).excludes(100, 100, 1),
        isFalse,
      );
    }
    final bounds = PolygonCollisionBounds(
      TrackPolygon([TrackPoint(0, 0), TrackPoint(1, 0), TrackPoint(0, 1)]),
    );
    expect(bounds.excludes(1e8, 0, 1), isFalse);
    expect(bounds.excludes(100, 100, 1e-20), isFalse);
    expect(bounds.excludes(100, 100, 1), isTrue);
  });
}
