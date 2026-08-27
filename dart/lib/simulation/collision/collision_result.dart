import '../math/float32.dart';

/// Kind of solid that produced a deterministic collision contact.
enum CollisionType { worldBoundary, trackObject, car }

/// One ordered contact emitted by the collision resolver.
final class CollisionContact {
  CollisionContact({
    required this.type,
    required double normalX,
    required double normalY,
    required double penetration,
    required double impactSpeed,
  }) : normalX = Float32.narrow(normalX),
       normalY = Float32.narrow(normalY),
       penetration = Float32.narrow(penetration),
       impactSpeed = Float32.narrow(impactSpeed);

  final CollisionType type;
  final double normalX;
  final double normalY;
  final double penetration;
  final double impactSpeed;
}

/// Summary emitted by one deterministic collision resolution pass.
final class CollisionResult {
  CollisionResult([
    Iterable<CollisionContact> contacts = const <CollisionContact>[],
  ]) : contacts = List<CollisionContact>.unmodifiable(contacts);

  static final CollisionResult none = CollisionResult();

  final List<CollisionContact> contacts;

  bool get collided => contacts.isNotEmpty;

  double get maxImpactSpeed {
    var maximum = 0.0;
    for (final contact in contacts) {
      if (contact.impactSpeed > maximum) {
        maximum = contact.impactSpeed;
      }
    }
    return maximum;
  }
}
