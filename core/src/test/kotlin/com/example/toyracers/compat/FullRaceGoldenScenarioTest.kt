package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
import com.example.toyracers.race.RaceRules
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

class FullRaceGoldenScenarioTest {
    private val runner = BehavioralScenarioRunner()

    @Test
    fun `full race goldens complete three laps through gameplay rules`() {
        val fixtures = fixtures()

        assertTrue(
            "Expected at least $MINIMUM_SCENARIO_COUNT full-race scenarios",
            fixtures.size >= MINIMUM_SCENARIO_COUNT,
        )
        assertEquals(fixtures.size, fixtures.map { it.scenario.seed }.toSet().size)
        assertTrue(fixtures.any { STATE_MACHINE_TAG in it.scenario.tags })

        fixtures.forEach { fixture ->
            val track = validateScenario(fixture.scenario)
            val trace = runner.run(fixture.scenario)

            assertEquals(fixture.scenario.seed, trace.seed)
            assertPlayerAndAiParticipants(trace)
            assertLifecycle(trace, fixture.scenario)
            assertPeriodicSnapshots(trace, fixture.scenario)
            assertProgressEventSnapshots(trace, track, fixture.scenario.id)
            assertFinishedFirst(trace, fixture.golden)
        }
    }

    private fun validateScenario(scenario: BehavioralScenario): Track {
        assertTrue(scenario.fullRace)
        assertTrue(EVENT_SNAPSHOTS_TAG in scenario.tags)
        assertTrue(PERIODIC_SNAPSHOTS_TAG in scenario.tags)
        assertTrue(scenario.ticks >= MINIMUM_LONG_SCENARIO_TICKS)
        assertFalse("${scenario.id} must not inject progress or finish state", scenario.initialStates.isNotEmpty())

        return TrackLoader().load(TrackId.fromValue(scenario.trackId)).also { track ->
            assertEquals(PARTICIPANT_COUNT, track.startGrid.size)
            assertTrue(track.checkpoints.isNotEmpty())
            assertTrue(track.racingLine.isNotEmpty())
        }
    }

    private fun assertLifecycle(
        trace: BehavioralTrace,
        scenario: BehavioralScenario,
    ) {
        assertTrue(trace.samples.any { it.label == COUNTDOWN_LABEL })
        assertTrue(trace.samples.any { it.label == RACING_LABEL })
        if (STATE_MACHINE_TAG in scenario.tags) {
            assertEquals(
                listOf(
                    LOADING_LABEL,
                    READY_LABEL,
                    COUNTDOWN_LABEL,
                    COUNTDOWN_LABEL,
                    COUNTDOWN_LABEL,
                    COUNTDOWN_LABEL,
                    RACING_LABEL,
                ),
                trace.samples.take(LIFECYCLE_SAMPLE_COUNT).map(BehavioralTraceSample::label),
            )
        }
    }

    private fun assertPlayerAndAiParticipants(trace: BehavioralTrace) {
        val participants =
            trace.samples
                .first()
                .snapshot
                .participants

        assertTrue(participants.any { it.id == PLAYER_ID })
        assertEquals(AI_PARTICIPANT_COUNT, participants.count { it.id.startsWith(AI_ID_PREFIX) })
    }

    private fun assertPeriodicSnapshots(
        trace: BehavioralTrace,
        scenario: BehavioralScenario,
    ) {
        val periodicTicks =
            trace.samples
                .filter { it.label == SIMULATION_LABEL }
                .map(BehavioralTraceSample::tick)

        assertTrue(periodicTicks.contains(1))
        assertTrue(
            periodicTicks.any {
                it >= scenario.snapshotIntervalTicks && it % scenario.snapshotIntervalTicks == 0
            },
        )
    }

    private fun assertProgressEventSnapshots(
        trace: BehavioralTrace,
        track: Track,
        scenarioId: String,
    ) {
        val expectedCheckpoints =
            List(RaceRules.DEFAULT_LAP_COUNT) {
                (1..track.checkpoints.size).toList()
            }.flatten()
        val checkpointProgress =
            trace.playerProgressFor(CHECKPOINT_LABEL).map(BehavioralParticipantSnapshot::checkpoint)
        val completedLaps = trace.playerProgressFor(LAP_LABEL).map(BehavioralParticipantSnapshot::lap)
        val finishSamples = trace.samples.filter { it.label == FINISH_LABEL }

        assertEquals(expectedCheckpoints, checkpointProgress)
        assertEquals((1..RaceRules.DEFAULT_LAP_COUNT).toList(), completedLaps)
        assertEquals("$scenarioId should have one finish event snapshot", 1, finishSamples.size)
        val finish = finishSamples.single().snapshot
        assertEquals("finished", finish.raceState)
        assertTrue(finish.player().finished)
    }

    private fun assertFinishedFirst(
        trace: BehavioralTrace,
        golden: Path,
    ) {
        val finalSnapshot = trace.samples.last().snapshot
        val player = finalSnapshot.player()
        val playerResult = finalSnapshot.playerFinishResult()

        assertEquals("finished", finalSnapshot.raceState)
        assertEquals(RaceRules.DEFAULT_LAP_COUNT, player.lap)
        assertTrue(player.finished)
        assertEquals(EXPECTED_PLAYER_FINISH_POSITION, player.racePosition)
        assertEquals(EXPECTED_PLAYER_FINISH_POSITION, playerResult.finishPosition)
        assertEquals(
            goldenPlayerFinishTime(golden),
            playerResult.elapsedSimulationTime,
            SnapshotComparisonEngine.ABSOLUTE_TOLERANCE.toFloat(),
        )
    }

    private fun fixtures(): List<FullRaceFixture> {
        val scenarios = scenarioDirectory()
        return Files.walk(scenarios).use { paths ->
            paths
                .filter(Files::isRegularFile)
                .filter { path -> path.fileName.toString().endsWith(JSON_SUFFIX) }
                .filter { path -> path.fileName.toString() != INPUT_SCRIPT_FILE }
                .sorted()
                .map { path ->
                    FullRaceFixture(
                        scenario = BehavioralScenarioLoader.load(path),
                        golden = goldenDirectory().resolve(scenarios.relativize(path)),
                    )
                }.toList()
        }
    }

    private fun goldenPlayerFinishTime(golden: Path): Float {
        val root = Files.newBufferedReader(golden).use(JsonReader()::parse)
        val finishSample = root.get("samples").children().single { it.getString("label") == FINISH_LABEL }
        return finishSample
            .get("snapshot")
            .get("finishResults")
            .children()
            .single { it.getString("participantId") == PLAYER_ID }
            .getFloat("elapsedSimulationTime")
    }

    private fun BehavioralTrace.playerProgressFor(label: String): List<BehavioralParticipantSnapshot> =
        samples
            .filter { it.label == label }
            .map { it.snapshot.player() }

    private fun BehavioralSnapshot.player(): BehavioralParticipantSnapshot = participants.single { it.id == PLAYER_ID }

    private fun BehavioralSnapshot.playerFinishResult(): BehavioralFinishResultSnapshot =
        finishResults.single { it.participantId == PLAYER_ID }

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private fun scenarioDirectory(): Path = compatibilityDirectory().resolve("scenarios/full_race")

    private fun goldenDirectory(): Path = compatibilityDirectory().resolve("golden/full_race")

    private fun compatibilityDirectory(): Path =
        Path.of(requireNotNull(System.getProperty(COMPATIBILITY_DIRECTORY_PROPERTY))).toAbsolutePath()

    private data class FullRaceFixture(
        val scenario: BehavioralScenario,
        val golden: Path,
    )

    private companion object {
        const val CHECKPOINT_LABEL = "checkpoint"
        const val AI_ID_PREFIX = "ai-"
        const val AI_PARTICIPANT_COUNT = 5
        const val COMPATIBILITY_DIRECTORY_PROPERTY = "compatibilityDirectory"
        const val COUNTDOWN_LABEL = "countdown"
        const val EVENT_SNAPSHOTS_TAG = "event-snapshots"
        const val EXPECTED_PLAYER_FINISH_POSITION = 1
        const val FINISH_LABEL = "finish"
        const val INPUT_SCRIPT_FILE = "full-race-input.json"
        const val JSON_SUFFIX = ".json"
        const val LAP_LABEL = "lap"
        const val LIFECYCLE_SAMPLE_COUNT = 7
        const val LOADING_LABEL = "loading"
        const val MINIMUM_LONG_SCENARIO_TICKS = 5_000
        const val MINIMUM_SCENARIO_COUNT = 10
        const val PARTICIPANT_COUNT = 6
        const val PERIODIC_SNAPSHOTS_TAG = "periodic-snapshots"
        const val PLAYER_ID = "player"
        const val RACING_LABEL = "racing"
        const val READY_LABEL = "ready"
        const val SIMULATION_LABEL = "simulation"
        const val STATE_MACHINE_TAG = "state-machine"
    }
}
