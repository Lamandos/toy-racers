package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame

/** First race view: a resolution-independent test track without gameplay physics. */
class RaceScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var manuallyPaused = false

    override fun render(delta: Float) {
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            manuallyPaused = !manuallyPaused
        }

        ScreenUtils.clear(GRASS)
        beginShapes(ShapeRenderer.ShapeType.Filled)

        // A simple rectangular circuit: asphalt outside, grass in the infield.
        shapes.color = ASPHALT
        shapes.rect(120f, 90f, 1040f, 540f)
        shapes.color = GRASS
        shapes.rect(330f, 260f, 620f, 200f)

        // Start/finish stripe and a placeholder player car.
        shapes.color = Color.WHITE
        shapes.rect(610f, 90f, 16f, 170f)
        shapes.color = Color(0.94f, 0.25f, 0.18f, 1f)
        shapes.rect(570f, 135f, 70f, 110f)

        if (manuallyPaused || lifecyclePaused) {
            shapes.color = Color(0f, 0f, 0f, 0.55f)
            shapes.rect(0f, 0f, ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT)
            shapes.color = Color(0.98f, 0.76f, 0.22f, 1f)
            shapes.rect(465f, 300f, 350f, 120f)
        }
        shapes.end()

        if (!lifecyclePaused && !manuallyPaused && finishRequested()) {
            game.showResults()
        }
    }

    private fun finishRequested(): Boolean =
        Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    private companion object {
        val GRASS = Color(0.18f, 0.48f, 0.24f, 1f)
        val ASPHALT = Color(0.20f, 0.22f, 0.25f, 1f)
    }
}
