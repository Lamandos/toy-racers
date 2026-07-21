package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame

/** Minimal shape-based menu used until the Scene2D UI stage is implemented. */
class MainMenuScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        beginShapes(ShapeRenderer.ShapeType.Filled)

        // Abstract toy car title mark.
        shapes.color = Color(0.94f, 0.32f, 0.22f, 1f)
        shapes.rect(440f, 430f, 400f, 110f)
        shapes.color = Color(0.98f, 0.76f, 0.22f, 1f)
        shapes.rect(520f, 520f, 240f, 55f)
        shapes.color = Color.DARK_GRAY
        shapes.circle(520f, 425f, 42f)
        shapes.circle(760f, 425f, 42f)

        // Start button placeholder.
        shapes.color = Color(0.18f, 0.72f, 0.42f, 1f)
        shapes.rect(490f, 190f, 300f, 105f)
        shapes.end()

        if (!lifecyclePaused && startRequested()) {
            game.startRace()
        }
    }

    private fun startRequested(): Boolean =
        Gdx.input.justTouched() ||
            Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    private companion object {
        val BACKGROUND = Color(0.07f, 0.12f, 0.18f, 1f)
    }
}
