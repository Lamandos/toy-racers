package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.ScreenAdapter
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame

/** Shared camera, viewport, drawing resource, and lifecycle behavior for game screens. */
abstract class ToyRacersScreen(
    protected val game: ToyRacersGame,
) : ScreenAdapter() {
    protected val camera = OrthographicCamera()
    protected val viewport = ExtendViewport(
        ToyRacersGame.VIRTUAL_WIDTH,
        ToyRacersGame.VIRTUAL_HEIGHT,
        camera,
    )
    protected val shapes = ShapeRenderer()
    protected var lifecyclePaused = false
        private set

    override fun show() {
        resize(Gdx.graphics.width, Gdx.graphics.height)
    }

    override fun resize(width: Int, height: Int) {
        viewport.update(width, height, true)
    }

    override fun pause() {
        lifecyclePaused = true
    }

    override fun resume() {
        lifecyclePaused = false
    }

    protected fun beginShapes(type: ShapeRenderer.ShapeType) {
        viewport.apply()
        camera.update()
        shapes.projectionMatrix = camera.combined
        shapes.begin(type)
    }

    override fun dispose() {
        shapes.dispose()
    }
}
