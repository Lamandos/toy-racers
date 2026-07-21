package com.example.toyracers.screen

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import kotlin.math.min

/** Brief startup screen that will later coordinate asynchronous asset loading. */
class LoadingScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var elapsedSeconds = 0f

    override fun render(delta: Float) {
        if (!lifecyclePaused) {
            elapsedSeconds += min(delta, MAX_FRAME_DELTA)
        }

        val assetsReady = game.assets.update()

        ScreenUtils.clear(BACKGROUND)
        beginShapes(ShapeRenderer.ShapeType.Filled)
        shapes.color = Color(0.18f, 0.72f, 0.82f, 1f)
        shapes.rect(390f, 330f, 500f, 60f)
        shapes.color = Color(0.92f, 0.82f, 0.28f, 1f)
        val displayProgress = (elapsedSeconds / DISPLAY_SECONDS).coerceAtMost(1f)
        shapes.rect(390f, 330f, 500f * min(displayProgress, game.assets.progress), 60f)
        shapes.end()

        if (!lifecyclePaused && elapsedSeconds >= DISPLAY_SECONDS && assetsReady) {
            game.showMainMenu()
        }
    }

    private companion object {
        val BACKGROUND = Color(0.06f, 0.08f, 0.12f, 1f)
        const val DISPLAY_SECONDS = 0.35f
        const val MAX_FRAME_DELTA = 0.1f
    }
}
