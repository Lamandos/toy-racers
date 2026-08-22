package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

class CompatibilityGoldenMasterTest {
    @Test
    fun `checked in compatibility goldens match their scenarios without mutation`() {
        val compatibility = compatibilityDirectory()
        val golden = compatibility.resolve("golden/car/straight_acceleration.json")
        val before = Files.readString(golden)

        CompatibilityGoldenMaster(
            scenarioDirectory = compatibility.resolve("scenarios"),
            goldenDirectory = compatibility.resolve("golden"),
        ).verify()

        assertEquals(before, Files.readString(golden))
    }

    @Test
    fun `explicit regeneration reports only generated golden files`() {
        val temporaryDirectory = Files.createTempDirectory("compatibility-golden-")
        try {
            val scenarios = temporaryDirectory.resolve("scenarios/car")
            val goldens = temporaryDirectory.resolve("golden")
            Files.createDirectories(scenarios)
            Files.writeString(scenarios.resolve("test.json"), scenarioDocument())
            val master = CompatibilityGoldenMaster(scenarios.parent, goldens)

            val changed = master.regenerate()

            assertEquals(listOf(goldens.resolve("car/test.json")), changed)
            assertEquals(emptyList<Path>(), master.regenerate())
        } finally {
            Files.walk(temporaryDirectory).use { paths ->
                paths.sorted(java.util.Comparator.reverseOrder()).forEach(Files::deleteIfExists)
            }
        }
    }

    @Test
    fun `referenced input scripts are not treated as scenarios by their file name`() {
        val temporaryDirectory = Files.createTempDirectory("compatibility-script-")
        try {
            val scenarios = temporaryDirectory.resolve("scenarios/car")
            val goldens = temporaryDirectory.resolve("golden")
            Files.createDirectories(scenarios)
            Files.writeString(scenarios.resolve("test.json"), scriptedScenarioDocument())
            Files.writeString(scenarios.resolve("full-race-input.json"), inputScriptDocument())
            val master = CompatibilityGoldenMaster(scenarios.parent, goldens)

            val changed = master.regenerate()

            assertEquals(listOf(goldens.resolve("car/test.json")), changed)
            assertTrue(Files.isRegularFile(goldens.resolve("car/test.json")))
        } finally {
            Files.walk(temporaryDirectory).use { paths ->
                paths.sorted(java.util.Comparator.reverseOrder()).forEach(Files::deleteIfExists)
            }
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `malformed self-referencing scenario is not hidden as input script`() {
        val temporaryDirectory = Files.createTempDirectory("compatibility-self-reference-")
        try {
            val scenarios = temporaryDirectory.resolve("scenarios/car")
            val goldens = temporaryDirectory.resolve("golden")
            Files.createDirectories(scenarios)
            Files.writeString(scenarios.resolve("valid.json"), scenarioDocument())
            Files.writeString(scenarios.resolve("malformed.json"), selfReferencingScenarioDocument())

            CompatibilityGoldenMaster(scenarios.parent, goldens).regenerate()
        } finally {
            Files.walk(temporaryDirectory).use { paths ->
                paths.sorted(java.util.Comparator.reverseOrder()).forEach(Files::deleteIfExists)
            }
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario reference cycle is not hidden as input scripts`() {
        val temporaryDirectory = Files.createTempDirectory("compatibility-reference-cycle-")
        try {
            val scenarios = temporaryDirectory.resolve("scenarios/car")
            val goldens = temporaryDirectory.resolve("golden")
            Files.createDirectories(scenarios)
            Files.writeString(scenarios.resolve("valid.json"), scenarioDocument())
            Files.writeString(
                scenarios.resolve("first.json"),
                scriptedScenarioDocument("cycle-first", "second.json"),
            )
            Files.writeString(
                scenarios.resolve("second.json"),
                scriptedScenarioDocument("cycle-second", "first.json"),
            )

            CompatibilityGoldenMaster(scenarios.parent, goldens).regenerate()
        } finally {
            Files.walk(temporaryDirectory).use { paths ->
                paths.sorted(java.util.Comparator.reverseOrder()).forEach(Files::deleteIfExists)
            }
        }
    }

    private fun compatibilityDirectory(): Path =
        Path.of(requireNotNull(System.getProperty(COMPATIBILITY_DIRECTORY_PROPERTY))).toAbsolutePath()

    private fun scenarioDocument(): String =
        """
        {
          "schemaVersion": 1,
          "scenarios": [{
            "id": "test-golden", "seed": 1, "trackId": "track-01",
            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
            "ticks": 1, "snapshotIntervalTicks": 1,
            "inputSegments": [{"fromTick": 1, "toTick": 1}]
          }]
        }
        """.trimIndent()

    private fun scriptedScenarioDocument(): String =
        """
        {
          "schemaVersion": 1,
          "scenarios": [{
            "id": "test-scripted-golden", "seed": 1, "trackId": "track-01",
            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
            "ticks": 1, "snapshotIntervalTicks": 1,
            "inputScript": "full-race-input.json"
          }]
        }
        """.trimIndent()

    private fun scriptedScenarioDocument(
        id: String,
        script: String,
    ): String =
        """
        {
          "schemaVersion": 1,
          "scenarios": [{
            "id": "$id", "seed": 1, "trackId": "track-01",
            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
            "ticks": 1, "snapshotIntervalTicks": 1,
            "inputScript": "$script"
          }]
        }
        """.trimIndent()

    private fun selfReferencingScenarioDocument(): String =
        """
        {
          "schemaVersion": 1,
          "scenarios": [{
            "id": "malformed-self-reference", "seed": 1, "trackId": "track-01",
            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
            "ticks": 1, "snapshotIntervalTicks": 1,
            "inputSegments": [{"fromTick": 1, "toTick": 1}],
            "inputScript": "malformed.json"
          }]
        }
        """.trimIndent()

    private fun inputScriptDocument(): String =
        """
        {
          "schemaVersion": 1,
          "segments": [{"fromTick": 1, "toTick": 1}]
        }
        """.trimIndent()

    private companion object {
        const val COMPATIBILITY_DIRECTORY_PROPERTY = "compatibilityDirectory"
    }
}
