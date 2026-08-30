package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import java.io.IOException
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import kotlin.system.exitProcess

/** Runs the Dart long-running fixtures against the Kotlin behavioral oracle. */
internal object DartStressDeterminismCli {
    fun execute(args: Array<String>): DartStressComparisonReport {
        val options = parseOptions(args)
        return DartStressComparisonRunner(
            outputDirectory = options.outputDirectory,
            stressFixtureDirectory = options.stressFixtureDirectory,
            dartWorkingDirectory = options.dartWorkingDirectory,
            dartExecutable = options.dartExecutable,
        ).run()
    }

    private fun parseOptions(args: Array<String>): DartStressDeterminismOptions {
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
        return DartStressDeterminismOptions(
            outputDirectory = Path.of(requireNotNull(values[OUTPUT_OPTION]) { "Missing $OUTPUT_OPTION" }),
            stressFixtureDirectory =
                Path.of(requireNotNull(values[STRESS_FIXTURES_OPTION]) { "Missing $STRESS_FIXTURES_OPTION" }),
            dartWorkingDirectory =
                Path.of(
                    requireNotNull(values[DART_WORKING_DIRECTORY_OPTION]) {
                        "Missing $DART_WORKING_DIRECTORY_OPTION"
                    },
                ),
            dartExecutable = values[DART_EXECUTABLE_OPTION] ?: DEFAULT_DART_EXECUTABLE,
        )
    }

    private data class DartStressDeterminismOptions(
        val outputDirectory: Path,
        val stressFixtureDirectory: Path,
        val dartWorkingDirectory: Path,
        val dartExecutable: String,
    )

    private const val DART_EXECUTABLE_OPTION = "--dart-executable"
    private const val DART_WORKING_DIRECTORY_OPTION = "--dart-working-directory"
    private const val DEFAULT_DART_EXECUTABLE = "dart"
    private const val OUTPUT_OPTION = "--output"
    private const val STRESS_FIXTURES_OPTION = "--stress-fixtures"
    private val OPTIONS =
        setOf(OUTPUT_OPTION, STRESS_FIXTURES_OPTION, DART_WORKING_DIRECTORY_OPTION, DART_EXECUTABLE_OPTION)
}

/** Coordinates Dart deterministic replay and comparison for the two stress fixtures. */
internal class DartStressComparisonRunner(
    private val outputDirectory: Path,
    private val stressFixtureDirectory: Path,
    private val dartWorkingDirectory: Path,
    dartExecutable: String,
    private val dartTraceRunner: DartStressTraceRunner =
        ProcessDartStressTraceRunner(dartExecutable, dartWorkingDirectory),
) {
    fun run(): DartStressComparisonReport {
        Files.createDirectories(outputDirectory)
        val artifacts = STRESS_FIXTURE_NAMES.map(::materializeArtifact)
        val dartReport = dartTraceRunner.writeTraces(artifacts)
        require(dartReport.contains(DART_DETERMINISM_SUCCESS)) {
            "Dart stress runner did not report $DART_DETERMINISM_SUCCESS"
        }
        artifacts.forEach(::compareTraces)
        return DartStressComparisonReport(dartReport.trim(), artifacts.size)
    }

    private fun materializeArtifact(fixtureName: String): DartStressArtifact {
        val scenarioFile = stressFixtureDirectory.resolve(fixtureName)
        require(Files.isRegularFile(scenarioFile)) { "Stress scenario does not exist: $scenarioFile" }
        val artifactDirectory = outputDirectory.resolve(scenarioFile.fileName.toString().removeSuffix(".json"))
        val kotlinTraceFile = artifactDirectory.resolve(KOTLIN_TRACE_FILE_NAME)
        val dartTraceFile = artifactDirectory.resolve(DART_TRACE_FILE_NAME)
        Files.createDirectories(artifactDirectory)

        val scenario = BehavioralScenarioLoader.load(scenarioFile)
        Files.writeString(
            kotlinTraceFile,
            BehavioralTraceJson.encode(BehavioralScenarioRunner(continueAfterFinish = true).run(scenario)),
            UTF_8,
        )
        return DartStressArtifact(scenario.id, scenarioFile, kotlinTraceFile, dartTraceFile)
    }

    private fun compareTraces(artifact: DartStressArtifact) {
        require(Files.isRegularFile(artifact.dartTraceFile)) {
            "Dart stress runner did not create ${artifact.dartTraceFile}"
        }
        val failure =
            SnapshotComparisonEngine
                .compare(readTrace(artifact.kotlinTraceFile), readTrace(artifact.dartTraceFile))
                .failureReport(artifact.scenarioId)
        require(failure == null) { "Stress fixture: ${artifact.scenarioId}\n$failure" }
    }

    private fun readTrace(path: Path) = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)

    private companion object {
        const val DART_DETERMINISM_SUCCESS = "Dart determinism: 20 / 20 identical"
        const val DART_TRACE_FILE_NAME = "dart.json"
        const val KOTLIN_TRACE_FILE_NAME = "kotlin.json"
        val STRESS_FIXTURE_NAMES = listOf("long_running_1000.json", "long_running_5000.json")
    }
}

/** One immutable stress scenario and its Kotlin and Dart trace paths. */
internal data class DartStressArtifact(
    val scenarioId: String,
    val scenarioFile: Path,
    val kotlinTraceFile: Path,
    val dartTraceFile: Path,
)

/** Produces normalized Dart traces and reports its repeated-run result. */
internal fun interface DartStressTraceRunner {
    fun writeTraces(artifacts: List<DartStressArtifact>): String
}

private class ProcessDartStressTraceRunner(
    private val dartExecutable: String,
    private val dartWorkingDirectory: Path,
) : DartStressTraceRunner {
    override fun writeTraces(artifacts: List<DartStressArtifact>): String {
        val process =
            ProcessBuilder(command(artifacts))
                .directory(dartWorkingDirectory.toFile())
                .redirectErrorStream(true)
                .start()
        val output = process.inputStream.bufferedReader(UTF_8).use { it.readText().trim() }
        val exitCode = process.waitFor()
        require(exitCode == SUCCESS_EXIT_CODE) {
            "Dart stress runner exited with status $exitCode.${output.asFailureSuffix()}"
        }
        return output
    }

    private fun command(artifacts: List<DartStressArtifact>): List<String> =
        buildList {
            add(dartExecutable)
            add("run")
            add(DART_STRESS_RUNNER)
            add(REPEAT_COUNT_OPTION)
            add(REPEAT_COUNT.toString())
            artifacts.forEach { artifact ->
                add(SCENARIO_OPTION)
                add(artifact.scenarioFile.toString())
                add(OUTPUT_OPTION)
                add(artifact.dartTraceFile.toString())
            }
        }

    private fun String.asFailureSuffix(): String = takeIf(String::isNotEmpty)?.let { "\n$it" } ?: ""

    private companion object {
        const val DART_STRESS_RUNNER = "tool/stress_determinism_runner.dart"
        const val OUTPUT_OPTION = "--output"
        const val REPEAT_COUNT = 20
        const val REPEAT_COUNT_OPTION = "--repeat-count"
        const val SCENARIO_OPTION = "--scenario"
        const val SUCCESS_EXIT_CODE = 0
    }
}

/** Stable summary printed after every complete Kotlin-versus-Dart stress invocation. */
internal data class DartStressComparisonReport(
    private val dartReport: String,
    val total: Int,
) {
    fun format(): String = "$dartReport\nKotlin-vs-Dart stress: $total / $total PASS"
}

fun main(args: Array<String>) {
    try {
        println(DartStressDeterminismCli.execute(args).format())
    } catch (exception: IllegalArgumentException) {
        failDartStressComparison(exception)
    } catch (exception: IllegalStateException) {
        failDartStressComparison(exception)
    } catch (exception: IOException) {
        failDartStressComparison(exception)
    } catch (exception: InterruptedException) {
        Thread.currentThread().interrupt()
        failDartStressComparison(exception)
    }
}

private fun failDartStressComparison(exception: Exception): Nothing {
    System.err.println("Dart stress comparison failed: ${exception.message}")
    exitProcess(1)
}
