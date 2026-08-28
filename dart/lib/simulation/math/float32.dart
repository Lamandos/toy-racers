import 'dart:typed_data';

/// Explicit IEEE-754 binary32 operations used at Kotlin `Float` boundaries.
///
/// Dart numbers are binary64. Use this class only where the Kotlin reference
/// either stores a `Float`, converts a value with `toFloat()`, or evaluates an
/// expression whose operands are `Float`. This includes scenario floats,
/// mutable simulation state, fixed-step and race-progress timers, and scalar
/// physics, collision, surface, and AI calculations.
///
/// Do not add a narrowing call around arithmetic that Kotlin intentionally
/// evaluates as `Double`: trigonometry, `toRadians`, `toDegrees`, and the
/// documented double-precision geometry boundaries keep their binary64
/// intermediates until their explicit `toFloat()` conversion.
final class Float32 {
  Float32._();

  /// The fixed physics step used by the Kotlin reference: `1f / 60f`.
  static final double fixedDeltaSeconds = divide(1, 60);

  /// Narrows [value] to a finite IEEE-754 binary32 value.
  ///
  /// This is the conversion boundary for finite values read from scenario
  /// JSON, supplied through a constructor, or written into a Kotlin `Float`
  /// equivalent. Conversion uses IEEE-754 round-to-nearest, ties-to-even.
  static double narrow(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    final narrowed = _round(value);
    if (!narrowed.isFinite) {
      throw ArgumentError.value(
        value,
        'value',
        'must fit in a finite IEEE-754 binary32 value',
      );
    }
    return narrowed;
  }

  /// Adds two binary32 values and narrows the result to binary32.
  ///
  /// A finite arithmetic result that overflows binary32 is retained as an
  /// infinity so a later operation, such as clamping, can reproduce Float
  /// arithmetic semantics.
  static double add(double left, double right) =>
      _narrowArithmeticResult(narrow(left) + narrow(right));

  /// Subtracts two binary32 values and narrows the result to binary32.
  static double subtract(double left, double right) =>
      _narrowArithmeticResult(narrow(left) - narrow(right));

  /// Multiplies two binary32 values and narrows the result to binary32.
  static double multiply(double left, double right) =>
      _narrowArithmeticResult(narrow(left) * narrow(right));

  /// Divides two binary32 values and narrows the result to binary32.
  /// IEEE-754 infinity and NaN results are preserved.
  static double divide(double dividend, double divisor) =>
      _narrowArithmeticResult(narrow(dividend) / narrow(divisor));

  /// Computes the Kotlin `Float` remainder operation and narrows its result.
  static double remainder(double dividend, double divisor) =>
      _narrowArithmeticResult(narrow(dividend).remainder(narrow(divisor)));

  /// Clamps a binary32 [value] inclusively between binary32 limits.
  static double clamp(double value, double minimum, double maximum) {
    final narrowedMinimum = narrow(minimum);
    final narrowedMaximum = narrow(maximum);
    if (narrowedMinimum > narrowedMaximum) {
      throw ArgumentError.value(
        maximum,
        'maximum',
        'must be greater than or equal to minimum',
      );
    }
    final narrowedValue = _narrowArithmeticResult(value);
    if (narrowedValue < narrowedMinimum) {
      return narrowedMinimum;
    }
    if (narrowedValue > narrowedMaximum) {
      return narrowedMaximum;
    }
    return narrowedValue;
  }

  /// Matches `CarPhysics.normalizeDegrees` in the Kotlin reference.
  ///
  /// This keeps a negative zero because it is still simulation state. Use
  /// [normalizeRotationDegrees] when producing a compatibility trace.
  static double wrapDegrees(double degrees) {
    final wrapped = remainder(degrees, _degreesPerTurn);
    return wrapped < 0 ? add(wrapped, _degreesPerTurn) : wrapped;
  }

  /// Matches the compatibility harness's rotation normalization for a trace.
  ///
  /// It returns an angle in `[0, 360)` and converts either signed zero to
  /// positive zero. The latter is required before canonical trace encoding.
  static double normalizeRotationDegrees(double rotationDegrees) {
    final normalized = wrapDegrees(rotationDegrees);
    return normalized >= _degreesPerTurn || normalized == 0 ? 0 : normalized;
  }

  /// Matches `AiPathFollower.normalizeSignedDegrees` in the Kotlin reference.
  static double normalizeSignedDegrees(double degrees) {
    final wrapped = remainder(add(degrees, _halfTurnDegrees), _degreesPerTurn);
    final normalized = wrapped < 0 ? add(wrapped, _degreesPerTurn) : wrapped;
    return subtract(normalized, _halfTurnDegrees);
  }

  /// Reproduces `simulationTick.toFloat() * (1f / 60f)` for snapshots.
  static double elapsedSimulationTime(int simulationTick) {
    if (simulationTick < 0) {
      throw ArgumentError.value(
        simulationTick,
        'simulationTick',
        'must not be negative',
      );
    }
    return multiply(narrow(simulationTick.toDouble()), fixedDeltaSeconds);
  }

  /// Converts negative zero to the canonical positive zero used in traces.
  static double canonicalZero(double value) {
    final narrowed = narrow(value);
    return narrowed == 0 ? 0 : narrowed;
  }

  /// Reports whether [value] is IEEE-754 negative zero.
  static bool isNegativeZero(double value) => value == 0 && value.isNegative;

  /// Returns the IEEE-754 binary32 bit pattern used by Kotlin's `Float.toBits`.
  static int bits(double value) =>
      ByteData.sublistView(Float32List.fromList(<double>[narrow(value)]))
          .getUint32(0, Endian.host);

  static final double _degreesPerTurn = narrow(360);
  static final double _halfTurnDegrees = narrow(180);

  static double _narrowArithmeticResult(double value) => _round(value);

  static double _round(double value) =>
      Float32List.fromList(<double>[value]).single;
}
