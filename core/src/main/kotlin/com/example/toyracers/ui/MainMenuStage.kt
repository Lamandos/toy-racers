package com.example.toyracers.ui

import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.utils.Scaling

class MainMenuStage(
    background: Texture,
    onPlay: () -> Unit,
    onSettings: () -> Unit = {},
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {

    init {
        stage.addActor(Image(background).apply {
            setFillParent(true)
            setScaling(Scaling.fill)
        })
        val menu = Table().apply {
            setFillParent(true)
            left().padLeft(92f)
            val panel = Table().apply {
                this.background = this@MainMenuStage.skin.panelDrawable()
                pad(34f)
            }
            val title = Label("TOY RACERS", this@MainMenuStage.skin).apply {
                setFontScale(3f)
            }
            panel.add(title).width(430f).height(110f)
            panel.row()
            panel.add(button("PLAY", action = onPlay)).width(360f).height(80f).pad(10f)
            panel.row()
            panel.add(button("SETTINGS", SECONDARY_BUTTON_STYLE, onSettings))
                .width(360f).height(72f).pad(8f)
            add(panel).width(500f)
        }
        stage.addActor(menu)
    }

}
