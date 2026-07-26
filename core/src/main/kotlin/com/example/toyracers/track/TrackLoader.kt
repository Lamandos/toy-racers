package com.example.toyracers.track

/** Supplies built-in track data until authored Tiled maps are introduced. */
class TrackLoader {
    fun load(trackId: String = ORIGINAL_TRACK_ID): Track {
        require(trackId == ORIGINAL_TRACK_ID) { "Unknown track: $trackId" }
        return createOriginalTrack()
    }

    private fun createOriginalTrack(): Track = Track(
        id = ORIGINAL_TRACK_ID,
        name = "Tabletop Loop",
        worldBounds = rectangle(0f, 0f, 42.67f, 24f),
        cameraBounds = rectangle(0f, 0f, 42.67f, 24f),
        outerBoundary = rectangle(4f, 3f, 34.67f, 18f),
        innerObstacles = listOf(
            rectangle(11f, 8.67f, 20.67f, 6.66f),
        ),
        backgroundSurface = SurfaceType.GRASS,
        surfaceRegions = listOf(
            SurfaceRegion(
                bounds = rectangle(4f, 3f, 34.67f, 18f),
                surface = SurfaceType.ASPHALT,
            ),
        ),
        startLine = StartLine(
            bounds = rectangle(20.33f, 3f, 0.54f, 5.67f),
            forwardX = 1f,
            forwardY = 0f,
        ),
        checkpoints = listOf(
            Checkpoint(
                order = 0,
                gate = segment(31.67f, 12f, 38.67f, 12f),
                forwardX = 0f,
                forwardY = 1f,
            ),
            Checkpoint(
                order = 1,
                gate = segment(20.5f, 15.33f, 20.5f, 21f),
                forwardX = -1f,
                forwardY = 0f,
            ),
            Checkpoint(
                order = 2,
                gate = segment(4f, 12f, 11f, 12f),
                forwardX = 0f,
                forwardY = -1f,
            ),
        ),
        startGrid = listOf(
            startPosition(18.2f, 5.6f),
            startPosition(14.5f, 7.1f),
            startPosition(10.8f, 5.6f),
            startPosition(7.1f, 7.1f),
        ),
        racingLine = listOf(
            point(7.5f, 6f),
            point(18f, 6f),
            point(30f, 6f),
            point(35f, 8f),
            point(35f, 16f),
            point(30f, 18.5f),
            point(13f, 18.5f),
            point(7.5f, 16f),
            point(7.5f, 9f),
        ),
    )

    private fun rectangle(
        x: Float,
        y: Float,
        width: Float,
        height: Float,
    ): TrackRectangle = TrackRectangle(x, y, width, height)

    private fun point(
        x: Float,
        y: Float,
    ): TrackPoint = TrackPoint(x, y)

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
        const val ORIGINAL_TRACK_ID = "tabletop-loop"
    }
}
