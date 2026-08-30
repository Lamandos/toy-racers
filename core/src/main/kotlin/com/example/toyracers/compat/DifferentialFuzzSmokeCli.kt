package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import java.io.IOException
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

/** Runs the fixed, reproducible Kotlin-versus-Dart differential fuzz suite. */
internal object DifferentialFuzzSmokeCli {
    fun execute(args: Array<String>): DifferentialFuzzReport {
        val options = parseOptions(args)
        return DifferentialFuzzRunner(
            outputDirectory = options.outputDirectory,
            dartWorkingDirectory = options.dartWorkingDirectory,
            dartExecutable = options.dartExecutable,
        ).run(FIXED_SEEDS, SMOKE_TICKS)
    }

    private fun parseOptions(args: Array<String>): DifferentialFuzzSmokeOptions {
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
        return DifferentialFuzzSmokeOptions(
            outputDirectory = Path.of(requireNotNull(values[OUTPUT_OPTION]) { "Missing $OUTPUT_OPTION" }),
            dartWorkingDirectory =
                Path.of(
                    requireNotNull(values[DART_WORKING_DIRECTORY_OPTION]) {
                        "Missing $DART_WORKING_DIRECTORY_OPTION"
                    },
                ),
            dartExecutable = values[DART_EXECUTABLE_OPTION] ?: DEFAULT_DART_EXECUTABLE,
        )
    }

    private data class DifferentialFuzzSmokeOptions(
        val outputDirectory: Path,
        val dartWorkingDirectory: Path,
        val dartExecutable: String,
    )

    const val SMOKE_SCENARIO_COUNT = 100
    const val SMOKE_TICKS = 120
    private const val SEED_STEP = 104_729L
    private const val OUTPUT_OPTION = "--output"
    private const val DART_WORKING_DIRECTORY_OPTION = "--dart-working-directory"
    private const val DART_EXECUTABLE_OPTION = "--dart-executable"
    private const val DEFAULT_DART_EXECUTABLE = "dart"
    private val OPTIONS = setOf(OUTPUT_OPTION, DART_WORKING_DIRECTORY_OPTION, DART_EXECUTABLE_OPTION)
    val FIXED_SEEDS: List<Long> =
        listOf(Long.MIN_VALUE, -1L, 0L, 1L, Long.MAX_VALUE) +
            (1L..95L).map { index -> index * SEED_STEP }
}

/** Coordinates trace generation and comparison for one or more immutable fuzz scenarios. */
internal class DifferentialFuzzRunner(
    private val outputDirectory: Path,
    private val dartWorkingDirectory: Path,
    dartExecutable: String,
    private val dartTraceRunner: DartTraceRunner = ProcessDartTraceRunner(dartExecutable, dartWorkingDirectory),
) {
    fun run(
        seeds: List<Long>,
        ticks: Int,
    ): DifferentialFuzzReport {
        require(seeds.isNotEmpty()) { "Differential fuzz requires at least one seed" }
        require(seeds.distinct().size == seeds.size) { "Differential fuzz seeds must be unique" }
        require(ticks > 0) { "Differential fuzz tick count must be positive" }
        Files.createDirectories(outputDirectory)
        val artifacts = seeds.map { seed -> materializeScenario(seed, ticks) }
        dartTraceRunner.writeTraces(artifacts)
        compareTraces(artifacts)
        return DifferentialFuzzReport(passed = seeds.size, total = seeds.size)
    }

    private fun materializeScenario(
        seed: Long,
        ticks: Int,
    ): DifferentialFuzzArtifact {
        val artifactDirectory = outputDirectory.resolve("seed-${seed.toULong()}")
        val scenarioFile = artifactDirectory.resolve(SCENARIO_FILE_NAME)
        val kotlinTraceFile = artifactDirectory.resolve(KOTLIN_TRACE_FILE_NAME)
        val dartTraceFile = artifactDirectory.resolve(DART_TRACE_FILE_NAME)
        Files.createDirectories(artifactDirectory)
        Files.deleteIfExists(dartTraceFile)

        val scenario = DifferentialFuzzScenarioGenerator.generate(seed, ticks)
        Files.writeString(scenarioFile, DifferentialFuzzScenarioJson.encode(scenario), UTF_8)
        Files.writeString(
            kotlinTraceFile,
            BehavioralTraceJson.encode(BehavioralScenarioRunner(continueAfterFinish = true).run(scenario)),
            UTF_8,
        )
        return DifferentialFuzzArtifact(seed, scenario.id, scenarioFile, kotlinTraceFile, dartTraceFile)
    }

    private fun compareTraces(artifacts: List<DifferentialFuzzArtifact>) {
        artifacts.forEach { artifact ->
            val failure = compare(artifact.kotlinTraceFile, artifact.dartTraceFile, artifact.scenarioId)
            if (failure != null) {
                preserveOnlyFailureTrace(artifacts, artifact.dartTraceFile)
                error("Seed: ${artifact.seed}\n$failure")
            }
            Files.deleteIfExists(artifact.dartTraceFile)
        }
    }

    private fun preserveOnlyFailureTrace(
        artifacts: List<DifferentialFuzzArtifact>,
        failureTrace: Path,
    ) {
        artifacts
            .map(DifferentialFuzzArtifact::dartTraceFile)
            .filter { it != failureTrace }
            .forEach(Files::deleteIfExists)
    }

    private fun compare(
        kotlinTraceFile: Path,
        dartTraceFile: Path,
        scenarioId: String,
    ): String? =
        SnapshotComparisonEngine
            .compare(readTrace(kotlinTraceFile), readTrace(dartTraceFile))
            .failureReport(scenarioId)

    private fun readTrace(path: Path) = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)

    private companion object {
        const val SCENARIO_FILE_NAME = "scenario.json"
        const val KOTLIN_TRACE_FILE_NAME = "kotlin.json"
        const val DART_TRACE_FILE_NAME = "dart.json"
    }
}

/** One materialized fuzz scenario and its Kotlin and Dart trace artifact paths. */
internal data class DifferentialFuzzArtifact(
    val seed: Long,
    val scenarioId: String,
    val scenarioFile: Path,
    val kotlinTraceFile: Path,
    val dartTraceFile: Path,
)

/** Produces normalized Dart traces for materialized compatibility scenarios. */
internal fun interface DartTraceRunner {
    fun writeTraces(artifacts: List<DifferentialFuzzArtifact>)
}

private class ProcessDartTraceRunner(
    private val dartExecutable: String,
    private val dartWorkingDirectory: Path,
) : DartTraceRunner {
    override fun writeTraces(artifacts: List<DifferentialFuzzArtifact>) {
        val process =
            ProcessBuilder(command(artifacts))
                .directory(dartWorkingDirectory.toFile())
                .redirectErrorStream(true)
                .start()
        val output = process.inputStream.bufferedReader(UTF_8).use { it.readText().trim() }
        val exitCode = process.waitFor()
        require(exitCode == SUCCESS_EXIT_CODE) {
            "Dart behavior runner exited with status $exitCode.${output.asFailureSuffix()}"
        }
        artifacts.forEach { artifact ->
            require(Files.isRegularFile(artifact.dartTraceFile)) {
                "Dart behavior runner did not create ${artifact.dartTraceFile}"
            }
        }
    }

    private fun command(artifacts: List<DifferentialFuzzArtifact>): List<String> =
        buildList {
            add(dartExecutable)
            add("run")
            add(DART_FUZZ_RUNNER)
            artifacts.forEach { artifact ->
                add(SCENARIO_OPTION)
                add(artifact.scenarioFile.toString())
                add(OUTPUT_OPTION)
                add(artifact.dartTraceFile.toString())
            }
        }

    private fun String.asFailureSuffix(): String = takeIf(String::isNotEmpty)?.let { "\n$it" } ?: ""

    private companion object {
        const val SUCCESS_EXIT_CODE = 0
        const val DART_FUZZ_RUNNER = "tool/differential_fuzz_runner.dart"
        const val SCENARIO_OPTION = "--scenario"
        const val OUTPUT_OPTION = "--output"
    }
}

/** Summary printed after every complete differential fuzz invocation. */
internal data class DifferentialFuzzReport(
    val passed: Int,
    val total: Int,
) {
    fun format(): String = "Differential fuzz:\n$passed / $total PASS"
}

fun main(args: Array<String>) {
    try {
        val report = DifferentialFuzzSmokeCli.execute(args)
        println(report.format())
    } catch (exception: IllegalArgumentException) {
        failDifferentialFuzzSmoke(exception)
    } catch (exception: IllegalStateException) {
        failDifferentialFuzzSmoke(exception)
    } catch (exception: IOException) {
        failDifferentialFuzzSmoke(exception)
    } catch (exception: InterruptedException) {
        Thread.currentThread().interrupt()
        failDifferentialFuzzSmoke(exception)
    }
}

private fun failDifferentialFuzzSmoke(exception: Exception): Nothing {
    System.err.println("Differential fuzz failed: ${exception.message}")
    exitProcess(1)
}
