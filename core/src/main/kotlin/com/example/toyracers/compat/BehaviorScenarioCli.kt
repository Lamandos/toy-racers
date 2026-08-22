package com.example.toyracers.compat

import java.io.IOException
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

/** Command-line entry point for replaying one behavior scenario without a graphics backend. */
internal object BehaviorScenarioCli {
    fun execute(args: Array<String>) {
        val options = parseOptions(args)
        val trace =
            BehavioralScenarioRunner(
                continueAfterFinish = true,
            ).run(BehavioralScenarioLoader.load(options.scenario))
        options.output.parent?.let(Files::createDirectories)
        Files.writeString(options.output, BehavioralTraceJson.encode(trace), UTF_8)
    }

    private fun parseOptions(args: Array<String>): BehaviorScenarioCliOptions {
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
        return BehaviorScenarioCliOptions(
            scenario = Path.of(requireNotNull(values[SCENARIO_OPTION]) { "Missing $SCENARIO_OPTION" }),
            output = Path.of(requireNotNull(values[OUTPUT_OPTION]) { "Missing $OUTPUT_OPTION" }),
        )
    }

    private data class BehaviorScenarioCliOptions(
        val scenario: Path,
        val output: Path,
    )

    private const val SCENARIO_OPTION = "--scenario"
    private const val OUTPUT_OPTION = "--output"
    private val OPTIONS = setOf(SCENARIO_OPTION, OUTPUT_OPTION)
}

fun main(args: Array<String>) {
    try {
        BehaviorScenarioCli.execute(args)
    } catch (exception: IllegalArgumentException) {
        fail(exception)
    } catch (exception: IOException) {
        fail(exception)
    }
}

private fun fail(exception: Exception): Nothing {
    System.err.println("Behavior scenario failed: ${exception.message}")
    exitProcess(1)
}
