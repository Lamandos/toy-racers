package com.example.toyracers.compat

import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path

class DartStressComparisonRunnerTest {
    @Test
    fun `matching Dart stress traces report both fixture comparisons as passing`() {
        val fixture = createFixture()
        try {
            val report =
                DartStressComparisonRunner(
                    outputDirectory = fixture.outputDirectory,
                    stressFixtureDirectory = fixture.stressDirectory,
                    dartWorkingDirectory = fixture.stressDirectory,
                    dartExecutable = "unused",
                    dartTraceRunner = ReferenceDartStressTraceRunner(),
                ).run()

            assertTrue(report.format().contains("Dart determinism: 20 / 20 identical"))
            assertTrue(report.format().contains("Kotlin-vs-Dart stress: 2 / 2 PASS"))
            assertTrue(Files.isRegularFile(fixture.outputDirectory.resolve("long_running_1000/dart.json")))
            assertTrue(Files.isRegularFile(fixture.outputDirectory.resolve("long_running_5000/dart.json")))
        } finally {
            deleteRecursively(fixture.root)
        }
    }

    @Test
    fun `divergent Dart stress trace keeps artifacts and reports the fixture`() {
        val fixture = createFixture()
        try {
            val failure =
                assertThrows(IllegalArgumentException::class.java) {
                    DartStressComparisonRunner(
                        outputDirectory = fixture.outputDirectory,
                        stressFixtureDirectory = fixture.stressDirectory,
                        dartWorkingDirectory = fixture.stressDirectory,
                        dartExecutable = "unused",
                        dartTraceRunner = DivergentDartStressTraceRunner(),
                    ).run()
                }

            assertTrue(failure.message.orEmpty().contains("Stress fixture:"))
            assertTrue(failure.message.orEmpty().contains("stress-long-running-5000"))
            assertTrue(Files.isRegularFile(fixture.outputDirectory.resolve("long_running_5000/kotlin.json")))
            assertTrue(Files.isRegularFile(fixture.outputDirectory.resolve("long_running_5000/dart.json")))
        } finally {
            deleteRecursively(fixture.root)
        }
    }

    private fun createFixture(): StressFixture {
        val root = Files.createTempDirectory("dart-stress-comparison-")
        val stressDirectory = root.resolve("stress")
        Files.createDirectories(stressDirectory)
        STRESS_FIXTURE_NAMES.forEach { name ->
            javaClass.classLoader.getResourceAsStream("compat/stress/$name").use { source ->
                requireNotNull(source) { "Missing test fixture: $name" }
                Files.copy(source, stressDirectory.resolve(name))
            }
        }
        return StressFixture(root, stressDirectory, root.resolve("output"))
    }

    private fun deleteRecursively(path: Path) {
        Files.walk(path).use { paths -> paths.sorted(Comparator.reverseOrder()).forEach(Files::delete) }
    }

    private open class ReferenceDartStressTraceRunner : DartStressTraceRunner {
        override fun writeTraces(artifacts: List<DartStressArtifact>): String {
            artifacts.forEach(::writeReferenceTrace)
            return DART_SUCCESS_REPORT
        }

        protected fun writeReferenceTrace(artifact: DartStressArtifact) {
            val scenario = BehavioralScenarioLoader.load(artifact.scenarioFile)
            val trace = BehavioralScenarioRunner(continueAfterFinish = true).run(scenario)
            Files.writeString(artifact.dartTraceFile, BehavioralTraceJson.encode(trace), UTF_8)
        }
    }

    private class DivergentDartStressTraceRunner : ReferenceDartStressTraceRunner() {
        override fun writeTraces(artifacts: List<DartStressArtifact>): String {
            super.writeTraces(artifacts)
            val outputFile = artifacts.last().dartTraceFile
            Files.writeString(
                outputFile,
                Files.readString(outputFile).replaceFirst(
                    "\"elapsedSimulationTime\":0.000000",
                    "\"elapsedSimulationTime\":0.500000",
                ),
                UTF_8,
            )
            return DART_SUCCESS_REPORT
        }
    }

    private data class StressFixture(
        val root: Path,
        val stressDirectory: Path,
        val outputDirectory: Path,
    )

    private companion object {
        const val DART_SUCCESS_REPORT =
            "Dart stress:\n1,000 ticks PASS\n5,000 ticks PASS\nDart determinism: 20 / 20 identical"
        val STRESS_FIXTURE_NAMES = listOf("long_running_1000.json", "long_running_5000.json")
    }
}
