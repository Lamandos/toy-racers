import 'dart:collection';
import 'dart:convert';

import 'compatibility_exception.dart';

/// Decodes JSON without losing numeric text or silently accepting duplicate
/// object keys.
///
/// Compatibility documents contain signed 64-bit seeds, which must not pass
/// through a binary64 value on web targets.  The standard decoder also keeps
/// the last duplicate key, whereas the shared contract treats duplicates as
/// invalid input.
CompatibilityJsonValue readCompatibilityJson(String source) {
  final reader = _StrictJsonReader(source);
  final value = reader.readValue();
  reader.skipWhitespace();
  if (!reader.isAtEnd) {
    reader.fail('Unexpected trailing content');
  }
  return value;
}

sealed class CompatibilityJsonValue {
  const CompatibilityJsonValue();
}

final class CompatibilityJsonObject extends CompatibilityJsonValue {
  CompatibilityJsonObject(Map<String, CompatibilityJsonValue> values)
    : values = UnmodifiableMapView<String, CompatibilityJsonValue>(values);

  final Map<String, CompatibilityJsonValue> values;
}

final class CompatibilityJsonArray extends CompatibilityJsonValue {
  CompatibilityJsonArray(List<CompatibilityJsonValue> values)
    : values = List<CompatibilityJsonValue>.unmodifiable(values);

  final List<CompatibilityJsonValue> values;
}

final class CompatibilityJsonString extends CompatibilityJsonValue {
  const CompatibilityJsonString(this.value);

  final String value;
}

final class CompatibilityJsonNumber extends CompatibilityJsonValue {
  const CompatibilityJsonNumber(this.literal);

  final String literal;

  /// Returns an exact integer when this JSON number has no fractional value.
  ///
  /// JSON Schema considers values such as `1.0` and `1e3` integers.  This
  /// method keeps that behaviour without converting a seed through `double`.
  BigInt? get integralValue {
    final match = _numberPattern.firstMatch(literal);
    if (match == null) {
      return null;
    }
    final negative = match.group(1) == '-';
    final integerPart = match.group(2)!;
    final fractionalPart = match.group(3) ?? '';
    final exponentText = match.group(4);
    final exponent = exponentText == null ? 0 : int.tryParse(exponentText);
    final digits = '$integerPart$fractionalPart';
    final significant = digits.replaceFirst(RegExp(r'^0+'), '');
    if (significant.isEmpty) {
      return BigInt.zero;
    }
    if (exponent == null || exponent.abs() > _maximumSupportedExponent) {
      return null;
    }
    final decimalPlaces = fractionalPart.length - exponent;
    if (decimalPlaces > 0) {
      final requiredZeroes = decimalPlaces;
      if (digits.length < requiredZeroes ||
          digits
              .substring(digits.length - requiredZeroes)
              .contains(RegExp(r'[^0]'))) {
        return null;
      }
      return _signed(
        BigInt.parse(digits.substring(0, digits.length - requiredZeroes)),
        negative,
      );
    }
    final value = BigInt.parse(digits) * BigInt.from(10).pow(-decimalPlaces);
    return _signed(value, negative);
  }

  double? get finiteDouble {
    final value = double.tryParse(literal);
    return value != null && value.isFinite ? value : null;
  }

  static BigInt _signed(BigInt value, bool negative) =>
      negative ? -value : value;

  static const int _maximumSupportedExponent = 1000;
  static final RegExp _numberPattern = RegExp(
    r'^(-)?(0|[1-9][0-9]*)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$',
  );
}

final class CompatibilityJsonBoolean extends CompatibilityJsonValue {
  const CompatibilityJsonBoolean(this.value);

  final bool value;
}

final class CompatibilityJsonNull extends CompatibilityJsonValue {
  const CompatibilityJsonNull();
}

final class _StrictJsonReader {
  _StrictJsonReader(this.source);

  final String source;
  var _index = 0;

  bool get isAtEnd => _index >= source.length;

  CompatibilityJsonValue readValue() {
    skipWhitespace();
    if (isAtEnd) {
      fail('Expected a JSON value');
    }
    return switch (source.codeUnitAt(_index)) {
      _objectStart => _readObject(),
      _arrayStart => _readArray(),
      _quote => CompatibilityJsonString(_readString()),
      _minus || >= _zero && <= _nine => _readNumber(),
      _lowercaseT => _readLiteral('true', const CompatibilityJsonBoolean(true)),
      _lowercaseF => _readLiteral(
        'false',
        const CompatibilityJsonBoolean(false),
      ),
      _lowercaseN => _readLiteral('null', const CompatibilityJsonNull()),
      _ => fail('Expected a JSON value'),
    };
  }

  void skipWhitespace() {
    while (!isAtEnd && _isWhitespace(source.codeUnitAt(_index))) {
      _index++;
    }
  }

  Never fail(String message) {
    throw CompatibilityFormatException(r'$', '$message at character $_index');
  }

  CompatibilityJsonObject _readObject() {
    _index++;
    skipWhitespace();
    final values = <String, CompatibilityJsonValue>{};
    if (_takeIf(_objectEnd)) {
      return CompatibilityJsonObject(values);
    }
    while (true) {
      skipWhitespace();
      if (isAtEnd || source.codeUnitAt(_index) != _quote) {
        fail('Expected an object key');
      }
      final key = _readString();
      if (values.containsKey(key)) {
        fail('Duplicate object key "$key"');
      }
      skipWhitespace();
      _expect(_colon, 'Expected ":" after object key');
      final value = readValue();
      values[key] = value;
      skipWhitespace();
      if (_takeIf(_objectEnd)) {
        return CompatibilityJsonObject(values);
      }
      _expect(_comma, 'Expected "," or "}" in object');
    }
  }

  CompatibilityJsonArray _readArray() {
    _index++;
    skipWhitespace();
    final values = <CompatibilityJsonValue>[];
    if (_takeIf(_arrayEnd)) {
      return CompatibilityJsonArray(values);
    }
    while (true) {
      values.add(readValue());
      skipWhitespace();
      if (_takeIf(_arrayEnd)) {
        return CompatibilityJsonArray(values);
      }
      _expect(_comma, 'Expected "," or "]" in array');
    }
  }

  CompatibilityJsonNumber _readNumber() {
    final start = _index;
    _takeIf(_minus);
    if (_takeIf(_zero)) {
      if (!isAtEnd && _isDigit(source.codeUnitAt(_index))) {
        fail('A JSON number cannot have a leading zero');
      }
    } else {
      _requireDigits('Expected a digit in number');
    }
    if (_takeIf(_period)) {
      _requireDigits('Expected digits after decimal point');
    }
    if (!isAtEnd && _isExponentMarker(source.codeUnitAt(_index))) {
      _index++;
      if (!isAtEnd && _isSign(source.codeUnitAt(_index))) {
        _index++;
      }
      _requireDigits('Expected exponent digits');
    }
    return CompatibilityJsonNumber(source.substring(start, _index));
  }

  CompatibilityJsonValue _readLiteral(
    String literal,
    CompatibilityJsonValue value,
  ) {
    if (!source.startsWith(literal, _index)) {
      fail('Expected "$literal"');
    }
    _index += literal.length;
    return value;
  }

  String _readString() {
    final start = _index;
    _index++;
    while (!isAtEnd) {
      final codeUnit = source.codeUnitAt(_index);
      if (codeUnit < _space) {
        fail('Unescaped control character in string');
      }
      _index++;
      if (codeUnit == _quote) {
        final literal = source.substring(start, _index);
        try {
          return jsonDecode(literal) as String;
        } on FormatException {
          fail('Invalid JSON string');
        }
      }
      if (codeUnit == _backslash) {
        if (isAtEnd) {
          fail('Unterminated string escape');
        }
        _index++;
      }
    }
    fail('Unterminated JSON string');
  }

  void _expect(int expected, String message) {
    if (!_takeIf(expected)) {
      fail(message);
    }
  }

  bool _takeIf(int expected) {
    if (!isAtEnd && source.codeUnitAt(_index) == expected) {
      _index++;
      return true;
    }
    return false;
  }

  void _requireDigits(String message) {
    if (isAtEnd || !_isDigit(source.codeUnitAt(_index))) {
      fail(message);
    }
    while (!isAtEnd && _isDigit(source.codeUnitAt(_index))) {
      _index++;
    }
  }

  static bool _isWhitespace(int value) =>
      value == _space ||
      value == _tab ||
      value == _lineFeed ||
      value == _carriageReturn;

  static bool _isDigit(int value) => value >= _zero && value <= _nine;

  static bool _isExponentMarker(int value) =>
      value == _lowercaseE || value == _uppercaseE;

  static bool _isSign(int value) => value == _plus || value == _minus;

  static const int _arrayEnd = 0x5D;
  static const int _arrayStart = 0x5B;
  static const int _backslash = 0x5C;
  static const int _carriageReturn = 0x0D;
  static const int _colon = 0x3A;
  static const int _comma = 0x2C;
  static const int _lineFeed = 0x0A;
  static const int _lowercaseE = 0x65;
  static const int _lowercaseF = 0x66;
  static const int _lowercaseN = 0x6E;
  static const int _lowercaseT = 0x74;
  static const int _minus = 0x2D;
  static const int _nine = 0x39;
  static const int _objectEnd = 0x7D;
  static const int _objectStart = 0x7B;
  static const int _period = 0x2E;
  static const int _plus = 0x2B;
  static const int _quote = 0x22;
  static const int _space = 0x20;
  static const int _tab = 0x09;
  static const int _uppercaseE = 0x45;
  static const int _zero = 0x30;
}
