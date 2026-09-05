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
        val comparisons =
            options.manifest
                ?.let(::readManifest)
                ?: listOf(
                    TracePair(
                        "trace",
                        requireNotNull(options.expected),
                        requireNotNull(options.actual),
                    ),
                )
        val failures =
            comparisons
                .mapNotNull { comparison ->
                    val expected = readTrace(comparison.expected)
                    val actual = readTrace(comparison.actual)
                    SnapshotComparisonEngine
                        .compare(expected, actual)
                        .failureReport(scenarioId(expected))
                        ?.let { "${comparison.label}:\n$it" }
                }
        require(failures.isEmpty()) { failures.joinToString("\n\n") }
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
        val manifest = values[MANIFEST_OPTION]?.let(Path::of)
        val expected = values[EXPECTED_OPTION]?.let(Path::of)
        val actual = values[ACTUAL_OPTION]?.let(Path::of)
        require(
            (manifest != null && expected == null && actual == null) ||
                (manifest == null && expected != null && actual != null),
        ) { "Supply either $MANIFEST_OPTION or both $EXPECTED_OPTION and $ACTUAL_OPTION" }
        return BehaviorTraceComparisonOptions(expected, actual, manifest)
    }

    private fun readManifest(path: Path): List<TracePair> {
        val root = readTrace(path)
        require(root.isArray) { "Comparison manifest must be a JSON array" }
        return generateSequence(root.child) { it.next }
            .mapIndexed { index, entry ->
                require(entry.isObject) { "Comparison manifest entry $index must be an object" }
                TracePair(
                    label = entry.requiredString("label", index),
                    expected = Path.of(entry.requiredString("expected", index)),
                    actual = Path.of(entry.requiredString("actual", index)),
                )
            }.toList()
            .also { require(it.isNotEmpty()) { "Comparison manifest must not be empty" } }
    }

    private fun JsonValue.requiredString(
        name: String,
        index: Int,
    ): String = requireNotNull(get(name)?.asString()) { "Missing $name in manifest entry $index" }

    private fun readTrace(path: Path): JsonValue = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)

    private fun scenarioId(trace: JsonValue): String = trace.get("scenarioId")?.asString() ?: "unknown"

    private data class BehaviorTraceComparisonOptions(
        val expected: Path?,
        val actual: Path?,
        val manifest: Path?,
    )

    private data class TracePair(
        val label: String,
        val expected: Path,
        val actual: Path,
    )

    private const val ACTUAL_OPTION = "--actual"
    private const val EXPECTED_OPTION = "--expected"
    private const val MANIFEST_OPTION = "--manifest"
    private val OPTIONS = setOf(EXPECTED_OPTION, ACTUAL_OPTION, MANIFEST_OPTION)
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
