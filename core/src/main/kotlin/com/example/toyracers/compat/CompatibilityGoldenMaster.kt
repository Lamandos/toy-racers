package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path

/** Verifies and explicitly regenerates the checked-in, file-per-scenario golden traces. */
internal class CompatibilityGoldenMaster(
    scenarioDirectory: Path,
    goldenDirectory: Path,
) {
    private val scenarios = scenarioDirectory.toAbsolutePath().normalize()
    private val goldens = goldenDirectory.toAbsolutePath().normalize()
    private val runner = BehavioralScenarioRunner(continueAfterFinish = true)

    fun verify() {
        val fixtures = fixtures()
        verifyNoOrphanedGoldens(fixtures)
        val differences = fixtures.mapNotNull(::difference)
        check(differences.isEmpty()) {
            "Compatibility golden verification failed:\n${differences.joinToString("\n")}"
        }
    }

    fun regenerate(): List<Path> {
        val fixtures = fixtures()
        verifyNoOrphanedGoldens(fixtures)
        val generatedGoldens =
            fixtures.map { fixture ->
                GeneratedGolden(fixture, generatedGolden(fixture))
            }
        return generatedGoldens.mapNotNull { generated ->
            val existing =
                generated.fixture.golden
                    .takeIf(Files::isRegularFile)
                    ?.let { Files.readString(it, UTF_8) }
            if (existing == generated.content) {
                null
            } else {
                generated.fixture.golden.parent
                    ?.let(Files::createDirectories)
                Files.writeString(generated.fixture.golden, generated.content, UTF_8)
                generated.fixture.golden
            }
        }
    }

    private fun fixtures(): List<GoldenFixture> {
        require(Files.isDirectory(scenarios)) { "Scenario directory does not exist: $scenarios" }
        val files = jsonFiles(scenarios)
        val inputScripts = inputScriptPaths(files)
        val referencedScripts = files.flatMap(::referencedInputScripts).toSet()
        val fixtures =
            files
                .filterNot { path -> path in inputScripts && path in referencedScripts }
                .map(::fixture)
        require(fixtures.isNotEmpty()) { "No compatibility scenarios found in $scenarios" }
        val duplicateIds =
            fixtures
                .groupBy { it.scenario.id }
                .filterValues { it.size > 1 }
                .keys
                .sorted()
        require(duplicateIds.isEmpty()) {
            "Compatibility scenario IDs must be unique: ${duplicateIds.joinToString(", ")}"
        }
        return fixtures
    }

    private fun inputScriptPaths(files: List<Path>): Set<Path> =
        files
            .filter { path ->
                val root = readJson(path)
                if (root.has(SCENARIOS_FIELD)) {
                    false
                } else {
                    BehavioralScenarioValidator.validateInputScript(root, path.toString())
                    true
                }
            }.toSet()

    private fun referencedInputScripts(path: Path): List<Path> {
        val root = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)
        val scenarios = root.get("scenarios")?.takeIf { it.isArray } ?: return emptyList()
        return scenarios
            .children()
            .mapNotNull { scenario ->
                scenario
                    .get(INPUT_SCRIPT_FIELD)
                    ?.takeIf { it.isString }
                    ?.asString()
                    ?.let(path.parent::resolve)
                    ?.normalize()
            }
    }

    private fun fixture(path: Path): GoldenFixture {
        val relative = scenarios.relativize(path)
        val golden = goldens.resolve(relative).normalize()
        check(golden.startsWith(goldens)) { "Invalid golden path for scenario: $path" }
        return GoldenFixture(golden, BehavioralScenarioLoader.load(path))
    }

    private fun difference(fixture: GoldenFixture): String? {
        if (!Files.isRegularFile(fixture.golden)) {
            return "Missing golden for ${fixture.scenario.id}: ${fixture.golden}"
        }
        val expected = Files.newBufferedReader(fixture.golden, UTF_8).use(JsonReader()::parse)
        val actual = JsonReader().parse(generatedGolden(fixture))
        return BehavioralTraceJson.firstDifference(expected, actual)?.let { difference ->
            "${fixture.scenario.id}: $difference"
        }
    }

    private fun generatedGolden(fixture: GoldenFixture): String =
        BehavioralTraceJson.encode(runner.run(fixture.scenario)) + "\n"

    private fun verifyNoOrphanedGoldens(fixtures: List<GoldenFixture>) {
        val expectedGoldens = fixtures.map(GoldenFixture::golden).toSet()
        val unexpected = jsonFiles(goldens).filterNot(expectedGoldens::contains)
        require(unexpected.isEmpty()) {
            "Golden files without a matching scenario:\n${unexpected.joinToString("\n")}"
        }
    }

    private fun jsonFiles(directory: Path): List<Path> {
        if (!Files.isDirectory(directory)) return emptyList()
        return Files.walk(directory).use { paths ->
            paths
                .filter(Files::isRegularFile)
                .filter { path -> path.fileName.toString().endsWith(JSON_SUFFIX) }
                .sorted()
                .toList()
        }
    }

    private fun readJson(path: Path): JsonValue = Files.newBufferedReader(path, UTF_8).use(JsonReader()::parse)

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private data class GoldenFixture(
        val golden: Path,
        val scenario: BehavioralScenario,
    )

    private data class GeneratedGolden(
        val fixture: GoldenFixture,
        val content: String,
    )

    private companion object {
        const val JSON_SUFFIX = ".json"
        const val SCENARIOS_FIELD = "scenarios"
        const val INPUT_SCRIPT_FIELD = "inputScript"
    }
}
