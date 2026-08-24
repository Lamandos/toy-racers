package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Path

class AiBehaviorScenarioTest {
    private val runner = BehavioralScenarioRunner(continueAfterFinish = true)

    @Test
    fun `AI follows the racing path and advances race progress`() {
        val trace = run("follows_racing_path.json")
        val observations = trace.aiObservations("ai-0")

        assertTrue(observations.any { it.checkpoint > 0 })
        assertTrue(observations.any { it.lap > 0 })
        assertTrue(observations.all { it.surface == "asphalt" })
    }

    @Test
    fun `same AI seed and starting state produce identical steering snapshots`() {
        val scenario = scenario("deterministic_steering.json")

        val first = runner.run(scenario)
        val second = runner.run(scenario)

        assertEquals(BehavioralTraceJson.encode(first), BehavioralTraceJson.encode(second))
        assertTrue(first.aiObservations("ai-0").any { it.angularVelocity != 0f })
    }

    @Test
    fun `AI changes its observed course around a stopped obstacle`() {
        val controlTrace = run("obstacle_reaction_control.json")
        val obstacleTrace = run("obstacle_reaction.json")

        val controlCar = controlTrace.aiAt("ai-0", tick = 60)
        val obstacleCar = obstacleTrace.aiAt("ai-0", tick = 60)

        assertTrue(controlCar.y != obstacleCar.y)
        assertTrue(controlCar.rotation != obstacleCar.rotation)
    }

    @Test
    fun `AI recovery returns an off track car to a racing surface`() {
        val trace = run("recovery.json")
        val first = trace.aiAt("ai-0", tick = 1)
        val recovered = trace.aiAt("ai-0", tick = 180)

        assertEquals("tile", first.surface)
        assertEquals("asphalt", recovered.surface)
        assertTrue(recovered.x != first.x || recovered.y != first.y)
    }

    @Test
    fun `AI recovery does not grant checkpoint progress`() {
        val observations = run("recovery_checkpoint_progress.json").aiObservations("ai-0")

        assertTrue(observations.all { it.checkpoint == 0 && it.lap == 0 })
    }

    @Test
    fun `extended multi AI scenario remains finite and deterministic`() {
        val scenario = scenario("extended_multicar.json")
        val first = runner.run(scenario)
        val second = runner.run(scenario)
        val participants =
            first
                .samples
                .first()
                .snapshot
                .participants

        assertEquals(BehavioralTraceJson.encode(first), BehavioralTraceJson.encode(second))
        assertEquals(5, participants.count { it.id.startsWith("ai-") })
        assertTrue(first.samples.all { it.snapshot.hasOnlyFiniteValues() })
    }

    private fun run(fileName: String): BehavioralTrace = runner.run(scenario(fileName))

    private fun scenario(fileName: String): BehavioralScenario =
        BehavioralScenarioLoader.load(compatibilityDirectory().resolve("scenarios/ai").resolve(fileName))

    private fun compatibilityDirectory(): Path =
        Path.of(requireNotNull(System.getProperty(COMPATIBILITY_DIRECTORY_PROPERTY))).toAbsolutePath()

    private fun BehavioralTrace.aiAt(
        id: String,
        tick: Int,
    ): BehavioralParticipantSnapshot =
        samples
            .first { it.label == "simulation" && it.tick == tick }
            .snapshot
            .participants
            .first { it.id == id }

    private fun BehavioralTrace.aiObservations(id: String): List<BehavioralParticipantSnapshot> =
        samples
            .asSequence()
            .filter { it.label == "simulation" }
            .map { sample -> sample.snapshot.participants.first { it.id == id } }
            .toList()

    private fun BehavioralSnapshot.hasOnlyFiniteValues(): Boolean =
        elapsedSimulationTime.isFinite() &&
            countdown.remainingSeconds.isFinite() &&
            participants.all { participant ->
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
                ).all(Float::isFinite)
            } &&
            finishResults.all { result ->
                result.elapsedSimulationTime.isFinite() &&
                    (result.bestLapTime?.isFinite() ?: true)
            }

    private companion object {
        const val COMPATIBILITY_DIRECTORY_PROPERTY = "compatibilityDirectory"
    }
}
