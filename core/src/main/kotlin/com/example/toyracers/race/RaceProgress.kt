package com.example.toyracers.race

/** Mutable race-rule state for one car. Times are measured in simulation seconds. */
data class RaceProgress(
    var currentCheckpointIndex: Int = 0,
    var completedLaps: Int = 0,
    var lapStartTime: Float = 0f,
    var bestLapTime: Float? = null,
    var totalRaceTime: Float = 0f,
    var finished: Boolean = false,
    var finishPosition: Int? = null,
)
