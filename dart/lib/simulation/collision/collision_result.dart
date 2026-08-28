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
  /// [maxImpactSpeed] preserves the constructor used before contacts were
  /// exposed. New callers should provide [contacts] so the aggregate is
  /// derived from the ordered collision details.
  CollisionResult({
    Iterable<CollisionContact> contacts = const <CollisionContact>[],
    double maxImpactSpeed = 0,
  }) : contacts = List<CollisionContact>.unmodifiable(contacts),
       _legacyMaxImpactSpeed = Float32.narrow(maxImpactSpeed);

  static final CollisionResult none = CollisionResult();

  final List<CollisionContact> contacts;
  final double _legacyMaxImpactSpeed;

  bool get collided => contacts.isNotEmpty;

  double get maxImpactSpeed {
    var maximum = _legacyMaxImpactSpeed;
    for (final contact in contacts) {
      if (contact.impactSpeed > maximum) {
        maximum = contact.impactSpeed;
      }
    }
    return maximum;
  }
}
