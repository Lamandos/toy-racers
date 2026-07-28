package com.example.toyracers.track

import java.io.InputStream

/** Supplies the built-in track authored against the track_01 background image. */
class TrackLoader {
    fun load(
        trackId: String = TRACK_01_ID,
        collisionMap: InputStream = classpathCollisionMap(),
    ): Track {
        require(trackId == TRACK_01_ID) { "Unknown track: $trackId" }
        val tiledObjects = collisionMap.use(TILED_COLLISION_LOADER::loadTrackObjects)
        return createTrack01(tiledObjects)
    }

    private fun createTrack01(tiledObjects: TiledTrackObjects): Track = Track(
        id = TRACK_01_ID,
        name = "Living Room Oval",
        worldBounds = rectangle(0f, 0f, 36f, 24f),
        cameraBounds = rectangle(0f, 0f, 36f, 24f),
        outerBoundary = rectangle(0f, 0f, 36f, 24f),
        innerObstacles = emptyList(),
        collisionShapes = tiledObjects.collisionShapes,
        backgroundSurface = SurfaceType.PARQUET,
        surfaceRegions = emptyList(),
        roadOuter = tiledObjects.roadOuter,
        roadInner = tiledObjects.roadInner,
        startLine = StartLine(
            bounds = rectangle(20.5f, 3.5f, 0.25f, 3.7f),
            forwardX = 1f,
            forwardY = 0f,
        ),
        checkpoints = listOf(
            Checkpoint(
                order = 0,
                gate = segment(23.8f, 12f, 35f, 12f),
                forwardX = 0f,
                forwardY = 1f,
            ),
            Checkpoint(
                order = 1,
                gate = segment(20.5f, 16.5f, 20.5f, 20.5f),
                forwardX = -1f,
                forwardY = 0f,
            ),
            Checkpoint(
                order = 2,
                gate = segment(1.1f, 12f, 12.3f, 12f),
                forwardX = 0f,
                forwardY = -1f,
            ),
        ),
        startGrid = listOf(
            startPosition(16.5f, 5.2f),
            startPosition(14.0f, 5.7f),
            startPosition(11.5f, 5.2f),
            startPosition(9.0f, 5.7f),
        ),
        racingLine = listOf(
            point(12f, 5.5f),
            point(15f, 5.75f),
            point(18f, 5.75f),
            point(21f, 5.75f),
            point(23.8f, 5.75f),
            point(25.4f, 5.96f),
            point(26.9f, 6.59f),
            point(28.2f, 7.58f),
            point(29.2f, 8.88f),
            point(29.8f, 10.38f),
            point(30.05f, 12f),
            point(29.8f, 13.62f),
            point(29.2f, 15.12f),
            point(28.2f, 16.42f),
            point(26.9f, 17.41f),
            point(25.4f, 18.04f),
            point(23.8f, 18.25f),
            point(21f, 18.25f),
            point(18f, 18.25f),
            point(15f, 18.25f),
            point(12.3f, 18.25f),
            point(10.7f, 18.04f),
            point(9.2f, 17.41f),
            point(7.9f, 16.42f),
            point(6.9f, 15.12f),
            point(6.3f, 13.62f),
            point(6.05f, 12f),
            point(6.3f, 10.38f),
            point(6.9f, 8.88f),
            point(7.9f, 7.58f),
            point(9.2f, 6.59f),
            point(10.7f, 5.96f),
        ),
        racingLineWaypointRadius = 10f,
    )

    private fun rectangle(
        x: Float,
        y: Float,
        width: Float,
        height: Float,
    ): TrackRectangle = TrackRectangle(scale(x), scale(y), scale(width), scale(height))

    private fun point(
        x: Float,
        y: Float,
    ): TrackPoint = TrackPoint(scale(x), scale(y))

    private fun scale(value: Float): Float = value * MAP_SCALE

    private fun segment(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
    ): TrackSegment = TrackSegment(point(startX, startY), point(endX, endY))

    private fun startPosition(
        x: Float,
        y: Float,
    ): StartGridPosition = StartGridPosition(
        position = point(x, y),
        rotationDeg = 0f,
    )

    companion object {
        const val TRACK_01_ID = "track-01"
        const val MAP_SCALE = 3f
        const val TRACK_01_TMX = "tracks/track_01.tmx"
        private val TILED_COLLISION_LOADER = TiledCollisionLoader(
            imageWidthPixels = 1536f,
            imageHeightPixels = 1024f,
            authoredWidth = 36f,
            worldScale = MAP_SCALE,
        )

        private fun classpathCollisionMap(): InputStream =
            requireNotNull(TrackLoader::class.java.classLoader?.getResourceAsStream(TRACK_01_TMX)) {
                "Missing Tiled collision map: $TRACK_01_TMX"
            }
    }
}
