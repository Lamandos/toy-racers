package com.example.toyracers.ui

import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table

data class RaceHudSnapshot(
    val speed: Float,
    val position: Int,
    val competitorCount: Int,
    val completedLaps: Int,
    val requiredLaps: Int,
    val totalRaceTime: Float,
    val bestLapTime: Float?,
)

class RaceHudStage(
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRestart: () -> Unit,
    onQuitToMenu: () -> Unit,
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {
    private val positionLabel = Label("", skin)
    private val speedLabel = Label("", skin)
    private val lapLabel = Label("", skin)
    private val timeLabel = Label("", skin)
    private val bestLapLabel = Label("", skin)
    private val pauseButton = button("PAUSE", onPause)
    private val pauseMenu = createPauseMenu(onResume, onRestart, onQuitToMenu)

    init {
        val hud = Table()
        hud.setFillParent(true)
        hud.top().pad(18f)
        listOf(positionLabel, speedLabel, lapLabel, timeLabel, bestLapLabel).forEach {
            it.setFontScale(1.45f)
        }
        hud.add(instrument(positionLabel)).width(175f).height(72f).padRight(8f)
        hud.add(instrument(speedLabel)).width(175f).height(72f).padRight(8f)
        hud.add(instrument(lapLabel)).width(160f).height(72f).padRight(8f)
        hud.add(instrument(timeLabel)).width(225f).height(72f).padRight(8f)
        hud.add(instrument(bestLapLabel)).width(275f).height(72f).padRight(12f)
        hud.add(pauseButton).width(115f).height(64f)
        stage.addActor(hud)
        stage.addActor(pauseMenu)
        showPause(false)
    }

    fun update(snapshot: RaceHudSnapshot) {
        positionLabel.setText("POS ${snapshot.position}/${snapshot.competitorCount}")
        speedLabel.setText("${(snapshot.speed.coerceAtLeast(0f) * SPEED_DISPLAY_SCALE).toInt()} KM/H")
        val displayedLap = (snapshot.completedLaps + 1).coerceAtMost(snapshot.requiredLaps)
        lapLabel.setText("LAP $displayedLap/${snapshot.requiredLaps}")
        timeLabel.setText("TIME ${formatRaceTime(snapshot.totalRaceTime)}")
        bestLapLabel.setText(
            "BEST ${snapshot.bestLapTime?.let(::formatRaceTime) ?: "--:--.---"}",
        )
    }

    private fun instrument(label: Label): Table = Table().apply {
        background = this@RaceHudStage.skin.panelDrawable()
        add(label).expand().center()
    }

    fun showPause(show: Boolean) {
        pauseMenu.isVisible = show
        pauseMenu.touchable = if (show) {
            com.badlogic.gdx.scenes.scene2d.Touchable.enabled
        } else {
            com.badlogic.gdx.scenes.scene2d.Touchable.disabled
        }
        pauseButton.isVisible = !show
    }

    private fun createPauseMenu(
        onResume: () -> Unit,
        onRestart: () -> Unit,
        onQuitToMenu: () -> Unit,
    ): Table = Table().apply {
        setFillParent(true)
        background = this@RaceHudStage.skin.panelDrawable()
        val title = Label("PAUSED", this@RaceHudStage.skin).apply { setFontScale(2.2f) }
        add(title).width(360f).height(80f)
        row()
        add(button("RESUME", onResume)).width(360f).height(72f).pad(8f)
        row()
        add(button("RESTART", onRestart)).width(360f).height(72f).pad(8f)
        row()
        add(button("QUIT TO MENU", onQuitToMenu)).width(360f).height(72f).pad(8f)
    }

    private companion object {
        const val SPEED_DISPLAY_SCALE = 18f
    }
}

fun formatRaceTime(seconds: Float): String {
    val safeMilliseconds = (seconds.coerceAtLeast(0f) * 1000f).toInt()
    val minutes = safeMilliseconds / 60_000
    val secondsPart = safeMilliseconds / 1000 % 60
    val milliseconds = safeMilliseconds % 1000
    return "%02d:%02d.%03d".format(minutes, secondsPart, milliseconds)
}
