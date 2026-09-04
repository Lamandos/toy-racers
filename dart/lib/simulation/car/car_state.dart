import '../math/float32.dart';

/// Mutable simulation state for one car, expressed in world units.
///
/// State is intentionally mutable because one fixed simulation step updates all
/// of its fields together. Every write narrows to binary32 to match Kotlin
/// `Float` storage semantics.
final class CarState {
  CarState({
    double x = 0,
    double y = 0,
    double rotationDegrees = 0,
    double longitudinalSpeed = 0,
    double velocityX = 0,
    double velocityY = 0,
    double angularVelocity = 0,
    double lateralSpeed = 0,
    double driftAmount = 0,
  }) : _x = Float32.narrow(x),
       _y = Float32.narrow(y),
       _rotationDegrees = Float32.narrow(rotationDegrees),
       _longitudinalSpeed = Float32.narrow(longitudinalSpeed),
       _velocityX = Float32.narrow(velocityX),
       _velocityY = Float32.narrow(velocityY),
       _angularVelocity = Float32.narrow(angularVelocity),
       _lateralSpeed = Float32.narrow(lateralSpeed),
       _driftAmount = Float32.narrow(driftAmount);

  double _x;
  double _y;
  double _rotationDegrees;
  double _longitudinalSpeed;
  double _velocityX;
  double _velocityY;
  double _angularVelocity;
  double _lateralSpeed;
  double _driftAmount;

  double get x => _x;
  set x(double value) => _x = Float32.narrow(value);

  double get y => _y;
  set y(double value) => _y = Float32.narrow(value);

  double get rotationDegrees => _rotationDegrees;
  set rotationDegrees(double value) => _rotationDegrees = Float32.narrow(value);

  double get longitudinalSpeed => _longitudinalSpeed;
  set longitudinalSpeed(double value) =>
      _longitudinalSpeed = Float32.narrow(value);

  double get velocityX => _velocityX;
  set velocityX(double value) => _velocityX = Float32.narrow(value);

  double get velocityY => _velocityY;
  set velocityY(double value) => _velocityY = Float32.narrow(value);

  double get angularVelocity => _angularVelocity;
  set angularVelocity(double value) => _angularVelocity = Float32.narrow(value);

  double get lateralSpeed => _lateralSpeed;
  set lateralSpeed(double value) => _lateralSpeed = Float32.narrow(value);

  double get driftAmount => _driftAmount;
  set driftAmount(double value) => _driftAmount = Float32.narrow(value);

  /// Copies the complete state for rendering interpolation or deterministic tests.
  CarState copy() => CarState(
    x: x,
    y: y,
    rotationDegrees: rotationDegrees,
    longitudinalSpeed: longitudinalSpeed,
    velocityX: velocityX,
    velocityY: velocityY,
    angularVelocity: angularVelocity,
    lateralSpeed: lateralSpeed,
    driftAmount: driftAmount,
  );

  /// Replaces every field with an already narrowed value from [other].
  ///
  /// Simulation owners use this to retain fixed snapshot storage across ticks;
  /// no arithmetic is performed and binary32 values keep their exact bit pattern.
  void copyFrom(CarState other) {
    _x = other._x;
    _y = other._y;
    _rotationDegrees = other._rotationDegrees;
    _longitudinalSpeed = other._longitudinalSpeed;
    _velocityX = other._velocityX;
    _velocityY = other._velocityY;
    _angularVelocity = other._angularVelocity;
    _lateralSpeed = other._lateralSpeed;
    _driftAmount = other._driftAmount;
  }

  @override
  bool operator ==(Object other) =>
      other is CarState &&
      _floatEquals(x, other.x) &&
      _floatEquals(y, other.y) &&
      _floatEquals(rotationDegrees, other.rotationDegrees) &&
      _floatEquals(longitudinalSpeed, other.longitudinalSpeed) &&
      _floatEquals(velocityX, other.velocityX) &&
      _floatEquals(velocityY, other.velocityY) &&
      _floatEquals(angularVelocity, other.angularVelocity) &&
      _floatEquals(lateralSpeed, other.lateralSpeed) &&
      _floatEquals(driftAmount, other.driftAmount);

  @override
  int get hashCode => Object.hash(
    _floatHash(x),
    _floatHash(y),
    _floatHash(rotationDegrees),
    _floatHash(longitudinalSpeed),
    _floatHash(velocityX),
    _floatHash(velocityY),
    _floatHash(angularVelocity),
    _floatHash(lateralSpeed),
    _floatHash(driftAmount),
  );

  static bool _floatEquals(double left, double right) =>
      left == right &&
      (left != 0 ||
          Float32.isNegativeZero(left) == Float32.isNegativeZero(right));

  static int _floatHash(double value) =>
      Float32.isNegativeZero(value) ? 0x80000000 : value.hashCode;
}
