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
}
