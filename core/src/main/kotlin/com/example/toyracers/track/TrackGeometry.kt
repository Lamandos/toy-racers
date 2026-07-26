package com.example.toyracers.track

data class TrackPoint(
    val x: Float,
    val y: Float,
)

data class TrackRectangle(
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
) {
    init {
        require(width > 0f) { "Rectangle width must be positive" }
        require(height > 0f) { "Rectangle height must be positive" }
    }

    val maxX: Float
        get() = x + width
    val maxY: Float
        get() = y + height

    fun contains(point: TrackPoint): Boolean =
        point.x in x..maxX && point.y in y..maxY

    fun contains(other: TrackRectangle): Boolean =
        other.x >= x &&
            other.y >= y &&
            other.maxX <= maxX &&
            other.maxY <= maxY
}

data class TrackSegment(
    val start: TrackPoint,
    val end: TrackPoint,
) {
    init {
        require(start != end) { "Segment endpoints must be different" }
    }
}
