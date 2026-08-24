package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPerformance
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.race.RaceRules
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest
import kotlin.math.hypot

class LongRunningDeterminismTest {
    private val runner = BehavioralScenarioRunner()

    @Test
    fun `stress scenarios preserve normalized simulation invariants at every tick`() {
        val scenarios = stressScenarios()

        assertTrue(scenarios.first().ticks >= MINIMUM_SHORT_STRESS_TICKS)
        assertTrue(scenarios.last().ticks >= MINIMUM_LONG_STRESS_TICKS)
        val traces =
            scenarios.map { scenario ->
                runner.run(scenario).also { trace -> assertTraceIsValid(trace, scenario) }
            }
        assertTrue(
            "Long-running fixtures must exercise non-empty finish ordering",
            traces.any { trace -> trace.samples.any { it.snapshot.finishResults.isNotEmpty() } },
        )
    }

    @Test
    fun `five thousand tick scenario has one normalized output hash across twenty runs`() {
        val scenario = stressScenario(FIVE_THOUSAND_TICK_SCENARIO)
        val hashes =
            List(REPEAT_RUN_COUNT) {
                runner.run(scenario).also { trace -> assertTraceIsValid(trace, scenario) }.normalizedHash()
            }

        assertEquals(1, hashes.toSet().size)
    }

    private fun assertTraceIsValid(
        trace: BehavioralTrace,
        scenario: BehavioralScenario,
    ) {
        val simulationSamples = trace.samples.filter { it.label == SIMULATION_LABEL }
        val checkpointCount = TrackLoader().load(TrackId.fromValue(scenario.trackId)).checkpoints.size

        assertEquals(scenario.id, trace.scenarioId)
        assertEquals(scenario.seed, trace.seed)
        assertEquals(listOf(COUNTDOWN_LABEL, RACING_LABEL), trace.samples.take(2).map(BehavioralTraceSample::label))
        assertEquals(scenario.ticks + START_SAMPLE_COUNT, trace.samples.size)
        assertEquals(scenario.ticks, simulationSamples.size)
        assertInitialRaceStates(trace.samples.take(START_SAMPLE_COUNT), checkpointCount)
        simulationSamples.forEachIndexed { index, sample ->
            assertEquals(index + 1, sample.tick)
            assertSnapshotIsValid(sample.snapshot, sample.tick, checkpointCount)
        }
    }

    private fun assertInitialRaceStates(
        startSamples: List<BehavioralTraceSample>,
        checkpointCount: Int,
    ) {
        val countdown = startSamples.first().snapshot
        val racing = startSamples.last().snapshot

        startSamples.forEach { sample -> assertSnapshotValuesAreValid(sample.snapshot, checkpointCount) }
        assertEquals(0, countdown.simulationTick)
        assertEquals(0f, countdown.elapsedSimulationTime, 0f)
        assertEquals(COUNTDOWN_LABEL, countdown.raceState)
        assertEquals(COUNTDOWN_ACTIVE, countdown.countdown.state)
        assertTrue(countdown.countdown.remainingSeconds > 0f)
        assertEquals(0, racing.simulationTick)
        assertEquals(0f, racing.elapsedSimulationTime, 0f)
        assertEquals(RACING_LABEL, racing.raceState)
        assertEquals(COUNTDOWN_COMPLETE, racing.countdown.state)
        assertEquals(0f, racing.countdown.remainingSeconds, 0f)
    }

    private fun assertSnapshotIsValid(
        snapshot: BehavioralSnapshot,
        tick: Int,
        checkpointCount: Int,
    ) {
        assertSnapshotValuesAreValid(snapshot, checkpointCount)
        assertEquals(tick, snapshot.simulationTick)
        assertEquals(RACING_LABEL, snapshot.raceState)
        assertEquals(COUNTDOWN_COMPLETE, snapshot.countdown.state)
        assertEquals(0f, snapshot.countdown.remainingSeconds, 0f)
        assertEquals(tick * CarPhysics.FIXED_DELTA_SECONDS, snapshot.elapsedSimulationTime, 0f)
    }

    private fun assertSnapshotValuesAreValid(
        snapshot: BehavioralSnapshot,
        checkpointCount: Int,
    ) {
        assertEquals(BehavioralSnapshotSchema.VERSION, snapshot.schemaVersion)
        assertTrue(snapshot.currentLap in 1..RaceRules.DEFAULT_LAP_COUNT)
        assertTrue(snapshot.currentProgress.checkpoint in 0..checkpointCount)
        assertTrue(snapshot.currentProgress.completedLaps in 0 until RaceRules.DEFAULT_LAP_COUNT)

        assertFiniteValues(snapshot, checkpointCount)
        assertParticipantOrdering(snapshot)
        assertFinishOrdering(snapshot)
    }

    private fun assertFiniteValues(
        snapshot: BehavioralSnapshot,
        checkpointCount: Int,
    ) {
        assertTrue(snapshot.elapsedSimulationTime.isFinite())
        assertTrue(snapshot.countdown.remainingSeconds.isFinite())
        snapshot.participants.forEach { participant ->
            assertParticipantIsValid(participant, checkpointCount)
        }
        snapshot.finishResults.forEach { result ->
            assertTrue(result.elapsedSimulationTime.isFinite())
            assertTrue(result.bestLapTime?.isFinite() ?: true)
        }
    }

    private fun assertParticipantIsValid(
        participant: BehavioralParticipantSnapshot,
        checkpointCount: Int,
    ) {
        assertTrue("Invalid checkpoint for ${participant.id}", participant.checkpoint in 0..checkpointCount)
        assertTrue(
            "Invalid completed laps for ${participant.id}",
            participant.lap in 0..RaceRules.DEFAULT_LAP_COUNT,
        )
        val numericValues =
            listOf(
                participant.x,
                participant.y,
                participant.rotation,
                participant.velocityX,
                participant.velocityY,
                participant.angularVelocity,
                participant.longitudinalSpeed,
                participant.lateralSpeed,
                participant.driftAmount,
            )
        assertTrue("Non-finite state for ${participant.id}", numericValues.all(Float::isFinite))
        assertTrue("Invalid rotation for ${participant.id}", participant.rotation in 0f..<FULL_TURN_DEGREES)
        assertTrue(
            "Exploding velocity for ${participant.id}",
            hypot(participant.velocityX, participant.velocityY) <= maximumAllowedVelocity,
        )
    }

    private fun assertParticipantOrdering(snapshot: BehavioralSnapshot) {
        val participants = snapshot.participants
        val expectedRanking =
            participants
                .sortedWith(
                    compareBy<BehavioralParticipantSnapshot> { it.racePosition }
                        .thenBy(BehavioralParticipantSnapshot::id),
                ).map(BehavioralParticipantSnapshot::id)

        assertEquals(PARTICIPANT_IDS, participants.map(BehavioralParticipantSnapshot::id))
        assertEquals((1..PARTICIPANT_IDS.size).toList(), participants.map { it.racePosition }.sorted())
        assertEquals(expectedRanking, snapshot.ranking)
    }

    private fun assertFinishOrdering(snapshot: BehavioralSnapshot) {
        val finishedIds = snapshot.participants.filter { it.finished }.map(BehavioralParticipantSnapshot::id)
        val finishPositions = snapshot.finishResults.map(BehavioralFinishResultSnapshot::finishPosition)

        assertEquals(finishedIds.toSet(), snapshot.finishedParticipants.toSet())
        assertEquals(snapshot.finishedParticipants.size, snapshot.finishedParticipants.toSet().size)
        assertEquals(
            snapshot.finishedParticipants,
            snapshot.finishResults.map(BehavioralFinishResultSnapshot::participantId),
        )
        assertEquals(finishPositions.sorted(), finishPositions)
        assertEquals(finishPositions.size, finishPositions.toSet().size)
        assertTrue(finishPositions.all { it in 1..PARTICIPANT_IDS.size })
    }

    private fun BehavioralTrace.normalizedHash(): String {
        val normalizedOutput = BehavioralTraceJson.encode(this).toByteArray(UTF_8)
        return MessageDigest.getInstance(HASH_ALGORITHM).digest(normalizedOutput).toLowercaseHex()
    }

    private fun ByteArray.toLowercaseHex(): String =
        joinToString(separator = "") { byte -> byte.toUByte().toString(HEXADECIMAL_RADIX).padStart(2, '0') }

    private fun stressScenarios(): List<BehavioralScenario> =
        listOf(THOUSAND_TICK_SCENARIO, FIVE_THOUSAND_TICK_SCENARIO).map(::stressScenario)

    private fun stressScenario(fileName: String): BehavioralScenario =
        BehavioralFixtureLoader.parseScenarioDocument(readJson("$STRESS_RESOURCE_DIRECTORY/$fileName")).single()

    private fun readJson(path: String) =
        requireNotNull(javaClass.classLoader.getResourceAsStream(path)).bufferedReader().use(JsonReader()::parse)

    private companion object {
        const val COUNTDOWN_COMPLETE = "complete"
        const val COUNTDOWN_ACTIVE = "active"
        const val COUNTDOWN_LABEL = "countdown"
        const val FIVE_THOUSAND_TICK_SCENARIO = "long_running_5000.json"
        const val FULL_TURN_DEGREES = 360f
        const val HASH_ALGORITHM = "SHA-256"
        const val HEXADECIMAL_RADIX = 16
        const val MINIMUM_LONG_STRESS_TICKS = 5_000
        const val MINIMUM_SHORT_STRESS_TICKS = 1_000
        const val RACING_LABEL = "racing"
        const val REPEAT_RUN_COUNT = 20
        const val SIMULATION_LABEL = "simulation"
        const val START_SAMPLE_COUNT = 2
        const val STRESS_RESOURCE_DIRECTORY = "compat/stress"
        const val THOUSAND_TICK_SCENARIO = "long_running_1000.json"
        private const val COLLISION_VELOCITY_ALLOWANCE = 3f
        private val PARTICIPANT_IDS = listOf("ai-0", "ai-1", "ai-2", "ai-3", "ai-4", "player")
        private val maximumAllowedVelocity =
            CarConfig().maxForwardSpeed * CarPerformance.MAX_MULTIPLIER * COLLISION_VELOCITY_ALLOWANCE
    }
}
