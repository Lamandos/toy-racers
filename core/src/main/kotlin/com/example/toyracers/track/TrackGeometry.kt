package com.example.toyracers.track

import kotlin.math.hypot

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
        contains(point.x, point.y)

    fun contains(
        pointX: Float,
        pointY: Float,
    ): Boolean = pointX in x..maxX && pointY in y..maxY

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

/**
 * A horizontal stadium (a rectangle with semicircular ends), used for the oval road mask.
 */
data class TrackStadium(
    val centerY: Float,
    val leftCenterX: Float,
    val rightCenterX: Float,
    val radius: Float,
) {
    init {
        require(leftCenterX < rightCenterX) { "Stadium centers must be ordered" }
        require(radius > 0f) { "Stadium radius must be positive" }
    }

    fun contains(
        x: Float,
        y: Float,
    ): Boolean {
        val nearestX = x.coerceIn(leftCenterX, rightCenterX)
        return hypot(x - nearestX, y - centerY) <= radius
    }
}

/** Road area between the outer and inner edges of an oval track. */
data class StadiumRing(
    val outer: TrackStadium,
    val inner: TrackStadium,
) {
    init {
        require(outer.centerY == inner.centerY) { "Ring stadiums must share a center line" }
        require(outer.radius > inner.radius) { "Outer stadium must be larger than inner stadium" }
    }

    fun contains(
        x: Float,
        y: Float,
    ): Boolean = outer.contains(x, y) && !inner.contains(x, y)
}

sealed interface TrackCollisionShape

data class TrackCircle(
    val center: TrackPoint,
    val radius: Float,
) : TrackCollisionShape {
    init {
        require(radius > 0f) { "Circle radius must be positive" }
    }
}

/**
 * Convex collision contour. Vertices may be clockwise or counter-clockwise.
 */
data class TrackPolygon(
    val vertices: List<TrackPoint>,
) : TrackCollisionShape {
    init {
        require(vertices.size >= 3) { "Polygon must contain at least three vertices" }
    }

    fun contains(
        x: Float,
        y: Float,
    ): Boolean {
        var inside = false
        var previous = vertices.last()
        vertices.forEach { current ->
            if (
                (current.y > y) != (previous.y > y) &&
                x < (
                    (previous.x - current.x) * (y - current.y) /
                        (previous.y - current.y) + current.x
                    )
            ) {
                inside = !inside
            }
            previous = current
        }
        return inside
    }
}
