package com.example.toyracers.compat

import org.junit.Assert.assertThrows
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption.REPLACE_EXISTING

class BehaviorTraceComparisonCliTest {
    @Test
    fun `accepts a complete trace that satisfies the shared contract`() {
        val expected = golden("car/straight_acceleration.json")
        val actual = Files.createTempFile("dart-compatible-trace", ".json")
        try {
            Files.copy(expected, actual, REPLACE_EXISTING)

            BehaviorTraceComparisonCli.execute(
                arrayOf("--expected", expected.toString(), "--actual", actual.toString()),
            )
        } finally {
            Files.deleteIfExists(actual)
        }
    }

    @Test
    fun `reports a comparison failure for a changed trace`() {
        val expected = golden("car/straight_acceleration.json")
        val actual = Files.createTempFile("invalid-compatible-trace", ".json")
        try {
            Files.writeString(
                actual,
                Files.readString(expected).replaceFirst("\"scenarioId\":\"", "\"scenarioId\":\"other-"),
            )

            assertThrows(IllegalArgumentException::class.java) {
                BehaviorTraceComparisonCli.execute(
                    arrayOf("--expected", expected.toString(), "--actual", actual.toString()),
                )
            }
        } finally {
            Files.deleteIfExists(actual)
        }
    }

    private fun golden(relativePath: String): Path =
        requireNotNull(System.getProperty("compatibilityDirectory"))
            .let { compatibilityDirectory ->
                Path.of(compatibilityDirectory, "golden", relativePath)
            }
}
