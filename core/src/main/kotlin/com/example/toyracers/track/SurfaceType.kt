package com.example.toyracers.track

/** Surface categories consumed by rendering now and driving physics later. */
enum class SurfaceType {
    ASPHALT,
    PARQUET,
    TILE,
    GRASS,
    BOOST,
    OIL,
    ;

    val isRoad: Boolean
        get() = this == ASPHALT || this == BOOST || this == OIL
}
