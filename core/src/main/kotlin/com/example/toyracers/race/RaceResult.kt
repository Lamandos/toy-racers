package com.example.toyracers.race

data class RaceResult(
    val finishPosition: Int,
    val competitorCount: Int,
    val totalRaceTime: Float,
    val bestLapTime: Float?,
    val isNewRecord: Boolean = false,
)
