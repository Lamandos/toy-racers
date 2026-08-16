package com.example.toyracers.ui

/** Immutable presentation data consumed by the minimap. */
data class RaceMinimapSnapshot(
    val participants: List<MinimapParticipantSnapshot>,
)

data class MinimapParticipantSnapshot(
    val x: Float,
    val y: Float,
    val rotationDeg: Float,
    val role: MinimapParticipantRole,
)

enum class MinimapParticipantRole {
    PLAYER,
    OPPONENT,
}
