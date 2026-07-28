package com.example.toyracers.track

/** Immutable data needed to simulate and draw one race track. */
data class Track(
    val id: String,
    val name: String,
    val worldBounds: TrackRectangle,
    val cameraBounds: TrackRectangle,
    val outerBoundary: TrackRectangle,
    val innerObstacles: List<TrackRectangle>,
    val collisionShapes: List<TrackCollisionShape> = emptyList(),
    val backgroundSurface: SurfaceType,
    val surfaceRegions: List<SurfaceRegion>,
    val roadRegion: StadiumRing? = null,
    val roadOuter: TrackPolygon? = null,
    val roadInner: TrackPolygon? = null,
    val startLine: StartLine,
    val checkpoints: List<Checkpoint>,
    val startGrid: List<StartGridPosition>,
    val racingLine: List<TrackPoint>,
    val racingLineWaypointRadius: Float = 3f,
) {
    init {
        require(id.isNotBlank()) { "Track id must not be blank" }
        require(name.isNotBlank()) { "Track name must not be blank" }
        require(worldBounds.contains(cameraBounds)) {
            "Camera bounds must be inside world bounds"
        }
        require(worldBounds.contains(outerBoundary)) {
            "Outer boundary must be inside world bounds"
        }
        require(innerObstacles.all(outerBoundary::contains)) {
            "Inner obstacles must be inside the outer boundary"
        }
        require(surfaceRegions.all { worldBounds.contains(it.bounds) }) {
            "Surface regions must be inside world bounds"
        }
        require(innerObstacles.all(worldBounds::contains)) {
            "Collision obstacles must be inside world bounds"
        }
        require(outerBoundary.contains(startLine.bounds)) {
            "Start line must be inside the outer boundary"
        }
        require(checkpoints.isNotEmpty()) { "Track must have checkpoints" }
        require(checkpoints.map(Checkpoint::order) == checkpoints.indices.toList()) {
            "Checkpoints must be ordered and use contiguous indices"
        }
        require(
            checkpoints.all {
                worldBounds.contains(it.gate.start) && worldBounds.contains(it.gate.end)
            },
        ) {
            "Checkpoint gates must be inside world bounds"
        }
        require(startGrid.isNotEmpty()) { "Track must have start positions" }
        require(startGrid.all { worldBounds.contains(it.position) }) {
            "Start positions must be inside world bounds"
        }
        require(racingLine.size >= MIN_RACING_LINE_POINTS) {
            "Racing line must contain at least $MIN_RACING_LINE_POINTS points"
        }
        require(racingLine.all(worldBounds::contains)) {
            "Racing line must be inside world bounds"
        }
        require(racingLineWaypointRadius > 0f) {
            "Racing line waypoint radius must be positive"
        }
        require((roadOuter == null) == (roadInner == null)) {
            "Tiled road contours must be provided together"
        }
    }

    fun surfaceAt(point: TrackPoint): SurfaceType {
        return surfaceAt(point.x, point.y)
    }

    fun surfaceAt(
        x: Float,
        y: Float,
    ): SurfaceType {
        if (innerObstacles.any { it.contains(x, y) }) {
            return backgroundSurface
        }
        val insideTiledRoad =
            roadOuter?.contains(x, y) == true && roadInner?.contains(x, y) == false
        if (insideTiledRoad || roadRegion?.contains(x, y) == true) {
            return SurfaceType.ASPHALT
        }
        return surfaceRegions.lastOrNull { it.bounds.contains(x, y) }?.surface
            ?: backgroundSurface
    }

    private companion object {
        const val MIN_RACING_LINE_POINTS = 3
    }
}

data class SurfaceRegion(
    val bounds: TrackRectangle,
    val surface: SurfaceType,
)

data class StartLine(
    val bounds: TrackRectangle,
    val forwardX: Float,
    val forwardY: Float,
) {
    init {
        require(forwardX != 0f || forwardY != 0f) {
            "Start line forward direction must not be zero"
        }
    }
}
