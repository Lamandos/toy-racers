package com.example.toyracers.ui

import com.example.toyracers.track.TrackRectangle
import kotlin.math.min

/** Aspect-preserving mapping from world coordinates into minimap-local coordinates. */
class MinimapTransform(
    private val worldBounds: TrackRectangle,
    widgetWidth: Float,
    widgetHeight: Float,
    private val padding: Float,
) {
    init {
        require(widgetWidth > padding * 2f) { "Minimap width must exceed its padding" }
        require(widgetHeight > padding * 2f) { "Minimap height must exceed its padding" }
    }

    private val scale =
        min(
            (widgetWidth - padding * 2f) / worldBounds.width,
            (widgetHeight - padding * 2f) / worldBounds.height,
        )
    private val contentWidth = worldBounds.width * scale
    private val contentHeight = worldBounds.height * scale
    private val offsetX = (widgetWidth - contentWidth) / 2f
    private val offsetY = (widgetHeight - contentHeight) / 2f

    fun mapX(worldX: Float): Float =
        offsetX + (worldX.coerceIn(worldBounds.x, worldBounds.maxX) - worldBounds.x) * scale

    fun mapY(worldY: Float): Float =
        offsetY + (worldY.coerceIn(worldBounds.y, worldBounds.maxY) - worldBounds.y) * scale
}
