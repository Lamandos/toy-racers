package com.example.toyracers.compat

import com.example.toyracers.car.CarPhysics

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

internal class BehavioralScenarioRunner(
    private val continueAfterFinish: Boolean = false,
) {
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
        addStartSamples(harness, scenario, samples)
        addSimulationSamples(harness, scenario, samples)
        return BehavioralTrace(scenario.id, scenario.seed, samples)
    }

    private fun addStartSamples(
        harness: BehavioralCompatibilityHarness,
        scenario: BehavioralScenario,
        samples: MutableList<BehavioralTraceSample>,
    ) {
        if (LIFECYCLE_TAG in scenario.tags) {
            addLifecycleSamples(harness, samples)
        } else {
            samples += BehavioralTraceSample(COUNTDOWN_LABEL, 0, harness.start())
            samples += BehavioralTraceSample(RACING_LABEL, 0, harness.finishCountdown())
        }
    }

    private fun addLifecycleSamples(
        harness: BehavioralCompatibilityHarness,
        samples: MutableList<BehavioralTraceSample>,
    ) {
        samples += BehavioralTraceSample("loading", 0, harness.snapshot())
        samples += BehavioralTraceSample("ready", 0, harness.markReadyForLifecycle())
        samples += BehavioralTraceSample(COUNTDOWN_LABEL, 0, harness.startCountdownForLifecycle())
        samples += BehavioralTraceSample(COUNTDOWN_LABEL, 0, harness.advanceCountdown(COUNTDOWN_SAMPLE_SECONDS))
        samples += BehavioralTraceSample(COUNTDOWN_LABEL, 0, harness.advanceCountdown(COUNTDOWN_SAMPLE_SECONDS))
        samples += BehavioralTraceSample(COUNTDOWN_LABEL, 0, harness.advanceCountdown(CarPhysics.FIXED_DELTA_SECONDS))
        samples += BehavioralTraceSample(RACING_LABEL, 0, harness.finishCountdown())
    }

    private fun addSimulationSamples(
        harness: BehavioralCompatibilityHarness,
        scenario: BehavioralScenario,
        samples: MutableList<BehavioralTraceSample>,
    ) {
        var inputSegmentIndex = 0
        var raceFinished = false
        for (tick in 1..scenario.ticks) {
            inputSegmentIndex = scenario.nextInputSegmentIndex(inputSegmentIndex, tick)
            val snapshot = harness.advance(scenario.inputAt(tick, inputSegmentIndex))
            val finishedThisTick = snapshot.raceState == "finished" && !raceFinished
            val shouldSample =
                tick == 1 ||
                    tick % scenario.snapshotIntervalTicks == 0 ||
                    tick == scenario.ticks ||
                    finishedThisTick
            if (shouldSample) {
                samples += BehavioralTraceSample("simulation", tick, snapshot)
            }
            raceFinished = raceFinished || finishedThisTick
            if (raceFinished && !continueAfterFinish) break
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

    private companion object {
        const val COUNTDOWN_SAMPLE_SECONDS = 1f
        const val COUNTDOWN_LABEL = "countdown"
        const val LIFECYCLE_TAG = "state-machine"
        const val RACING_LABEL = "racing"
    }
}
