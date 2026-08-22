package com.example.toyracers.compat

import java.io.IOException
import java.nio.file.Path
import kotlin.system.exitProcess

/** Explicit command-line entry point for regenerating checked-in compatibility goldens. */
internal object CompatibilityGoldenCli {
    fun execute(args: Array<String>) {
        val options = parseOptions(args)
        require(options.regenerate) { "Compatibility golden regeneration requires --regenerate" }
        val changed = CompatibilityGoldenMaster(options.scenarios, options.goldens).regenerate()
        if (changed.isEmpty()) {
            println("No compatibility golden files changed.")
        } else {
            println("Changed compatibility golden files:")
            changed.forEach { println(displayPath(it)) }
        }
    }

    private fun parseOptions(args: Array<String>): CompatibilityGoldenOptions {
        val values = mutableMapOf<String, String>()
        var regenerate = false
        var index = 0
        while (index < args.size) {
            when (val option = args[index]) {
                REGENERATE_OPTION -> {
                    require(!regenerate) { "Option may only be supplied once: $option" }
                    regenerate = true
                    index++
                }

                SCENARIOS_OPTION, GOLDENS_OPTION -> {
                    val value = args.getOrNull(index + 1)
                    require(value != null && !value.startsWith("--")) { "Missing value for $option" }
                    require(values.put(option, value) == null) { "Option may only be supplied once: $option" }
                    index += 2
                }

                else -> {
                    error("Unknown option: $option")
                }
            }
        }
        return CompatibilityGoldenOptions(
            scenarios = Path.of(requireNotNull(values[SCENARIOS_OPTION]) { "Missing $SCENARIOS_OPTION" }),
            goldens = Path.of(requireNotNull(values[GOLDENS_OPTION]) { "Missing $GOLDENS_OPTION" }),
            regenerate = regenerate,
        )
    }

    private fun displayPath(path: Path): Path {
        val currentDirectory = Path.of("").toAbsolutePath().normalize()
        return path
            .takeIf { it.startsWith(currentDirectory) }
            ?.let(currentDirectory::relativize)
            ?: path
    }

    private data class CompatibilityGoldenOptions(
        val scenarios: Path,
        val goldens: Path,
        val regenerate: Boolean,
    )

    private const val SCENARIOS_OPTION = "--scenarios"
    private const val GOLDENS_OPTION = "--goldens"
    private const val REGENERATE_OPTION = "--regenerate"
}

fun main(args: Array<String>) {
    try {
        CompatibilityGoldenCli.execute(args)
    } catch (exception: IllegalArgumentException) {
        reportFailure(exception)
    } catch (exception: IllegalStateException) {
        reportFailure(exception)
    } catch (exception: IOException) {
        reportFailure(exception)
    }
}

private fun reportFailure(exception: Exception): Nothing {
    System.err.println("Compatibility golden regeneration failed: ${exception.message}")
    exitProcess(1)
}
