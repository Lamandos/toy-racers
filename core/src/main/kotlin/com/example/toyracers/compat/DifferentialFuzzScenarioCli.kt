package com.example.toyracers.compat

import java.io.IOException
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

/** Command-line entry point for creating one reproducible differential fuzz scenario. */
internal object DifferentialFuzzScenarioCli {
    fun execute(args: Array<String>) {
        val options = parseOptions(args)
        val scenario = DifferentialFuzzScenarioGenerator.generate(options.seed, options.ticks)
        val json = DifferentialFuzzScenarioJson.encode(scenario)
        options.output?.let { output ->
            output.parent?.let(Files::createDirectories)
            Files.writeString(output, json, UTF_8)
        } ?: println(json)
    }

    private fun parseOptions(args: Array<String>): DifferentialFuzzScenarioCliOptions {
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
        return DifferentialFuzzScenarioCliOptions(
            seed = values.requiredLong(SEED_OPTION, "a signed 64-bit integer"),
            ticks = values.requiredPositiveInt(TICKS_OPTION),
            output = values[OUTPUT_OPTION]?.let(Path::of),
        )
    }

    private fun Map<String, String>.requiredLong(
        option: String,
        description: String,
    ): Long {
        val value = requireNotNull(this[option]) { "Missing $option" }
        return requireNotNull(value.toLongOrNull()) { "$option must be $description" }
    }

    private fun Map<String, String>.requiredPositiveInt(option: String): Int {
        val value = requireNotNull(this[option]) { "Missing $option" }
        val ticks = requireNotNull(value.toIntOrNull()) { "$option must be a positive integer" }
        require(ticks > 0) { "$option must be a positive integer" }
        return ticks
    }

    private data class DifferentialFuzzScenarioCliOptions(
        val seed: Long,
        val ticks: Int,
        val output: Path?,
    )

    private const val SEED_OPTION = "--seed"
    private const val TICKS_OPTION = "--ticks"
    private const val OUTPUT_OPTION = "--output"
    private val OPTIONS = setOf(SEED_OPTION, TICKS_OPTION, OUTPUT_OPTION)
}

fun main(args: Array<String>) {
    try {
        DifferentialFuzzScenarioCli.execute(args)
    } catch (exception: IllegalArgumentException) {
        failDifferentialFuzzGeneration(exception)
    } catch (exception: IOException) {
        failDifferentialFuzzGeneration(exception)
    }
}

private fun failDifferentialFuzzGeneration(exception: Exception): Nothing {
    System.err.println("Differential fuzz scenario generation failed: ${exception.message}")
    exitProcess(1)
}
