package com.example.toyracers.compat

internal data class BehavioralTrace(
    val scenarioId: String,
    val seed: Long,
    val samples: List<BehavioralTraceSample>,
)

internal data class BehavioralTraceSample(
    val label: String,
    val tick: Int,
    val snapshot: BehavioralSnapshot,
)

internal class BehavioralScenarioRunner {
    fun run(scenario: BehavioralScenario): BehavioralTrace {
        val harness =
            BehavioralCompatibilityHarness(
                BehavioralRaceConfiguration(
                    seed = scenario.seed,
                    trackId = scenario.trackId,
                    playerCar = scenario.playerCar,
                ),
            )
        val samples = mutableListOf<BehavioralTraceSample>()
        harness.setInitialStates(scenario.initialStates)
        samples += BehavioralTraceSample("countdown", 0, harness.start())
        samples += BehavioralTraceSample("racing", 0, harness.finishCountdown())
        addSimulationSamples(harness, scenario, samples)
        return BehavioralTrace(scenario.id, scenario.seed, samples)
    }

    private fun addSimulationSamples(
        harness: BehavioralCompatibilityHarness,
        scenario: BehavioralScenario,
        samples: MutableList<BehavioralTraceSample>,
    ) {
        var inputSegmentIndex = 0
        (1..scenario.ticks).forEach { tick ->
            inputSegmentIndex = scenario.nextInputSegmentIndex(inputSegmentIndex, tick)
            val snapshot = harness.advance(scenario.inputAt(tick, inputSegmentIndex))
            val shouldSample =
                tick == 1 ||
                    tick % scenario.snapshotIntervalTicks == 0 ||
                    tick == scenario.ticks ||
                    snapshot.phase == "finished"
            if (shouldSample) {
                samples += BehavioralTraceSample("simulation", tick, snapshot)
            }
            if (snapshot.phase == "finished") return
        }
    }

    private fun BehavioralScenario.nextInputSegmentIndex(
        currentIndex: Int,
        tick: Int,
    ): Int {
        var nextIndex = currentIndex
        while (nextIndex < inputSegments.lastIndex && inputSegments[nextIndex].toTick < tick) {
            nextIndex++
        }
        return nextIndex
    }

    private fun BehavioralScenario.inputAt(
        tick: Int,
        segmentIndex: Int,
    ): BehavioralInput = inputSegments[segmentIndex].takeIf { it.contains(tick) }?.input ?: BehavioralInput()
}
