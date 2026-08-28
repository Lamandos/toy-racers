package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
import java.io.IOException
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

/** Command-line entry point for comparing a trace from any contract implementation. */
internal object BehaviorTraceComparisonCli {
    fun execute(args: Array<String>) {
        val options = parseOptions(args)
        val expected = readTrace(options.expected)
        val actual = readTrace(options.actual)
        val report = SnapshotComparisonEngine.compare(expected, actual).failureReport(scenarioId(expected))
        if (report != null) throw IllegalArgumentException(report)
    }

    private fun parseOptions(args: Array<String>): BehaviorTraceComparisonOptions {
        val values = mutableMapOf<String, String>()
        var index = 0
        while (index < args.size) {
            val name = args[index]
            require(name in OPTIONS) { "Unknown option: $name" }
            val value = args.getOrNull(index + 1)
            require(value != null && !value.startsWith("--")) { "Missing value for $name" }
            require(values.put(name, value) == null) { "Option may only be supplied once: $name" }
            index += 2
        }
        return BehaviorTraceComparisonOptions(
            expected = Path.of(requireNotNull(values[EXPECTED_OPTION]) { "Missing $EXPECTED_OPTION" }),
            actual = Path.of(requireNotNull(values[ACTUAL_OPTION]) { "Missing $ACTUAL_OPTION" }),
        )
    }

    private fun readTrace(path: Path): JsonValue = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)

    private fun scenarioId(trace: JsonValue): String = trace.get("scenarioId")?.asString() ?: "unknown"

    private data class BehaviorTraceComparisonOptions(
        val expected: Path,
        val actual: Path,
    )

    private const val ACTUAL_OPTION = "--actual"
    private const val EXPECTED_OPTION = "--expected"
    private val OPTIONS = setOf(EXPECTED_OPTION, ACTUAL_OPTION)
}

fun main(args: Array<String>) {
    try {
        BehaviorTraceComparisonCli.execute(args)
    } catch (exception: IllegalArgumentException) {
        failComparison(exception)
    } catch (exception: IOException) {
        failComparison(exception)
    }
}

private fun failComparison(exception: Exception): Nothing {
    System.err.println("Behavior trace comparison failed: ${exception.message}")
    exitProcess(1)
}
