package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SnapshotComparisonEngineTest {
    @Test
    fun `discrete snapshot fields and participant ordering must match exactly`() {
        val expected =
            trace(
                """
                {"samples":[{"tick":842,"snapshot":{"raceState":"racing","participants":[
                  {"id":"player","surface":"asphalt","checkpoint":2,"lap":1,"racePosition":1,"finished":false},
                  {"id":"ai-0","surface":"asphalt","checkpoint":2,"lap":1,"racePosition":2,"finished":false}
                ],"ranking":["player","ai-0"]}}]}
                """,
            )
        val actual =
            trace(
                """
                {"samples":[{"tick":842,"snapshot":{"raceState":"finished","participants":[
                  {"id":"ai-0","surface":"asphalt","checkpoint":3,"lap":1,"racePosition":1,"finished":false},
                  {"id":"player","surface":"asphalt","checkpoint":2,"lap":1,"racePosition":2,"finished":false}
                ],"ranking":["ai-0","player"]}}]}
                """,
            )

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertNotNull(mismatch)
        assertEquals(842L, mismatch?.tick)
        assertEquals("raceState", mismatch?.field)
        assertEquals("exact", mismatch?.delta)
    }

    @Test
    fun `float values accept only their documented absolute tolerance`() {
        val expected = traceWithParticipant("\"x\":183.4112")
        val withinTolerance = traceWithParticipant("\"x\":183.41129")
        val outsideTolerance = traceWithParticipant("\"x\":183.41131")

        assertNull(SnapshotComparisonEngine.compare(expected, withinTolerance).firstMismatch)
        assertEquals("x", SnapshotComparisonEngine.compare(expected, outsideTolerance).firstMismatch?.field)
    }

    @Test
    fun `angle comparison crosses zero using the shortest angular delta`() {
        val expected = traceWithParticipant("\"rotation\":359.99998")
        val withinTolerance = traceWithParticipant("\"rotation\":0.00002")
        val outsideTolerance = traceWithParticipant("\"rotation\":0.03")

        assertNull(SnapshotComparisonEngine.compare(expected, withinTolerance).firstMismatch)
        val mismatch = SnapshotComparisonEngine.compare(expected, outsideTolerance).firstMismatch
        assertEquals("rotation", mismatch?.field)
        assertTrue(checkNotNull(mismatch).delta.startsWith("angular delta"))
    }

    @Test
    fun `rotations outside the normalized contract are rejected`() {
        val expected = traceWithParticipant("\"rotation\":0.0")
        val actual = traceWithParticipant("\"rotation\":360.0")

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("rotation", mismatch?.field)
        assertEquals("outside [0, 360)", mismatch?.delta)
    }

    @Test
    fun `negative zero in approximate fields is rejected`() {
        val expected = traceWithParticipant("\"x\":0.0")
        val actual = traceWithParticipant("\"x\":-0.0")

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("x", mismatch?.field)
        assertEquals("-0.0", mismatch?.actual)
        assertEquals("negative zero", mismatch?.delta)
    }

    @Test
    fun `sample object type mismatches preserve the sample tick`() {
        val expected =
            trace(
                """
                {"samples":[{"label":"simulation","tick":842,"snapshot":{}}]}
                """,
            )
        val actual =
            trace(
                """
                {"samples":[null]}
                """,
            )

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals(842L, mismatch?.tick)
        assertEquals("simulation", mismatch?.sampleLabel)
        assertEquals("samples[0]", mismatch?.field)
    }

    @Test
    fun `missing sample reports the first unmatched tick`() {
        val expected = trace("{\"samples\":[{\"tick\":0},{\"tick\":842}]}")
        val actual = trace("{\"samples\":[{\"tick\":0}]}")

        val comparison = SnapshotComparisonEngine.compare(expected, actual)
        val mismatch = comparison.firstMismatch

        assertEquals(842L, mismatch?.tick)
        assertEquals("samples.size", mismatch?.field)
        assertTrue(checkNotNull(comparison.failureReport("drift_right_long")).contains("First mismatch: tick 842"))
    }

    @Test
    fun `finish result mismatches identify the finished participant`() {
        val expected = traceWithFinishResult("\"finishPosition\":1")
        val actual = traceWithFinishResult("\"finishPosition\":2")

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("ai-4", mismatch?.participant)
        assertEquals("finishPosition", mismatch?.field)
    }

    @Test
    fun `finish result size mismatches identify the unmatched participant`() {
        val expected =
            trace(
                """
                {"samples":[{"tick":842,"snapshot":{"finishResults":[
                  {"participantId":"ai-0"},{"participantId":"ai-4"}
                ]}}]}
                """,
            )
        val actual =
            trace(
                """
                {"samples":[{"tick":842,"snapshot":{"finishResults":[
                  {"participantId":"ai-0"}
                ]}}]}
                """,
            )

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("ai-4", mismatch?.participant)
        assertEquals("finishResults.size", mismatch?.field)
    }

    @Test
    fun `participant size mismatches identify the unmatched participant`() {
        val expected = traceWithParticipants("player", "ai-4")
        val missingParticipant = traceWithParticipants("player")
        val unexpectedParticipant = traceWithParticipants("player", "ai-4")

        listOf(
            SnapshotComparisonEngine.compare(expected, missingParticipant).firstMismatch to "ai-4",
            SnapshotComparisonEngine.compare(missingParticipant, unexpectedParticipant).firstMismatch to "ai-4",
        ).forEach { (mismatch, participant) ->
            assertEquals(participant, mismatch?.participant)
            assertEquals("participants.size", mismatch?.field)
        }
    }

    @Test
    fun `duplicate object fields are rejected`() {
        val expected = traceWithParticipant("\"x\":10.0")
        val actual = traceWithParticipant("\"x\":10.0,\"x\":10.0")

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("player", mismatch?.participant)
        assertEquals("x", mismatch?.field)
        assertEquals("duplicate key", mismatch?.delta)
    }

    @Test
    fun `non finite approximate values are rejected explicitly`() {
        listOf(Double.NaN to "NaN", Double.POSITIVE_INFINITY to "Infinity").forEach { (value, label) ->
            val expected = traceWithParticipant("\"x\":10.0")
            val actual = traceWithParticipant("\"x\":10.0")
            actual.sampleParticipant().get("x").set(value, null)

            val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

            assertEquals("x", mismatch?.field)
            assertEquals(label, mismatch?.actual)
            assertEquals("non-finite value", mismatch?.delta)
        }
    }

    @Test
    fun `failure report identifies scenario tick participant fields and deltas`() {
        val expected =
            traceWithParticipant(
                "\"x\":183.4112,\"y\":94.2811,\"rotation\":359.92",
            )
        val actual =
            traceWithParticipant(
                "\"x\":183.5288,\"y\":94.2892,\"rotation\":0.03",
            )

        val report = checkNotNull(SnapshotComparisonEngine.compare(expected, actual).failureReport("drift_right_long"))

        assertTrue(report.contains("Scenario: drift_right_long"))
        assertTrue(report.contains("First mismatch: tick 842"))
        assertTrue(report.contains("Participant: player"))
        assertTrue(report.contains("field              expected       actual         delta"))
        assertTrue(report.contains("x                  183.4112       183.5288"))
        assertTrue(report.contains("y                  94.2811        94.2892"))
        assertTrue(report.contains("rotation           359.92         0.03"))
        assertTrue(report.contains("+0.117600"))
        assertTrue(report.contains("angular delta 0.110000"))
        assertFalse(report.contains("Following differences:"))
    }

    @Test
    fun `failure report keeps same-tick samples separate`() {
        val expected =
            trace(
                """
                {"samples":[
                  {"label":"countdown","tick":0,"snapshot":{"participants":[{"id":"player","x":1.0}]}},
                  {"label":"racing","tick":0,"snapshot":{"participants":[{"id":"player","x":2.0}]}}
                ]}
                """,
            )
        val actual =
            trace(
                """
                {"samples":[
                  {"label":"countdown","tick":0,"snapshot":{"participants":[{"id":"player","x":1.1}]}},
                  {"label":"racing","tick":0,"snapshot":{"participants":[{"id":"player","x":2.1}]}}
                ]}
                """,
            )

        val report = checkNotNull(SnapshotComparisonEngine.compare(expected, actual).failureReport("same_tick"))

        assertTrue(report.contains("First mismatch: tick 0 (countdown)"))
        assertTrue(report.contains("Following differences:"))
        assertTrue(report.contains("tick 0 (racing)"))
    }

    @Test
    fun `complete traces are schema-validated before comparison`() {
        val expected = completeTrace()
        val actual = completeTrace()
        expected.get("schemaVersion").set(99L, null)
        actual.get("schemaVersion").set(99L, null)
        expected
            .get("samples")
            .get(0)
            .get("snapshot")
            .get("schemaVersion")
            .set(99L, null)
        actual
            .get("samples")
            .get(0)
            .get("snapshot")
            .get("schemaVersion")
            .set(99L, null)

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("schemaVersion", mismatch?.field)
        assertEquals("schema validation", mismatch?.delta)
    }

    @Test
    fun `complete traces without root schema version are schema-validated`() {
        val expected = completeTrace().also { it.remove("schemaVersion") }
        val actual = completeTrace().also { it.remove("schemaVersion") }

        val mismatch = SnapshotComparisonEngine.compare(expected, actual).firstMismatch

        assertEquals("schemaVersion", mismatch?.field)
        assertEquals("schema validation", mismatch?.delta)
    }

    private fun traceWithParticipant(fields: String) =
        trace(
            """
            {"samples":[{"tick":842,"snapshot":{"participants":[{"id":"player",$fields}]}}]}
            """,
        )

    private fun traceWithFinishResult(field: String) =
        trace(
            """
            {"samples":[{"tick":842,"snapshot":{"finishResults":[
              {"participantId":"ai-4",$field}
            ]}}]}
            """,
        )

    private fun traceWithParticipants(vararg ids: String): com.badlogic.gdx.utils.JsonValue {
        val participants = ids.joinToString { id -> """{"id":"$id"}""" }
        return trace("""{"samples":[{"tick":842,"snapshot":{"participants":[$participants]}}]}""")
    }

    private fun trace(document: String) = JsonReader().parse(document.trimIndent())

    private fun completeTrace() =
        trace(
            """
            {
              "schemaVersion": 3,
              "scenarioId": "schema-test",
              "seed": 1,
              "samples": [{
                "label": "simulation",
                "tick": 0,
                "snapshot": {
                  "schemaVersion": 2,
                  "simulationTick": 0,
                  "raceState": "racing",
                  "countdown": {"state": "complete", "remainingSeconds": 0.0},
                  "elapsedSimulationTime": 0.0,
                  "currentLap": 1,
                  "currentProgress": {"checkpoint": 0, "completedLaps": 0},
                  "participants": [{
                    "id": "player",
                    "surface": "asphalt",
                    "x": 0.0,
                    "y": 0.0,
                    "rotation": 0.0,
                    "velocityX": 0.0,
                    "velocityY": 0.0,
                    "angularVelocity": 0.0,
                    "longitudinalSpeed": 0.0,
                    "lateralSpeed": 0.0,
                    "driftAmount": 0.0,
                    "checkpoint": 0,
                    "lap": 0,
                    "racePosition": 1,
                    "finished": false
                  }],
                  "ranking": ["player"],
                  "finishedParticipants": [],
                  "finishResults": []
                }
              }]
            }
            """,
        )

    private fun com.badlogic.gdx.utils.JsonValue.sampleParticipant() =
        get("samples")
            .get(0)
            .get("snapshot")
            .get("participants")
            .get(0)
}
