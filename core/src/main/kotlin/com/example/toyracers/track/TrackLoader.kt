package com.example.toyracers.track

import java.io.InputStream

/** Supplies immutable simulation data for the built-in tracks. */
class TrackLoader {
    fun load(
        trackId: TrackId = TrackId.LIVING_ROOM,
        collisionMap: InputStream = classpathCollisionMap(trackId),
    ): Track {
        val tiledObjects = collisionMap.use(loaderFor(trackId)::loadTrackObjects)
        return when (trackId) {
            TrackId.LIVING_ROOM -> createTrack01(tiledObjects)
            TrackId.BATHROOM -> createTrack02(tiledObjects)
        }
    }

    /** Compatibility overload for callers that persist the original string identifiers. */
    fun load(
        trackId: String,
        collisionMap: InputStream = classpathCollisionMap(TrackId.fromValue(trackId)),
    ): Track = load(TrackId.fromValue(trackId), collisionMap)

    private fun createTrack01(tiledObjects: TiledTrackObjects): Track = Track(
        id = TrackId.LIVING_ROOM.value,
        name = TrackId.LIVING_ROOM.displayName,
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
            bounds = rectangle(18.1f, 3.8f, 0.6f, 3.2f),
            forwardX = 1f,
            forwardY = 0f,
        ),
        checkpoints = listOf(
            Checkpoint(0, segment(23.8f, 12f, 35f, 12f), 0f, 1f),
            Checkpoint(1, segment(20.5f, 16.5f, 20.5f, 20.5f), -1f, 0f),
            Checkpoint(2, segment(1.1f, 12f, 12.3f, 12f), 0f, -1f),
        ),
        startGrid = listOf(
            startPosition(16.5f, 5.2f),
            startPosition(14.0f, 5.7f),
            startPosition(11.5f, 5.2f),
            startPosition(9.0f, 5.7f),
            startPosition(9.0f, 6.9f),
            startPosition(9.0f, 7.3f),
        ),
        racingLine = OVAL_RACING_LINE.map { point(it.first, it.second) },
        racingLineWaypointRadius = 10f,
    )

    private fun createTrack02(tiledObjects: TiledTrackObjects): Track = Track(
        id = TrackId.BATHROOM.value,
        name = TrackId.BATHROOM.displayName,
        worldBounds = rectangle(0f, 0f, 36f, 36f),
        cameraBounds = rectangle(0f, 0f, 36f, 36f),
        outerBoundary = rectangle(0f, 0f, 36f, 36f),
        innerObstacles = emptyList(),
        collisionShapes = tiledObjects.collisionShapes,
        backgroundSurface = SurfaceType.TILE,
        surfaceRegions = emptyList(),
        roadOuter = tiledObjects.roadOuter,
        roadInner = tiledObjects.roadInner,
        startLine = StartLine(
            bounds = rectangle(16.6f, 4.2f, 0.8f, 2.6f),
            forwardX = 1f,
            forwardY = 0f,
        ),
        checkpoints = listOf(
            Checkpoint(0, segment(24.0f, 12.5f, 30.5f, 12.5f), 0f, 1f),
            Checkpoint(1, segment(19.2f, 27.2f, 19.2f, 32.3f), -1f, 0f),
            Checkpoint(2, segment(5.1f, 20.2f, 10.2f, 20.2f), 0f, -1f),
            Checkpoint(3, segment(13.0f, 12.0f, 17.4f, 12.0f), 0f, -1f),
            Checkpoint(4, segment(8.0f, 6.5f, 8.0f, 10.3f), 1f, 0f),
        ),
        startGrid = listOf(
            startPosition(15.5f, 5.3f),
            startPosition(13.5f, 5.7f),
            startPosition(11.5f, 5.3f),
            startPosition(10.5f, 5.7f),
            startPosition(10.5f, 6.9f),
            startPosition(10.5f, 7.3f),
        ),
        racingLine = BATHROOM_RACING_LINE.map { point(it.first, it.second) },
        racingLineWaypointRadius = 7f,
    )

    private fun loaderFor(trackId: TrackId): TiledCollisionLoader =
        when (trackId) {
            TrackId.LIVING_ROOM -> TiledCollisionLoader(1536f, 1024f, 36f, MAP_SCALE)
            TrackId.BATHROOM -> TiledCollisionLoader(1254f, 1254f, 36f, MAP_SCALE)
        }

    private fun rectangle(x: Float, y: Float, width: Float, height: Float): TrackRectangle =
        TrackRectangle(scale(x), scale(y), scale(width), scale(height))

    private fun point(x: Float, y: Float): TrackPoint = TrackPoint(scale(x), scale(y))

    private fun scale(value: Float): Float = value * MAP_SCALE

    private fun segment(startX: Float, startY: Float, endX: Float, endY: Float): TrackSegment =
        TrackSegment(point(startX, startY), point(endX, endY))

    private fun startPosition(x: Float, y: Float): StartGridPosition =
        StartGridPosition(position = point(x, y), rotationDeg = 0f)

    companion object {
        const val TRACK_01_ID = "track-01"
        const val TRACK_02_ID = "track-02"
        const val MAP_SCALE = 3f
        const val TRACK_01_TMX = "tracks/track_01.tmx"
        const val TRACK_02_TMX = "tracks/track_02.tmx"

        fun tmxPath(trackId: TrackId): String =
            when (trackId) {
                TrackId.LIVING_ROOM -> TRACK_01_TMX
                TrackId.BATHROOM -> TRACK_02_TMX
            }

        private fun classpathCollisionMap(trackId: TrackId): InputStream {
            val path = tmxPath(trackId)
            return requireNotNull(TrackLoader::class.java.classLoader?.getResourceAsStream(path)) {
                "Missing Tiled collision map: $path"
            }
        }

        private val OVAL_RACING_LINE = listOf(
            12f to 5.5f, 15f to 5.75f, 18f to 5.75f, 21f to 5.75f,
            23.8f to 5.75f, 25.4f to 5.96f, 26.9f to 6.59f, 28.2f to 7.58f,
            29.2f to 8.88f, 29.8f to 10.38f, 30.05f to 12f, 29.8f to 13.62f,
            29.2f to 15.12f, 28.2f to 16.42f, 26.9f to 17.41f, 25.4f to 18.04f,
            23.8f to 18.25f, 21f to 18.25f, 18f to 18.25f, 15f to 18.25f,
            12.3f to 18.25f, 10.7f to 18.04f, 9.2f to 17.41f, 7.9f to 16.42f,
            6.9f to 15.12f, 6.3f to 13.62f, 6.05f to 12f, 6.3f to 10.38f,
            6.9f to 8.88f, 7.9f to 7.58f, 9.2f to 6.59f, 10.7f to 5.96f,
        )

        private val BATHROOM_RACING_LINE = listOf(
            17.2f to 5.3f, 21.5f to 5.3f, 24.5f to 6.4f, 26.0f to 9.3f,
            26.0f to 12.5f, 28.0f to 14.5f, 29.0f to 17.5f, 27.5f to 21.5f,
            27.0f to 25.5f, 24.0f to 28.5f, 20.5f to 29.2f, 18.5f to 31.0f,
            15.0f to 31.5f, 11.5f to 30.0f, 10.0f to 26.8f, 9.5f to 25.7f,
            6.0f to 22.0f, 5.2f to 21.1f, 6.3f to 19.6f, 10.5f to 16.0f,
            11.5f to 19.9f, 13.8f to 21.7f, 19.0f to 24.0f, 21.2f to 23.0f,
            22.0f to 20.0f, 20.5f to 16.8f, 17.0f to 13.0f, 17.2f to 9.0f,
            16.4f to 8.4f, 14.9f to 8.2f, 13.5f to 9.0f, 13.2f to 12.0f,
            11.5f to 15.0f, 8.5f to 16.0f, 6.2f to 14.0f, 6.0f to 10.5f,
            8.0f to 7.5f, 11.0f to 5.8f, 14.0f to 5.3f,
        )
    }
}
