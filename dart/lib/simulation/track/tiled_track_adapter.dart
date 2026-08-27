import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../math/float32.dart';
import 'track_geometry.dart';
import 'track_point.dart';

/// Reads Tiled geometry without depending on Flame or its Tiled adapter.
///
/// Tiled coordinates are image pixels with Y pointing down. The Kotlin
/// reference converts them into authored coordinates with Y pointing up,
/// then multiplies them by the configured world scale. Every Float operation
/// in that conversion is narrowed to binary32 here.
final class TiledTrackAdapter {
  TiledTrackAdapter({
    required double imageWidthPixels,
    required double imageHeightPixels,
    required double authoredWidth,
    required double worldScale,
  }) : imageWidthPixels = Float32.narrow(imageWidthPixels),
       imageHeightPixels = Float32.narrow(imageHeightPixels),
       authoredWidth = Float32.narrow(authoredWidth),
       worldScale = Float32.narrow(worldScale) {
    if (this.imageWidthPixels <= 0) {
      throw ArgumentError.value(
        imageWidthPixels,
        'imageWidthPixels',
        'must be positive',
      );
    }
    if (this.imageHeightPixels <= 0) {
      throw ArgumentError.value(
        imageHeightPixels,
        'imageHeightPixels',
        'must be positive',
      );
    }
    if (this.authoredWidth <= 0) {
      throw ArgumentError.value(
        authoredWidth,
        'authoredWidth',
        'must be positive',
      );
    }
    if (this.worldScale <= 0) {
      throw ArgumentError.value(worldScale, 'worldScale', 'must be positive');
    }
  }

  final double imageWidthPixels;
  final double imageHeightPixels;
  final double authoredWidth;
  final double worldScale;

  /// Parses the `collisions` and `road` object layers from canonical TMX text.
  TiledTrackObjects parse(String tmx) {
    final document = XmlDocument.parse(tmx);
    final imageLayer = _namedElement(
      document.findAllElements(_imageLayerTag),
      _trackImageLayerName,
      'image layer',
    );
    final imageOffsetX = _optionalFloatAttribute(imageLayer, 'offsetx');
    final imageOffsetY = _optionalFloatAttribute(imageLayer, 'offsety');
    final layers = <String, XmlElement>{
      for (final layer in document.findAllElements(_objectGroupTag))
        _attribute(layer, 'name'): layer,
    };
    final collisionLayer = layers[_collisionLayerName];
    if (collisionLayer == null) {
      throw StateError(
        "TMX map must contain a '$_collisionLayerName' object layer.",
      );
    }
    final collisionOffsetX = Float32.subtract(
      _optionalFloatAttribute(collisionLayer, 'offsetx'),
      imageOffsetX,
    );
    final collisionOffsetY = Float32.subtract(
      _optionalFloatAttribute(collisionLayer, 'offsety'),
      imageOffsetY,
    );
    final roadLayer = layers[_roadLayerName];
    if (roadLayer == null) {
      throw StateError(
        "TMX map must contain a '$_roadLayerName' object layer.",
      );
    }
    return TiledTrackObjects(
      collisionShapes: collisionLayer
          .findAllElements(_objectTag)
          .map(
            (object) =>
                _parseObject(object, collisionOffsetX, collisionOffsetY),
          ),
      roadOuter: _parseNamedPolygon(
        roadLayer,
        _roadOuterName,
        imageOffsetX,
        imageOffsetY,
      ),
      roadInner: _parseNamedPolygon(
        roadLayer,
        _roadInnerName,
        imageOffsetX,
        imageOffsetY,
      ),
    );
  }

  TrackPolygon _parseNamedPolygon(
    XmlElement layer,
    String objectName,
    double imageOffsetX,
    double imageOffsetY,
  ) {
    final object = _namedElement(
      layer.findAllElements(_objectTag),
      objectName,
      'road contour',
    );
    final shape = _parseObject(
      object,
      Float32.subtract(_optionalFloatAttribute(layer, 'offsetx'), imageOffsetX),
      Float32.subtract(_optionalFloatAttribute(layer, 'offsety'), imageOffsetY),
    );
    if (shape is! TrackPolygon) {
      throw StateError("Tiled road contour '$objectName' must be a polygon.");
    }
    return shape;
  }

  TrackCollisionShape _parseObject(
    XmlElement element,
    double layerOffsetX,
    double layerOffsetY,
  ) {
    final x = Float32.add(_floatAttribute(element, 'x'), layerOffsetX);
    final y = Float32.add(_floatAttribute(element, 'y'), layerOffsetY);
    final polygons = element.findAllElements(_polygonTag);
    if (polygons.isNotEmpty) {
      return TrackPolygon(_parsePolygonPoints(polygons.first, x, y));
    }
    if (element.findAllElements(_ellipseTag).isNotEmpty) {
      return _parseEllipse(element, x, y);
    }
    throw StateError(
      "Collision object '${_attribute(element, 'name')}' must be a polygon or ellipse.",
    );
  }

  Iterable<TrackPoint> _parsePolygonPoints(
    XmlElement polygon,
    double x,
    double y,
  ) sync* {
    final points = _attribute(polygon, 'points').trim();
    for (final point in points.split(RegExp(r'\s+'))) {
      final coordinates = point.split(',');
      if (coordinates.length != 2) {
        throw FormatException('Invalid Tiled polygon point: $point');
      }
      yield _toTrackPoint(
        Float32.add(x, _parseFloat(coordinates[0], 'polygon point x')),
        Float32.add(y, _parseFloat(coordinates[1], 'polygon point y')),
      );
    }
  }

  TrackCollisionShape _parseEllipse(XmlElement element, double x, double y) {
    final width = _floatAttribute(element, 'width');
    final height = _floatAttribute(element, 'height');
    if (Float32.subtract(width, height).abs() <= _circleTolerancePixels) {
      final halfWidth = Float32.divide(width, 2);
      return TrackCircle(
        center: _toTrackPoint(
          Float32.add(x, halfWidth),
          Float32.add(y, Float32.divide(height, 2)),
        ),
        radius: _pixelsToWorld(halfWidth),
      );
    }
    final halfWidth = Float32.divide(width, 2);
    final halfHeight = Float32.divide(height, 2);
    return TrackPolygon(
      List<TrackPoint>.generate(_ellipseSegments, (index) {
        final angle = math.pi * 2 * index / _ellipseSegments;
        return _toTrackPoint(
          Float32.add(
            Float32.add(x, halfWidth),
            Float32.multiply(Float32.narrow(math.cos(angle)), halfWidth),
          ),
          Float32.add(
            Float32.add(y, halfHeight),
            Float32.multiply(Float32.narrow(math.sin(angle)), halfHeight),
          ),
        );
      }),
    );
  }

  TrackPoint _toTrackPoint(double pixelX, double pixelY) => TrackPoint(
    _pixelsToWorld(pixelX),
    _pixelsToWorld(Float32.subtract(imageHeightPixels, pixelY)),
  );

  double _pixelsToWorld(double pixels) => Float32.multiply(
    Float32.multiply(Float32.divide(pixels, imageWidthPixels), authoredWidth),
    worldScale,
  );

  XmlElement _namedElement(
    Iterable<XmlElement> elements,
    String name,
    String elementType,
  ) {
    for (final element in elements) {
      if (_attribute(element, 'name') == name) {
        return element;
      }
    }
    throw StateError("TMX map must contain a '$name' $elementType.");
  }

  double _floatAttribute(XmlElement element, String name) {
    final value = element.getAttribute(name);
    if (value == null) {
      throw StateError("TMX object is missing numeric '$name'.");
    }
    return _parseFloat(value, name);
  }

  double _optionalFloatAttribute(XmlElement element, String name) =>
      _parseFloat(element.getAttribute(name) ?? '0', name);

  String _attribute(XmlElement element, String name) =>
      element.getAttribute(name) ?? '';

  double _parseFloat(String value, String name) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw FormatException("Invalid numeric '$name': $value");
    }
    return Float32.narrow(parsed);
  }

  static const String _collisionLayerName = 'collisions';
  static final double _circleTolerancePixels = Float32.narrow(0.01);
  static const int _ellipseSegments = 24;
  static const String _ellipseTag = 'ellipse';
  static const String _imageLayerTag = 'imagelayer';
  static const String _objectGroupTag = 'objectgroup';
  static const String _objectTag = 'object';
  static const String _polygonTag = 'polygon';
  static const String _roadInnerName = 'road_inner';
  static const String _roadLayerName = 'road';
  static const String _roadOuterName = 'road_outer';
  static const String _trackImageLayerName = 'track';
}

/// Geometry parsed from a Tiled map for one track definition.
final class TiledTrackObjects {
  TiledTrackObjects({
    required Iterable<TrackCollisionShape> collisionShapes,
    required this.roadOuter,
    required this.roadInner,
  }) : collisionShapes = List<TrackCollisionShape>.unmodifiable(
         collisionShapes,
       );

  final List<TrackCollisionShape> collisionShapes;
  final TrackPolygon roadOuter;
  final TrackPolygon roadInner;
}
