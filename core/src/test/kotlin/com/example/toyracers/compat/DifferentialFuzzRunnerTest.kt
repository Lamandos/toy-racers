package com.example.toyracers.compat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path

class DifferentialFuzzRunnerTest {
    @Test
    fun `matching trace keeps scenario and Kotlin trace but removes Dart trace`() {
        val outputDirectory = Files.createTempDirectory("differential-fuzz-runner-")
        try {
            val report =
                DifferentialFuzzRunner(
                    outputDirectory = outputDirectory,
                    dartWorkingDirectory = outputDirectory,
                    dartExecutable = "unused",
                    dartTraceRunner = ReferenceDartTraceRunner(),
                ).run(listOf(1L), ticks = 2)

            val artifacts = outputDirectory.resolve("seed-1")
            assertTrue(Files.isRegularFile(artifacts.resolve("scenario.json")))
            assertTrue(Files.isRegularFile(artifacts.resolve("kotlin.json")))
            assertFalse(Files.exists(artifacts.resolve("dart.json")))
            assertTrue(report.format().contains("1 / 1 PASS"))
        } finally {
            deleteRecursively(outputDirectory)
        }
    }

    @Test
    fun `mismatch keeps Dart trace and reports seed tick field expected actual and delta`() {
        val outputDirectory = Files.createTempDirectory("differential-fuzz-mismatch-")
        try {
            val failure =
                assertThrows(IllegalStateException::class.java) {
                    DifferentialFuzzRunner(
                        outputDirectory = outputDirectory,
                        dartWorkingDirectory = outputDirectory,
                        dartExecutable = "unused",
                        dartTraceRunner = DivergentDartTraceRunner(),
                    ).run(listOf(1L), ticks = 2)
                }

            assertTrue(failure.message.orEmpty().contains("Seed: 1"))
            assertTrue(failure.message.orEmpty().contains("First mismatch: tick 0"))
            assertTrue(failure.message.orEmpty().contains("field"))
            assertTrue(failure.message.orEmpty().contains("expected"))
            assertTrue(failure.message.orEmpty().contains("actual"))
            assertTrue(failure.message.orEmpty().contains("delta"))
            assertTrue(Files.isRegularFile(outputDirectory.resolve("seed-1/dart.json")))
        } finally {
            deleteRecursively(outputDirectory)
        }
    }

    private open class ReferenceDartTraceRunner : DartTraceRunner {
        override fun writeTraces(artifacts: List<DifferentialFuzzArtifact>) {
            artifacts.forEach { artifact -> writeReferenceTrace(artifact) }
        }

        protected fun writeReferenceTrace(artifact: DifferentialFuzzArtifact) {
            val scenario = BehavioralScenarioLoader.load(artifact.scenarioFile)
            val trace = BehavioralScenarioRunner(continueAfterFinish = true).run(scenario)
            Files.writeString(artifact.dartTraceFile, BehavioralTraceJson.encode(trace), UTF_8)
        }
    }

    private class DivergentDartTraceRunner : ReferenceDartTraceRunner() {
        override fun writeTraces(artifacts: List<DifferentialFuzzArtifact>) {
            super.writeTraces(artifacts)
            val outputFile = artifacts.single().dartTraceFile
            Files.writeString(
                outputFile,
                Files.readString(outputFile).replaceFirst(
                    "\"elapsedSimulationTime\":0.000000",
                    "\"elapsedSimulationTime\":0.500000",
                ),
                UTF_8,
            )
        }
    }

    private fun deleteRecursively(path: Path) {
        Files.walk(path).use { paths -> paths.sorted(Comparator.reverseOrder()).forEach(Files::delete) }
    }
}
