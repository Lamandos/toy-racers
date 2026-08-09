package com.example.toyracers.debug

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.BitmapFont
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.viewport.Viewport
import java.util.Locale

/** Screen-space presentation for [FrameTelemetrySnapshot], shown only through the F5 debug toggle. */
class FrameTelemetryRenderer : Disposable {
    private val batch = SpriteBatch()
    private val font = BitmapFont().apply {
        data.setScale(TEXT_SCALE)
        color = OVERLAY_COLOR
    }

    fun render(
        viewport: Viewport,
        camera: Camera,
        snapshot: FrameTelemetrySnapshot,
    ) {
        viewport.apply()
        camera.update()
        batch.projectionMatrix = camera.combined
        batch.begin()
        font.draw(batch, overlayText(snapshot), TEXT_X, TEXT_Y)
        batch.end()
    }

    override fun dispose() {
        batch.dispose()
        font.dispose()
    }

    private fun overlayText(snapshot: FrameTelemetrySnapshot): String = buildString {
        append("PERF [F5]  ")
        append(snapshot.framesPerSecond)
        append(" FPS")
        snapshot.refreshRateHz?.let { append(" / ${it} Hz") }
        appendLine()
        append("frame ${snapshot.frameTimeMs.format()} ms  p50 ${snapshot.p50FrameTimeMs.format()}  ")
        append("p95 ${snapshot.p95FrameTimeMs.format()}  p99 ${snapshot.p99FrameTimeMs.format()}")
        appendLine()
        append("simulation ${snapshot.simulationTimeMs.format()} ms  ")
        append("collisions ${snapshot.collisionTimeMs.format()} ms  ")
        append("steps ${snapshot.physicalSteps}")
        appendLine()
        append("world ${snapshot.worldRenderTimeMs.format()} ms  UI ${snapshot.interfaceTimeMs.format()} ms  ")
        append("audio ${snapshot.audioTimeMs.format()} ms")
        appendLine()
        append("world draw calls ${snapshot.worldDrawCalls}  car flushes ${snapshot.carFlushes}")
    }

    private fun Float.format(): String = String.format(Locale.ROOT, "%.2f", this)

    private companion object {
        const val TEXT_X = 24f
        const val TEXT_Y = 690f
        const val TEXT_SCALE = 0.9f
        val OVERLAY_COLOR = Color(0.8f, 1f, 0.45f, 1f)
    }
}
