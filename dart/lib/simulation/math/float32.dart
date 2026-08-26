import 'dart:typed_data';

/// Explicit IEEE-754 binary32 operations used at the simulation boundary.
///
/// Dart numbers are binary64. Simulation code must use this utility whenever
/// the Kotlin reference performs a `Float` conversion or arithmetic operation.
final class Float32 {
  Float32._();

  /// Narrows [value] to a finite IEEE-754 binary32 value.
  static double narrow(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    final narrowed = Float32List.fromList(<double>[value]).single;
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
      narrow(narrow(left) - narrow(right));

  /// Multiplies two binary32 values and narrows the result to binary32.
  static double multiply(double left, double right) =>
      narrow(narrow(left) * narrow(right));

  /// Divides two binary32 values and narrows the result to binary32.
  static double divide(double dividend, double divisor) {
    final narrowedDivisor = narrow(divisor);
    if (narrowedDivisor == 0) {
      throw ArgumentError.value(divisor, 'divisor', 'must not be zero');
    }
    return narrow(narrow(dividend) / narrowedDivisor);
  }

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

  static double _narrowArithmeticResult(double value) =>
      Float32List.fromList(<double>[value]).single;
}
