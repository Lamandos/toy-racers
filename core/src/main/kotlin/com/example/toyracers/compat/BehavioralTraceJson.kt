package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import java.util.Locale

internal object BehavioralTraceJson {
    const val SCHEMA_VERSION = 2
    const val FLOAT_TOLERANCE = 0.0001

    fun encode(trace: BehavioralTrace): String =
        buildString {
            append('{')
            field("schemaVersion", SCHEMA_VERSION)
            append(',')
            field("scenarioId", trace.scenarioId)
            append(',')
            field("seed", trace.seed)
            append(",\"samples\":[")
            trace.samples.forEachIndexed { index, sample ->
                if (index > 0) append(',')
                sample(sample)
            }
            append("]}")
        }

    fun encodeGoldens(traces: List<BehavioralTrace>): String =
        buildString {
            append("{\"schemaVersion\":")
            append(SCHEMA_VERSION)
            append(",\"traces\":{")
            traces.forEachIndexed { index, trace ->
                if (index > 0) append(',')
                appendQuoted(trace.scenarioId)
                append(':')
                append(encode(trace))
            }
            append("}}")
        }

    fun firstDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String = "$",
    ): String? = BehavioralTraceComparator.firstDifference(expected, actual, path)

    private fun StringBuilder.sample(sample: BehavioralTraceSample) {
        append('{')
        field("label", sample.label)
        append(',')
        field("tick", sample.tick)
        append(",\"snapshot\":")
        snapshot(sample.snapshot)
        append('}')
    }

    private fun StringBuilder.snapshot(snapshot: BehavioralSnapshot) {
        append('{')
        field("schemaVersion", snapshot.schemaVersion)
        append(',')
        field("simulationTick", snapshot.simulationTick)
        append(',')
        field("raceState", snapshot.raceState)
        append(",\"countdown\":")
        countdown(snapshot.countdown)
        append(',')
        floatField("elapsedSimulationTime", snapshot.elapsedSimulationTime)
        append(',')
        field("currentLap", snapshot.currentLap)
        append(",\"currentProgress\":")
        progress(snapshot.currentProgress)
        append(",\"participants\":[")
        snapshot.participants.forEachIndexed { index, participant ->
            if (index > 0) append(',')
            participant(participant)
        }
        append("],\"ranking\":[")
        snapshot.ranking.forEachIndexed { index, participantId ->
            if (index > 0) append(',')
            appendQuoted(participantId)
        }
        append("],\"finishedParticipants\":[")
        snapshot.finishedParticipants.forEachIndexed { index, participantId ->
            if (index > 0) append(',')
            appendQuoted(participantId)
        }
        append("],\"finishResults\":[")
        snapshot.finishResults.forEachIndexed { index, result ->
            if (index > 0) append(',')
            finishResult(result)
        }
        append("]}")
    }

    private fun StringBuilder.participant(participant: BehavioralParticipantSnapshot) {
        append('{')
        field("id", participant.id)
        append(',')
        field("surface", participant.surface)
        append(',')
        floatField("x", participant.x)
        append(',')
        floatField("y", participant.y)
        append(',')
        floatField("rotation", participant.rotation)
        append(',')
        floatField("velocityX", participant.velocityX)
        append(',')
        floatField("velocityY", participant.velocityY)
        append(',')
        floatField("angularVelocity", participant.angularVelocity)
        append(',')
        floatField("longitudinalSpeed", participant.longitudinalSpeed)
        append(',')
        floatField("lateralSpeed", participant.lateralSpeed)
        append(',')
        floatField("driftAmount", participant.driftAmount)
        append(',')
        field("checkpoint", participant.checkpoint)
        append(',')
        field("lap", participant.lap)
        append(',')
        field("racePosition", participant.racePosition)
        append(',')
        field("finished", participant.finished)
        append('}')
    }

    private fun StringBuilder.countdown(countdown: BehavioralCountdownSnapshot) {
        append('{')
        field("state", countdown.state)
        append(',')
        floatField("remainingSeconds", countdown.remainingSeconds)
        append('}')
    }

    private fun StringBuilder.progress(progress: BehavioralProgressSnapshot) {
        append('{')
        field("checkpoint", progress.checkpoint)
        append(',')
        field("completedLaps", progress.completedLaps)
        append('}')
    }

    private fun StringBuilder.finishResult(result: BehavioralFinishResultSnapshot) {
        append('{')
        field("participantId", result.participantId)
        append(',')
        field("finishPosition", result.finishPosition)
        append(',')
        floatField("elapsedSimulationTime", result.elapsedSimulationTime)
        append(',')
        nullableFloatField("bestLapTime", result.bestLapTime)
        append('}')
    }

    private fun StringBuilder.field(
        name: String,
        value: String,
    ) {
        appendQuoted(name)
        append(':')
        appendQuoted(value)
    }

    private fun StringBuilder.field(
        name: String,
        value: Int,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.field(
        name: String,
        value: Long,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.field(
        name: String,
        value: Boolean,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.floatField(
        name: String,
        value: Float,
    ) {
        appendQuoted(name)
        append(':')
        appendFloat(value)
    }

    private fun StringBuilder.nullableFloatField(
        name: String,
        value: Float?,
    ) {
        appendQuoted(name)
        append(':')
        if (value == null) append("null") else appendFloat(value)
    }

    private fun StringBuilder.appendFloat(value: Float) {
        require(value.isFinite()) { "Snapshot floats must be finite JSON numbers" }
        val serialized = String.format(Locale.ROOT, "%.6f", value)
        append(if (serialized == NEGATIVE_ZERO) ZERO else serialized)
    }

    private fun StringBuilder.appendQuoted(value: String) {
        append('"')
        append(value.replace("\\", "\\\\").replace("\"", "\\\""))
        append('"')
    }

    private const val NEGATIVE_ZERO = "-0.000000"
    private const val ZERO = "0.000000"
}
