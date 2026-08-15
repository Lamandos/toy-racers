package com.example.toyracers.ui

import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.example.toyracers.audio.AudioSettings

class AudioSettingsStage(
    initialSettings: AudioSettings,
    private val onSettingsChanged: (AudioSettings) -> Unit,
    onBack: () -> Unit,
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {
    private var settings = initialSettings
    private val masterLabel = Label("", skin)
    private val musicLabel = Label("", skin)
    private val sfxLabel = Label("", skin)
    private val vibrationLabel = Label("", skin)

    init {
        val table =
            Table().apply {
                setFillParent(true)
                background = this@AudioSettingsStage.skin.panelDrawable()
                pad(36f)
                add(
                    Label("AUDIO SETTINGS", this@AudioSettingsStage.skin).apply {
                        setFontScale(2.2f)
                    },
                ).colspan(3).height(90f)
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
                add(
                    button("TOGGLE") {
                        update(settings.copy(vibrationEnabled = !settings.vibrationEnabled))
                    },
                ).colspan(2).width(260f).height(64f)
                row()
                add(button("BACK", SECONDARY_BUTTON_STYLE, onBack))
                    .colspan(3)
                    .width(360f)
                    .height(72f)
                    .padTop(24f)
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
            .width(110f)
            .height(60f)
        add(button("+") { update(change((value() + STEP).coerceAtMost(1f))) })
            .width(110f)
            .height(60f)
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

    private companion object {
        const val STEP = 0.1f
    }
}
