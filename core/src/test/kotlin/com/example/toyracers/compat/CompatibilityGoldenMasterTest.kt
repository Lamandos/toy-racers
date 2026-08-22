package com.example.toyracers.compat

import org.junit.Assert.assertEquals
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

    private companion object {
        const val COMPATIBILITY_DIRECTORY_PROPERTY = "compatibilityDirectory"
    }
}
