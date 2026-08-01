package com.example.toyracers

import com.badlogic.gdx.Game
import com.badlogic.gdx.Screen
import com.example.toyracers.assets.GameAssets
import com.example.toyracers.audio.GameAudio
import com.example.toyracers.car.CarModel
import com.example.toyracers.race.RaceResult
import com.example.toyracers.screen.CarSelectionScreen
import com.example.toyracers.screen.LoadingScreen
import com.example.toyracers.screen.MainMenuScreen
import com.example.toyracers.screen.RaceScreen
import com.example.toyracers.screen.ResultsScreen
import com.example.toyracers.screen.SettingsScreen
import com.example.toyracers.screen.TrackSelectionScreen
import com.example.toyracers.track.TrackId

/** Owns screen navigation for every platform launcher. */
class ToyRacersGame : Game() {
    lateinit var assets: GameAssets
        private set
    lateinit var audio: GameAudio
        private set
    var selectedCar: CarModel = CarModel.RED_STRIPE
        private set

    override fun create() {
        assets = GameAssets()
        assets.queueLoading()
        showLoadingScreen()
    }

    fun showMainMenu() {
        ensureAudio().startMusic()
        changeScreen(MainMenuScreen(this))
    }

    fun showTrackSelection() {
        changeScreen(TrackSelectionScreen(this))
    }

    fun showCarSelection(trackId: TrackId) {
        changeScreen(CarSelectionScreen(this, trackId))
    }

    fun selectCar(model: CarModel) {
        selectedCar = model
    }

    fun startRace(trackId: TrackId = TrackId.LIVING_ROOM) {
        changeScreen(RaceScreen(this, trackId))
    }

    fun showSettings() {
        changeScreen(SettingsScreen(this))
    }

    fun showResults(result: RaceResult) {
        changeScreen(ResultsScreen(this, result))
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
        if (::audio.isInitialized) audio.dispose()
        assets.dispose()
    }

    private fun ensureAudio(): GameAudio {
        if (!::audio.isInitialized) audio = GameAudio(assets)
        return audio
    }

    companion object {
        const val VIRTUAL_WIDTH = 1280f
        const val VIRTUAL_HEIGHT = 720f
    }
}
