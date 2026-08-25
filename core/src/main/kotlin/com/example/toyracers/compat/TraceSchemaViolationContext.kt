package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue

/** Recovers trace location identifiers for a schema violation reported by a complete trace. */
internal object TraceSchemaViolationContext {
    fun resolve(
        trace: JsonValue,
        path: String,
    ): ComparisonContext {
        if (!trace.isObject) return ComparisonContext()
        val sampleIndex = path.indexedSegmentIndex(SAMPLES_PATH) ?: return ComparisonContext()
        val sample = trace.get(SAMPLES_FIELD)?.takeIf { it.isArray }?.get(sampleIndex)
        val sampleObject = sample?.takeIf { it.isObject }
        val context =
            ComparisonContext(
                tick = sampleObject?.get(TICK_FIELD).integerValueOrNull(),
                sampleIndex = sampleIndex,
                sampleLabel = sampleObject?.get(LABEL_FIELD).stringValueOrNull(),
            )
        return context.copy(participant = participantIdentifier(trace, path, sampleIndex))
    }

    private fun participantIdentifier(
        trace: JsonValue,
        path: String,
        sampleIndex: Int,
    ): String? =
        participantIdentifier(trace, path, sampleIndex, PARTICIPANTS_FIELD, ID_FIELD)
            ?: participantIdentifier(trace, path, sampleIndex, FINISH_RESULTS_FIELD, PARTICIPANT_ID_FIELD)

    private fun participantIdentifier(
        trace: JsonValue,
        path: String,
        sampleIndex: Int,
        collectionField: String,
        identifierField: String,
    ): String? {
        val collectionPath = "$SAMPLES_PATH[$sampleIndex].snapshot.$collectionField"
        val participantIndex = path.indexedSegmentIndex(collectionPath) ?: return null
        return trace
            .get(SAMPLES_FIELD)
            ?.get(sampleIndex)
            ?.get(SNAPSHOT_FIELD)
            ?.get(collectionField)
            ?.takeIf { it.isArray }
            ?.get(participantIndex)
            ?.get(identifierField)
            .stringValueOrNull()
    }

    private fun String.indexedSegmentIndex(prefix: String): Int? {
        val opening = "$prefix["
        if (!startsWith(opening)) return null
        val closing = indexOf(']', opening.length)
        if (closing < 0) return null
        return substring(opening.length, closing).toIntOrNull()
    }

    private fun JsonValue?.integerValueOrNull(): Long? = takeIf { it?.isLong == true }?.asLong()

    private fun JsonValue?.stringValueOrNull(): String? = takeIf { it?.isString == true }?.asString()

    private const val SAMPLES_PATH = "$.samples"
    private const val SAMPLES_FIELD = "samples"
    private const val LABEL_FIELD = "label"
    private const val TICK_FIELD = "tick"
    private const val SNAPSHOT_FIELD = "snapshot"
    private const val PARTICIPANTS_FIELD = "participants"
    private const val FINISH_RESULTS_FIELD = "finishResults"
    private const val ID_FIELD = "id"
    private const val PARTICIPANT_ID_FIELD = "participantId"
}
