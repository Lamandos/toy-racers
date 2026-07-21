package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame

/** Shape-based results placeholder with retry and return-to-menu transitions. */
class ResultsScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        beginShapes(ShapeRenderer.ShapeType.Filled)

        shapes.color = Color(0.95f, 0.76f, 0.20f, 1f)
        shapes.rect(515f, 220f, 250f, 310f)
        shapes.color = Color(0.78f, 0.80f, 0.84f, 1f)
        shapes.rect(260f, 220f, 250f, 220f)
        shapes.color = Color(0.72f, 0.42f, 0.20f, 1f)
        shapes.rect(770f, 220f, 250f, 160f)
        shapes.end()

        if (lifecyclePaused) return

        when {
            Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) -> game.showMainMenu()
            retryRequested() -> game.startRace()
        }
    }

    private fun retryRequested(): Boolean =
        Gdx.input.justTouched() ||
            Gdx.input.isKeyJustPressed(Input.Keys.R) ||
            Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    private companion object {
        val BACKGROUND = Color(0.08f, 0.10f, 0.16f, 1f)
    }
}
