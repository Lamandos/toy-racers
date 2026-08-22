package com.example.toyracers.compat

/** Versioned, device-independent input for one headless simulation replay. */
internal data class BehavioralScenario(
    val id: String,
    val seed: Long,
    val trackId: String,
    val playerCar: String,
    val inputOrigin: String,
    val tags: Set<String>,
    val ticks: Int,
    val snapshotIntervalTicks: Int,
    val inputSegments: List<BehavioralInputSegment>,
    val initialStates: List<BehavioralInitialState>,
    val fullRace: Boolean,
)

/** A normalized player input held across an inclusive range of physical simulation ticks. */
internal data class BehavioralInputSegment(
    val fromTick: Int,
    val toTick: Int,
    val input: BehavioralInput,
) {
    fun contains(tick: Int): Boolean = tick in fromTick..toTick
}
