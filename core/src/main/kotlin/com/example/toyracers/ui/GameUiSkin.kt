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

    val font =
        BitmapFont().apply {
            region.texture.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        }
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
    skin.add(
        SECONDARY_BUTTON_STYLE,
        TextButton.TextButtonStyle(
            skin.newDrawable(WHITE_TEXTURE, SECONDARY_IDLE),
            skin.newDrawable(WHITE_TEXTURE, BUTTON_PRESSED),
            skin.newDrawable(WHITE_TEXTURE, SECONDARY_OVER),
            font,
        ),
    )
    return skin
}

internal fun Skin.panelDrawable() = newDrawable(WHITE_TEXTURE, PANEL_COLOR)

internal const val SECONDARY_BUTTON_STYLE = "secondary"

internal const val WHITE_TEXTURE = "white"
private const val DEFAULT_FONT = "default-font"
private const val DEFAULT_LABEL_STYLE = "default"
private const val DEFAULT_BUTTON_STYLE = "default"
private val BUTTON_IDLE = Color(0.78f, 0.16f, 0.08f, 0.96f)
private val BUTTON_PRESSED = Color(1f, 0.64f, 0.12f, 1f)
private val BUTTON_OVER = Color(0.94f, 0.31f, 0.08f, 1f)
private val SECONDARY_IDLE = Color(0.08f, 0.12f, 0.15f, 0.96f)
private val SECONDARY_OVER = Color(0.16f, 0.22f, 0.25f, 1f)
private val PANEL_COLOR = Color(0.025f, 0.035f, 0.04f, 0.88f)
