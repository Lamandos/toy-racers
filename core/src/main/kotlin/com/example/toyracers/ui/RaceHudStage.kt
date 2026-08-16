package com.example.toyracers.ui

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.scenes.scene2d.Touchable
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Stack
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.utils.Drawable
import com.badlogic.gdx.utils.Align
import com.example.toyracers.track.Track

data class RaceHudSnapshot(
    val position: Int,
    val competitorCount: Int,
    val completedLaps: Int,
    val requiredLaps: Int,
    val totalRaceTime: Float,
    val bestLapTime: Float?,
)

/** Screen-space race instruments styled after the supplied neon motorsport HUD reference. */
class RaceHudStage(
    track: Track,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRestart: () -> Unit,
    onQuitToMenu: () -> Unit,
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {
    private val minimap = MinimapActor(track)
    private val hudSkin = skin
    private val positionValue = hudLabel("", 3.35f, HUD_CYAN)
    private val lapValue = hudLabel("", 2.15f, HUD_CYAN)
    private val timeValue = hudLabel("", 1.65f)
    private val bestLapValue = hudLabel("", 1.05f, MUTED_TEXT)
    private val lapSegments = List(LAP_SEGMENT_COUNT) { Table() }
    private val cyanDrawable = hudSkin.newDrawable(WHITE_TEXTURE, HUD_CYAN)
    private val inactiveDrawable = hudSkin.newDrawable(WHITE_TEXTURE, SEGMENT_OFF)
    private val playerRowDrawable = hudSkin.newDrawable(WHITE_TEXTURE, PLAYER_ROW)
    private val standingRowDrawable = hudSkin.newDrawable(WHITE_TEXTURE, STANDING_ROW)
    private val standingRows =
        List(MAX_VISIBLE_COMPETITORS) { index ->
            StandingRow(
                position = hudLabel("${index + 1}", 1.2f),
                name = hudLabel("RACER ${index + 1}", 1.05f, MUTED_TEXT),
            )
        }
    private val pauseButton =
        button("", SECONDARY_BUTTON_STYLE, onPause).apply {
            clearChildren()
            add(Image(cyanDrawable)).width(13f).height(39f).padRight(10f)
            add(Image(cyanDrawable)).width(13f).height(39f)
        }
    private val pauseMenu = createPauseMenu(onResume, onRestart, onQuitToMenu)

    init {
        stage.addActor(createHudLayout())
        stage.addActor(pauseMenu)
        showPause(false)
    }

    fun update(snapshot: RaceHudSnapshot) {
        positionValue.setText("${snapshot.position}/${snapshot.competitorCount}")
        val displayedLap = (snapshot.completedLaps + 1).coerceAtMost(snapshot.requiredLaps)
        lapValue.setText("LAP $displayedLap/${snapshot.requiredLaps}")
        val completedLapSegments =
            (
                displayedLap.toFloat() / snapshot.requiredLaps.coerceAtLeast(1) * LAP_SEGMENT_COUNT
            ).toInt().coerceIn(1, LAP_SEGMENT_COUNT)
        lapSegments.forEachIndexed { index, segment ->
            segment.background = if (index < completedLapSegments) cyanDrawable else inactiveDrawable
        }
        timeValue.setText(formatRaceTime(snapshot.totalRaceTime))
        bestLapValue.setText(
            "BEST  ${snapshot.bestLapTime?.let(::formatRaceTime) ?: "--:--.---"}",
        )

        standingRows.forEachIndexed { index, row ->
            val place = index + 1
            val isVisible = place <= snapshot.competitorCount
            row.root.isVisible = isVisible
            if (isVisible) {
                val isPlayer = place == snapshot.position
                row.name.setText(if (isPlayer) "YOU" else "RACER $place")
                row.name.color = if (isPlayer) Color.WHITE else MUTED_TEXT
                row.root.background = if (isPlayer) playerRowDrawable else standingRowDrawable
            }
        }
    }

    fun updateMinimap(snapshot: RaceMinimapSnapshot) {
        minimap.update(snapshot)
    }

    fun showPause(show: Boolean) {
        pauseMenu.isVisible = show
        pauseMenu.touchable = if (show) Touchable.enabled else Touchable.disabled
        pauseButton.isVisible = !show
    }

    private fun createHudLayout(): Table =
        Table().apply {
            setFillParent(true)
            top().left().pad(22f)

            add(createLeftColumn()).width(235f).expandY().fillY()
            add(createCenterColumn()).expand().fill()
            add(createRightColumn()).width(110f).expandY().fillY()
        }

    private fun createLeftColumn(): Table =
        Table().apply {
            top().left()
            add(
                neonPanel(
                    Table().apply {
                        pad(11f, 14f, 10f, 14f)
                        add(hudLabel("POSITION", 1.25f, MUTED_TEXT)).growX().center().height(29f)
                        row()
                        add(positionValue).grow().center().padBottom(3f)
                    },
                ),
            ).width(220f).height(132f).left()
            row()
            add(createStandings()).width(220f).left().padTop(12f)
        }

    private fun createStandings(): Table =
        Table().apply {
            standingRows.forEach { standing ->
                standing.root =
                    Table().apply {
                        background = standingRowDrawable
                        add(standing.position).width(34f).center()
                        add(standing.name).expandX().left().padLeft(8f)
                    }
                add(standing.root).height(31f).growX().padBottom(4f)
                row()
            }
        }

    private fun createCenterColumn(): Table =
        Table().apply {
            top()
            add(lapValue).height(56f).padTop(3f)
            row()
            add(createLapProgress()).width(380f).height(16f)
            row()
            add(
                neonPanel(
                    Table().apply {
                        add(hudLabel("TIME", 0.9f, MUTED_TEXT)).padRight(15f)
                        add(timeValue)
                    },
                ),
            ).width(315f).height(54f).padTop(12f)
            row()
            add(bestLapValue).padTop(8f)
        }

    private fun createLapProgress(): Stack {
        val track = Table().apply { background = inactiveDrawable }
        val marks =
            Table().apply {
                pad(3f)
                lapSegments.forEachIndexed { index, segment ->
                    segment.background = inactiveDrawable
                    add(segment).grow().padRight(if (index == lapSegments.lastIndex) 0f else 4f)
                }
            }
        return Stack(track, marks)
    }

    private fun createRightColumn(): Table =
        Table().apply {
            top().right()
            add(pauseButton).width(88f).height(76f).right()
            row()
            add(minimap)
                .width(MinimapActor.PREFERRED_WIDTH)
                .height(MinimapActor.PREFERRED_HEIGHT)
                .right()
                .padTop(14f)
        }

    override fun dispose() {
        minimap.dispose()
        super.dispose()
    }

    private fun neonPanel(content: Table): Stack {
        val border = Table().apply { background = cyanDrawable }
        val inner =
            Table().apply {
                background = hudSkin.newDrawable(WHITE_TEXTURE, PANEL_COLOR)
                add(content).grow()
            }
        return Stack(
            border,
            Table().apply {
                pad(2f)
                add(inner).grow()
            },
        )
    }

    private fun createPauseMenu(
        onResume: () -> Unit,
        onRestart: () -> Unit,
        onQuitToMenu: () -> Unit,
    ): Table =
        Table().apply {
            setFillParent(true)
            background = hudSkin.newDrawable(WHITE_TEXTURE, PAUSE_SCRIM)
            val menu =
                Table().apply {
                    background = hudSkin.panelDrawable()
                    pad(28f)
                    add(hudLabel("PAUSED", 2.2f, HUD_CYAN)).width(330f).height(70f)
                    row()
                    add(button("RESUME", onResume)).width(330f).height(62f).pad(7f)
                    row()
                    add(button("RESTART", onRestart)).width(330f).height(62f).pad(7f)
                    row()
                    add(button("QUIT TO MENU", onQuitToMenu)).width(330f).height(62f).pad(7f)
                }
            add(neonPanel(menu)).width(410f).height(340f)
        }

    private fun hudLabel(
        text: String,
        scale: Float,
        color: Color = Color.WHITE,
    ) = Label(text, hudSkin).apply {
        setFontScale(scale)
        this.color = color
        setAlignment(Align.center)
    }

    private data class StandingRow(
        val position: Label,
        val name: Label,
        var root: Table = Table(),
    )

    private companion object {
        const val LAP_SEGMENT_COUNT = 6
        const val MAX_VISIBLE_COMPETITORS = 6
        val HUD_CYAN = Color(0.02f, 0.72f, 1f, 0.96f)
        val MUTED_TEXT = Color(0.78f, 0.84f, 0.9f, 1f)
        val PANEL_COLOR = Color(0.01f, 0.025f, 0.055f, 0.9f)
        val STANDING_ROW = Color(0.015f, 0.035f, 0.07f, 0.86f)
        val PLAYER_ROW = Color(0.02f, 0.28f, 0.72f, 0.94f)
        val SEGMENT_OFF = Color(0.08f, 0.12f, 0.17f, 0.92f)
        val PAUSE_SCRIM = Color(0f, 0f, 0.02f, 0.72f)
    }
}

fun formatRaceTime(seconds: Float): String {
    val safeMilliseconds = (seconds.coerceAtLeast(0f) * 1000f).toInt()
    val minutes = safeMilliseconds / 60_000
    val secondsPart = safeMilliseconds / 1000 % 60
    val milliseconds = safeMilliseconds % 1000
    return "%02d:%02d.%03d".format(minutes, secondsPart, milliseconds)
}
