package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.example.toyracers.car.CarModel
import com.example.toyracers.track.TrackId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

class BehavioralCompatibilityTest {
    private val runner = BehavioralScenarioRunner()

    @Test
    fun `versioned behavioral fixtures match the Kotlin reference implementation`() {
        val scenarios = BehavioralFixtureLoader.scenarios()
        validateFixtureCoverage(scenarios)
        val actual = scenarios.map(runner::run)
        if (System.getProperty(UPDATE_GOLDENS_PROPERTY) == "true") {
            writeGoldens(actual)
        } else {
            assertGoldenTraces(actual)
            assertDeterministic(scenarios, actual)
            assertInputOriginsAreEquivalent(actual)
            assertObservedFeatureCoverage(actual)
            assertCompleteRaceReplay(scenarios, actual)
        }
    }

    private fun validateFixtureCoverage(scenarios: List<BehavioralScenario>) {
        assertEquals(50, scenarios.size)
        assertEquals(scenarios.size, scenarios.map(BehavioralScenario::id).toSet().size)
        assertMinimumTagCount(scenarios, "race", 10)
        assertMinimumTagCount(scenarios, "collision", 10)
        assertMinimumTagCount(scenarios, "physics", 10)
        assertMinimumTagCount(scenarios, "track", 5)
        assertMinimumTagCount(scenarios, "ai", 5)
        assertTracksAndCarsAreCovered(scenarios)
        assertInputsAndTicksAreCovered(scenarios)
        assertObservableFeatureCoverage(scenarios)
    }

    private fun assertTracksAndCarsAreCovered(scenarios: List<BehavioralScenario>) {
        assertEquals(TrackId.entries.map(TrackId::value).toSet(), scenarios.map(BehavioralScenario::trackId).toSet())
        assertEquals(CarModel.entries.map { it.name }.toSet(), scenarios.map(BehavioralScenario::playerCar).toSet())
        assertEquals(setOf("keyboard", "touch"), scenarios.map(BehavioralScenario::inputOrigin).toSet())
    }

    private fun assertInputsAndTicksAreCovered(scenarios: List<BehavioralScenario>) {
        val tags = scenarios.flatMap { it.tags }.toSet()
        assertTrue(setOf("throttle", "brake", "reverse", "steering", "drift").all(tags::contains))
        assertTrue(scenarios.count { it.ticks >= 1_000 } >= 20)
        assertTrue(scenarios.count { it.ticks >= 5_000 } >= 5)
        assertTrue(scenarios.all { it.snapshotIntervalTicks > 0 })
        assertTrue(scenarios.all { it.inputSegments.isNotEmpty() })
    }

    private fun assertObservableFeatureCoverage(scenarios: List<BehavioralScenario>) {
        val tags = scenarios.flatMap { it.tags }.toSet()
        assertTrue(setOf("car-car", "car-track", "checkpoint", "lap", "finish", "ranking").all(tags::contains))
        assertTrue(setOf("asphalt", "parquet", "tile", "recovery", "countdown").all(tags::contains))
    }

    private fun assertGoldenTraces(actual: List<BehavioralTrace>) {
        val goldens = BehavioralFixtureLoader.goldens().get("traces")
        actual.forEach { trace ->
            val expected = goldens.get(trace.scenarioId)
            assertNotNull("Missing golden trace for ${trace.scenarioId}", expected)
            val actualJson = JsonReader().parse(BehavioralTraceJson.encode(trace))
            val difference = BehavioralTraceJson.firstDifference(checkNotNull(expected), actualJson)
            assertEquals("First mismatch in ${trace.scenarioId}: $difference", null, difference)
        }
    }

    private fun assertDeterministic(
        scenarios: List<BehavioralScenario>,
        firstRun: List<BehavioralTrace>,
    ) {
        scenarios.zip(firstRun).forEach { (scenario, firstTrace) ->
            val secondTrace = runner.run(scenario)
            assertEquals(
                "Scenario ${scenario.id} is not deterministic",
                BehavioralTraceJson.encode(firstTrace),
                BehavioralTraceJson.encode(secondTrace),
            )
        }
    }

    private fun assertCompleteRaceReplay(
        scenarios: List<BehavioralScenario>,
        traces: List<BehavioralTrace>,
    ) {
        val fullRace = scenarios.filter(BehavioralScenario::fullRace)
        assertEquals(1, fullRace.size)
        val finalSnapshot =
            traces
                .first { it.scenarioId == fullRace.single().id }
                .samples
                .last()
                .snapshot
        assertEquals("FINISHED", finalSnapshot.phase)
        assertTrue(finalSnapshot.participants.first().finished)
        assertEquals(finalSnapshot.requiredLaps, finalSnapshot.participants.first().completedLaps)
    }

    private fun assertInputOriginsAreEquivalent(traces: List<BehavioralTrace>) {
        val tracesById = traces.associateBy(BehavioralTrace::scenarioId)
        val keyboard = checkNotNull(tracesById["physics-keyboard-throttle"])
        val touch = checkNotNull(tracesById["physics-touch-throttle"])
        assertEquals(keyboard.samples, touch.samples)
    }

    private fun assertObservedFeatureCoverage(traces: List<BehavioralTrace>) {
        assertCollisionImpactCoverage(traces)
        assertRaceProgressCoverage(traces)
        assertSurfaceAndRecoveryCoverage(traces)
    }

    private fun assertCollisionImpactCoverage(traces: List<BehavioralTrace>) {
        val collisionTraces = traces.filter { it.scenarioId.startsWith("collision-") }
        assertEquals(10, collisionTraces.size)
        val impacts = collisionTraces.filter { it.firstPhysicalSnapshot().lastImpactSpeed > 0f }
        assertTrue(impacts.size >= 7)
        assertTrue(impacts.any { it.scenarioId.contains("car-car") })
        assertTrue(impacts.any { it.scenarioId.contains("track") })
    }

    private fun assertRaceProgressCoverage(traces: List<BehavioralTrace>) {
        val snapshots = traces.flatMap { trace -> trace.samples.map(BehavioralTraceSample::snapshot) }
        val players = snapshots.map { it.participants.first() }
        assertTrue(players.any { it.currentCheckpointIndex > 0 })
        assertTrue(players.any { it.completedLaps > 0 })
        assertTrue(players.any { it.finished && it.finishPosition == 1 })
        assertTrue(snapshots.any { it.phase == "FINISHED" && it.playerPosition == 1 })
    }

    private fun assertSurfaceAndRecoveryCoverage(traces: List<BehavioralTrace>) {
        val surfaces =
            traces
                .filter { it.scenarioId.startsWith("surface-") }
                .map {
                    it
                        .racingSnapshot()
                        .participants
                        .first()
                        .surface
                }.toSet()
        assertEquals(setOf("ASPHALT", "PARQUET", "TILE"), surfaces)
        assertTrue(
            traces
                .flatMap { it.samples }
                .flatMap { it.snapshot.participants }
                .any { it.aiBehavior == "RECOVER" },
        )
    }

    private fun BehavioralTrace.firstPhysicalSnapshot(): BehavioralSnapshot = samples.first { it.tick == 1 }.snapshot

    private fun BehavioralTrace.racingSnapshot(): BehavioralSnapshot = samples.first { it.label == "racing" }.snapshot

    private fun assertMinimumTagCount(
        scenarios: List<BehavioralScenario>,
        tag: String,
        minimum: Int,
    ) {
        assertTrue("Expected at least $minimum $tag scenarios", scenarios.count { tag in it.tags } >= minimum)
    }

    private fun writeGoldens(traces: List<BehavioralTrace>) {
        Files.writeString(GOLDEN_SOURCE, BehavioralTraceJson.encodeGoldens(traces) + "\n")
    }

    private companion object {
        const val UPDATE_GOLDENS_PROPERTY = "updateBehavioralGoldens"
        val GOLDEN_SOURCE: Path = Path.of("src/test/resources/compat/goldens.json")
    }
}
