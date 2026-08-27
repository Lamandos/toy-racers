/// The simulation surfaces defined by the shared compatibility schema.
enum SurfaceType { asphalt, parquet, tile, grass, boost, oil }

/// Reference-defined driving semantics for each [SurfaceType].
///
/// This mapping is part of the compatibility contract. It intentionally does
/// not derive road status from a surface name, track geometry, or styling.
extension SurfaceTypeRoadStatus on SurfaceType {
  bool get isRoad => switch (this) {
    SurfaceType.asphalt || SurfaceType.boost || SurfaceType.oil => true,
    SurfaceType.parquet || SurfaceType.tile || SurfaceType.grass => false,
  };
}
