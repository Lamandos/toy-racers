package com.example.toyracers.ui

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.audio.AudioSettings

class AudioSettingsStage(
    initialSettings: AudioSettings,
    private val onSettingsChanged: (AudioSettings) -> Unit,
    onBack: () -> Unit,
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    private val skin = createGameUiSkin()
    private val stage = Stage(
        ExtendViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
    )
    private var settings = initialSettings
    private val masterLabel = Label("", skin)
    private val musicLabel = Label("", skin)
    private val sfxLabel = Label("", skin)
    private val vibrationLabel = Label("", skin)

    val inputProcessor: InputProcessor get() = stage

    init {
        val table = Table().apply {
            setFillParent(true)
            background = this@AudioSettingsStage.skin.panelDrawable()
            pad(36f)
            add(Label("AUDIO SETTINGS", this@AudioSettingsStage.skin).apply {
                setFontScale(2.2f)
            }).colspan(3).height(90f)
            row()
            addVolumeRow(masterLabel, { settings.masterVolume }) {
                settings.copy(masterVolume = it)
            }
            addVolumeRow(musicLabel, { settings.musicVolume }) {
                settings.copy(musicVolume = it)
            }
            addVolumeRow(sfxLabel, { settings.sfxVolume }) {
                settings.copy(sfxVolume = it)
            }
            vibrationLabel.setFontScale(1.45f)
            add(vibrationLabel).width(390f).height(68f)
            add(button("TOGGLE") {
                update(settings.copy(vibrationEnabled = !settings.vibrationEnabled))
            }).colspan(2).width(260f).height(64f)
            row()
            add(button("BACK", SECONDARY_BUTTON_STYLE, onBack))
                .colspan(3).width(360f).height(72f).padTop(24f)
        }
        stage.addActor(table)
        refreshLabels()
    }

    private fun Table.addVolumeRow(
        label: Label,
        value: () -> Float,
        change: (Float) -> AudioSettings,
    ) {
        label.setFontScale(1.45f)
        add(label).width(390f).height(68f)
        add(button("-") { update(change((value() - STEP).coerceAtLeast(0f))) })
            .width(110f).height(60f)
        add(button("+") { update(change((value() + STEP).coerceAtMost(1f))) })
            .width(110f).height(60f)
        row()
    }

    private fun update(value: AudioSettings) {
        settings = value
        onSettingsChanged(value)
        refreshLabels()
    }

    private fun refreshLabels() {
        masterLabel.setText("MASTER ${(settings.masterVolume * 100).toInt()}%")
        musicLabel.setText("MUSIC ${(settings.musicVolume * 100).toInt()}%")
        sfxLabel.setText("SFX ${(settings.sfxVolume * 100).toInt()}%")
        vibrationLabel.setText(
            "VIBRATION ${if (settings.vibrationEnabled) "ON" else "OFF"}",
        )
    }

    private fun button(
        text: String,
        style: String = "default",
        action: () -> Unit,
    ): TextButton =
        TextButton(text, skin, style).apply {
            addListener(object : ClickListener() {
                override fun clicked(event: InputEvent, x: Float, y: Float) {
                    onButtonClick()
                    action()
                }
            })
        }

    fun resize(width: Int, height: Int) = stage.viewport.update(width, height, true)

    fun render(delta: Float) {
        stage.act(delta.coerceAtMost(MAX_UI_DELTA))
        stage.draw()
    }

    override fun dispose() {
        stage.dispose()
        skin.dispose()
    }

    private companion object {
        const val STEP = 0.1f
        const val MAX_UI_DELTA = 0.1f
    }
}
