package com.example.toyracers.ui

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.BitmapFont
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Skin
import com.badlogic.gdx.scenes.scene2d.ui.TextButton

/** Creates the small programmatic prototype skin shared by the current UI stages. */
internal fun createGameUiSkin(): Skin {
    val skin = Skin()
    val pixmap = Pixmap(1, 1, Pixmap.Format.RGBA8888)
    pixmap.setColor(Color.WHITE)
    pixmap.fill()
    skin.add(WHITE_TEXTURE, Texture(pixmap))
    pixmap.dispose()

    val font = BitmapFont()
    skin.add(DEFAULT_FONT, font)
    skin.add(DEFAULT_LABEL_STYLE, Label.LabelStyle(font, Color.WHITE))
    skin.add(
        DEFAULT_BUTTON_STYLE,
        TextButton.TextButtonStyle(
            skin.newDrawable(WHITE_TEXTURE, BUTTON_IDLE),
            skin.newDrawable(WHITE_TEXTURE, BUTTON_PRESSED),
            skin.newDrawable(WHITE_TEXTURE, BUTTON_OVER),
            font,
        ),
    )
    return skin
}

private const val WHITE_TEXTURE = "white"
private const val DEFAULT_FONT = "default-font"
private const val DEFAULT_LABEL_STYLE = "default"
private const val DEFAULT_BUTTON_STYLE = "default"
private val BUTTON_IDLE = Color(0.12f, 0.45f, 0.72f, 0.94f)
private val BUTTON_PRESSED = Color(0.96f, 0.68f, 0.18f, 1f)
private val BUTTON_OVER = Color(0.18f, 0.58f, 0.82f, 1f)
