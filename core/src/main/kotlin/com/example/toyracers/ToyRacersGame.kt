package com.example.toyracers

import com.badlogic.gdx.Game
import com.badlogic.gdx.Screen
import com.example.toyracers.assets.GameAssets
import com.example.toyracers.screen.LoadingScreen
import com.example.toyracers.screen.MainMenuScreen
import com.example.toyracers.screen.RaceScreen
import com.example.toyracers.screen.ResultsScreen

/** Owns screen navigation for every platform launcher. */
class ToyRacersGame : Game() {
    lateinit var assets: GameAssets
        private set

    override fun create() {
        assets = GameAssets()
        assets.queueLoading()
        showLoadingScreen()
    }

    fun showMainMenu() {
        changeScreen(MainMenuScreen(this))
    }

    fun startRace() {
        changeScreen(RaceScreen(this))
    }

    fun showResults() {
        changeScreen(ResultsScreen(this))
    }

    private fun showLoadingScreen() {
        changeScreen(LoadingScreen(this))
    }

    private fun changeScreen(nextScreen: Screen) {
        val previousScreen = screen
        setScreen(nextScreen)
        previousScreen?.dispose()
    }

    override fun dispose() {
        screen?.dispose()
        assets.dispose()
    }

    companion object {
        const val VIRTUAL_WIDTH = 1280f
        const val VIRTUAL_HEIGHT = 720f
    }
}
