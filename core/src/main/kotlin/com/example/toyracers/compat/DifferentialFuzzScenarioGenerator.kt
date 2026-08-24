package com.example.toyracers.compat

/** Creates fully materialized, deterministic input scenarios for cross-runtime fuzzing. */
internal object DifferentialFuzzScenarioGenerator {
    fun generate(
        seed: Long,
        ticks: Int,
    ): BehavioralScenario {
        require(ticks > 0) { "Differential fuzz tick count must be positive" }
        val random = InputRandom(seed)
        return BehavioralScenario(
            id = "differential-fuzz-seed-${seed.toULong()}",
            seed = seed,
            trackId = TRACK_ID,
            playerCar = PLAYER_CAR,
            inputOrigin = INPUT_ORIGIN,
            tags = setOf(TAG),
            ticks = ticks,
            snapshotIntervalTicks = minOf(DEFAULT_SNAPSHOT_INTERVAL_TICKS, ticks),
            inputSegments =
                (1..ticks).map { tick ->
                    BehavioralInputSegment(
                        fromTick = tick,
                        toTick = tick,
                        input = random.nextInput(),
                    )
                },
            initialStates = emptyList(),
            fullRace = false,
        )
    }

    private class InputRandom(
        seed: Long,
    ) {
        private var state = seed.toInt() xor (seed ushr SEED_HALF_BITS).toInt()

        fun nextInput(): BehavioralInput =
            BehavioralInput(
                throttle = nextUnitControl(),
                brake = nextUnitControl(),
                steering = nextSteering(),
            )

        private fun nextUnitControl(): Float =
            (nextUnsignedValue() % UNIT_CONTROL_VALUE_COUNT).toFloat() / COMMAND_SCALE

        private fun nextSteering(): Float =
            (nextUnsignedValue() % STEERING_CONTROL_VALUE_COUNT - STEERING_OFFSET).toFloat() / COMMAND_SCALE

        private fun nextUnsignedValue(): Long {
            state = state * MULTIPLIER + INCREMENT
            return state.toUInt().toLong()
        }
    }

    private const val TRACK_ID = "track-01"
    private const val PLAYER_CAR = "red-stripe"
    private const val INPUT_ORIGIN = "keyboard"
    private const val TAG = "differential-fuzz"
    private const val DEFAULT_SNAPSHOT_INTERVAL_TICKS = 60
    private const val SEED_HALF_BITS = 32
    private const val MULTIPLIER = 1_664_525
    private const val INCREMENT = 1_013_904_223
    private const val UNIT_CONTROL_VALUE_COUNT = 1_000_001L
    private const val STEERING_CONTROL_VALUE_COUNT = 2_000_001L
    private const val STEERING_OFFSET = 1_000_000L
    private const val COMMAND_SCALE = 1_000_000f
}
