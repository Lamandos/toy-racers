package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

/** Expensive release gate that detects run-to-run nondeterminism across every behavioral fixture. */
class BehavioralSuiteStabilityTest {
    @Test
    fun `full behavioral fixture inventory is stable across twenty sequential suite runs`() {
        val fixtures = fixtures()
        val expected = fixtures.map(SuiteFixture::run)

        repeat(REPEAT_RUN_COUNT - 1) { repeatIndex ->
            fixtures.zip(expected).forEach { (fixture, firstOutput) ->
                assertEquals(
                    "${fixture.label} diverged during suite run ${repeatIndex + 2}",
                    firstOutput,
                    fixture.run(),
                )
            }
        }
    }

    private fun fixtures(): List<SuiteFixture> {
        val legacy =
            BehavioralFixtureLoader.scenarios().map { scenario ->
                SuiteFixture("legacy/${scenario.id}", scenario, BehavioralScenarioRunner())
            }
        val compatibility =
            compatibilityScenarios().map { scenario ->
                SuiteFixture("compatibility/${scenario.id}", scenario, BehavioralScenarioRunner(true))
            }
        val stress =
            stressScenarios().map { scenario ->
                SuiteFixture("stress/${scenario.id}", scenario, BehavioralScenarioRunner())
            }
        val fixtures = legacy + compatibility + stress

        assertEquals(EXPECTED_FIXTURE_COUNT, fixtures.size)
        assertEquals(fixtures.size, fixtures.map(SuiteFixture::label).toSet().size)
        assertTrue(fixtures.any { fixture -> fixture.scenario.fullRace })
        return fixtures
    }

    private fun compatibilityScenarios(): List<BehavioralScenario> {
        val scenarioDirectory = compatibilityDirectory().resolve("scenarios")
        val files =
            Files.walk(scenarioDirectory).use { paths ->
                paths
                    .filter(Files::isRegularFile)
                    .filter { path -> path.isJson() }
                    .sorted()
                    .toList()
            }
        return files
            .filterNot(referencedInputScriptPaths(files)::contains)
            .map(BehavioralScenarioLoader::load)
    }

    private fun stressScenarios(): List<BehavioralScenario> =
        STRESS_FILES.map { fileName ->
            val root =
                requireNotNull(javaClass.classLoader.getResourceAsStream("compat/stress/$fileName"))
                    .bufferedReader()
                    .use(JsonReader()::parse)
            BehavioralFixtureLoader.parseScenarioDocument(root).single()
        }

    private fun compatibilityDirectory(): Path =
        Path.of(requireNotNull(System.getProperty(COMPATIBILITY_DIRECTORY_PROPERTY))).toAbsolutePath()

    private fun Path.isJson(): Boolean = fileName.toString().endsWith(JSON_SUFFIX)

    private data class SuiteFixture(
        val label: String,
        val scenario: BehavioralScenario,
        val runner: BehavioralScenarioRunner,
    ) {
        fun run(): String = BehavioralTraceJson.encode(runner.run(scenario))
    }

    private companion object {
        const val COMPATIBILITY_DIRECTORY_PROPERTY = "compatibilityDirectory"
        const val EXPECTED_FIXTURE_COUNT = 115
        const val JSON_SUFFIX = ".json"
        const val REPEAT_RUN_COUNT = 20
        val STRESS_FILES = listOf("long_running_1000.json", "long_running_5000.json")
    }
}
