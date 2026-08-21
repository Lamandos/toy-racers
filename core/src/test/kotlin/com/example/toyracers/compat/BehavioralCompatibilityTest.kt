package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
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
    fun `golden comparison rejects mismatched discrete JSON types`() {
        val expected = JsonReader().parse("{\"value\":false}")
        val actual = JsonReader().parse("{\"value\":\"false\"}")

        assertNotNull(BehavioralTraceJson.firstDifference(expected, actual))
    }

    @Test
    fun `golden comparison preserves full-width integer precision`() {
        val expected = JsonReader().parse("{\"seed\":9223372036854775806}")
        val actual = JsonReader().parse("{\"seed\":9223372036854775807}")

        assertNotNull(BehavioralTraceJson.firstDifference(expected, actual))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `compatibility harness rejects invalid surface multiplier`() {
        BehavioralCompatibilityHarness(
            BehavioralRaceConfiguration(
                seed = 1L,
                trackId = "track-01",
                playerCar = "red-stripe",
            ),
        ).setInitialStates(
            listOf(BehavioralInitialState(id = "player", surfaceSpeedMultiplier = -0.1f)),
        )
    }

    @Test
    fun `compatibility harness accepts stable difficulty IDs`() {
        val harness =
            BehavioralCompatibilityHarness(
                BehavioralRaceConfiguration(
                    seed = 1L,
                    trackId = "track-01",
                    playerCar = "red-stripe",
                    opponentDifficulty = "hard",
                ),
            )

        assertEquals("countdown", harness.start().phase)
    }

    @Test
    fun `fixture loader accepts integral JSON number representations`() {
        val scenario =
            parseScenario(
                """
                {
                  "id": "integral-number-fixture", "seed": 1.0, "trackId": "track-01",
                  "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                  "ticks": 1e0, "snapshotIntervalTicks": 1.0,
                  "inputSegments": [{"fromTick": 1e0, "toTick": 1.0}]
                }
                """.trimIndent(),
            ).single()

        assertEquals(1L, scenario.seed)
        assertEquals(1, scenario.ticks)
        assertEquals(1, scenario.inputSegments.single().toTick)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects Float overflow in initial state`() {
        parseScenario(
            """
            {
              "id": "float-overflow", "seed": 1, "trackId": "track-01",
              "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
              "ticks": 1, "snapshotIntervalTicks": 1,
              "inputSegments": [{"fromTick": 1, "toTick": 1}],
              "initialStates": [{"id": "player", "x": 1e100}]
            }
            """.trimIndent(),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects finished initial state without position`() {
        parseScenario(
            """
            {
              "id": "missing-finish-position", "seed": 1, "trackId": "track-01",
              "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
              "ticks": 1, "snapshotIntervalTicks": 1,
              "inputSegments": [{"fromTick": 1, "toTick": 1}],
              "initialStates": [{"id": "player", "finished": true}]
            }
            """.trimIndent(),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects progress beyond the selected track`() {
        parseScenario(
            """
            {
              "id": "invalid-checkpoint", "seed": 1, "trackId": "track-01",
              "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
              "ticks": 1, "snapshotIntervalTicks": 1,
              "inputSegments": [{"fromTick": 1, "toTick": 1}],
              "initialStates": [{"id": "player", "currentCheckpointIndex": 4}]
            }
            """.trimIndent(),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects segment outside scenario ticks`() {
        parseScenario(
            """
            {
              "id": "invalid-segment-range", "seed": 1, "trackId": "track-01",
              "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
              "ticks": 1, "snapshotIntervalTicks": 1,
              "inputSegments": [{"fromTick": 1, "toTick": 2}]
            }
            """.trimIndent(),
        )
    }

    @Test
    fun `versioned behavioral fixtures match the Kotlin reference implementation`() {
        val scenarios = BehavioralFixtureLoader.scenarios()
        validateFixtureCoverage(scenarios)
        assertScenarioSchemaMatchesGameModel()
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
        assertEquals(
            CarModel.entries.map(CarModel::scenarioId).toSet(),
            scenarios.map(BehavioralScenario::playerCar).toSet(),
        )
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

    private fun assertScenarioSchemaMatchesGameModel() {
        val schema = readScenarioSchema()
        val scenarioProperties = schema.get("\$defs").get("scenario").get("properties")

        assertEquals(
            BehavioralFixtureLoader.SCHEMA_VERSION,
            schema.get("properties").get("schemaVersion").getInt("const"),
        )
        assertEquals(
            TrackId.entries.map(TrackId::value).toSet(),
            enumValues(scenarioProperties.get("trackId").get("enum")),
        )
        assertEquals(
            CarModel.entries.map(CarModel::scenarioId).toSet(),
            enumValues(scenarioProperties.get("playerCar").get("enum")),
        )
        assertEquals(
            setOf("keyboard", "touch"),
            enumValues(scenarioProperties.get("inputOrigin").get("enum")),
        )
        assertEquals(
            setOf("player", "ai-0", "ai-1", "ai-2", "ai-3", "ai-4"),
            enumValues(
                schema
                    .get("\$defs")
                    .get("initialState")
                    .get("properties")
                    .get("id")
                    .get("enum"),
            ),
        )
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
        assertEquals("finished", finalSnapshot.phase)
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
        assertTrue(snapshots.any { it.phase == "finished" && it.playerPosition == 1 })
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
        assertEquals(setOf("asphalt", "parquet", "tile"), surfaces)
        assertTrue(
            traces
                .flatMap { it.samples }
                .flatMap { it.snapshot.participants }
                .any { it.aiBehavior == "recover" },
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

    private fun readScenarioSchema(): JsonValue {
        val stream = requireNotNull(javaClass.classLoader.getResourceAsStream("compat/scenario.schema.json"))
        return stream.bufferedReader().use(JsonReader()::parse)
    }

    private fun parseScenario(value: String): List<BehavioralScenario> =
        BehavioralFixtureLoader.parseScenarioDocument(
            JsonReader().parse("{\"schemaVersion\":1,\"scenarios\":[$value]}"),
        )

    private fun enumValues(value: JsonValue): Set<String> =
        generateSequence(value.child) { it.next }.map(JsonValue::asString).toSet()

    private fun writeGoldens(traces: List<BehavioralTrace>) {
        Files.writeString(GOLDEN_SOURCE, BehavioralTraceJson.encodeGoldens(traces) + "\n")
    }

    private companion object {
        const val UPDATE_GOLDENS_PROPERTY = "updateBehavioralGoldens"
        val GOLDEN_SOURCE: Path = Path.of("src/test/resources/compat/goldens.json")
    }
}
