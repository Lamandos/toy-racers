package com.example.toyracers.ui

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.Scaling
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.car.CarModel
import com.example.toyracers.car.CarPerformance
import kotlin.math.roundToInt

/** Displays every player car without coupling the selected visual to simulation rules. */
class CarSelectionStage(
    options: List<CarSelectionOption>,
    initiallySelected: CarModel,
    private val onCarSelected: (CarModel) -> Unit,
    onStartRace: () -> Unit,
    onBack: () -> Unit,
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    init {
        require(options.isNotEmpty()) { "Car selection requires at least one option" }
        require(options.any { it.model == initiallySelected }) { "Selected car must be an option" }
    }

    private val skin = createGameUiSkin()
    private val stage = Stage(ExtendViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT))
    private val statusLabels = mutableMapOf<CarModel, Label>()
    private var selected = initiallySelected

    val inputProcessor: InputProcessor
        get() = stage

    init {
        val content = Table().apply {
            setFillParent(true)
            background = this@CarSelectionStage.skin.panelDrawable()
            pad(22f)
            add(Label("SELECT CAR", this@CarSelectionStage.skin).apply {
                setFontScale(2.2f)
            }).colspan(options.size).height(105f)
            row()
            options.forEach { option ->
                add(carCard(option)).width(CARD_WIDTH).height(410f).pad(8f)
            }
            row()
        add(button("BACK", SECONDARY_BUTTON_STYLE, onBack)).width(260f).height(68f).padTop(18f)
            add(button("START RACE", action = onStartRace))
                .colspan(options.size - 1)
                .width(360f)
                .height(68f)
                .padTop(18f)
        }
        stage.addActor(content)
        refreshStatuses()
    }

    private fun carCard(option: CarSelectionOption): TextButton = TextButton("", skin).apply {
        clearChildren()
        add(Image(option.preview).apply {
            setScaling(Scaling.fit)
        }).grow().pad(14f)
        row()
        add(Label(option.model.displayName, skin).apply {
            setFontScale(1.05f)
        }).height(48f)
        row()
        add(performanceTable(option.model.performance))
            .height(82f)
            .growX()
            .padLeft(8f)
            .padRight(8f)
        row()
        add(Label("", skin).also { statusLabels[option.model] = it }).height(42f)
        addListener(object : ClickListener() {
            override fun clicked(event: InputEvent, x: Float, y: Float) {
                onButtonClick()
                selected = option.model
                onCarSelected(option.model)
                refreshStatuses()
            }
        })
    }

    private fun performanceTable(performance: CarPerformance): Table = Table().apply {
        addPerformanceRow("ACCEL", performance.acceleration)
        row()
        addPerformanceSeparator()
        row()
        addPerformanceRow("SPEED", performance.maxSpeed)
        row()
        addPerformanceSeparator()
        row()
        addPerformanceRow("HANDLING", performance.handling)
    }

    private fun Table.addPerformanceSeparator() {
        add(Image(this@CarSelectionStage.skin.newDrawable("white", STAT_SEPARATOR)))
            .colspan(STAT_COLUMN_COUNT)
            .height(STAT_SEPARATOR_HEIGHT)
            .growX()
            .padTop(2f)
            .padBottom(2f)
    }

    private fun Table.addPerformanceRow(label: String, multiplier: Float) {
        add(Label(label, this@CarSelectionStage.skin).apply { setFontScale(0.72f) })
            .width(72f)
            .left()
        val filledSquares = performanceSquareCount(multiplier)
        repeat(STAT_SQUARE_COUNT) { index ->
            val color = if (index < filledSquares) STAT_FILLED else STAT_EMPTY
            add(Image(this@CarSelectionStage.skin.newDrawable("white", color)))
                .size(STAT_SQUARE_SIZE)
                .padLeft(2f)
                .padRight(2f)
        }
    }

    private fun refreshStatuses() {
        statusLabels.forEach { (model, label) ->
            label.setText(if (model == selected) "SELECTED" else "SELECT")
        }
    }

    private fun button(
        text: String,
        style: String = "default",
        action: () -> Unit,
    ): TextButton = TextButton(text, skin, style).apply {
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
        const val MAX_UI_DELTA = 0.1f
        const val CARD_WIDTH = 230f
        const val STAT_SQUARE_COUNT = 5
        const val STAT_COLUMN_COUNT = STAT_SQUARE_COUNT + 1
        const val STAT_SQUARE_SIZE = 15f
        const val STAT_SEPARATOR_HEIGHT = 1f
        val STAT_FILLED = Color(0.96f, 0.68f, 0.18f, 1f)
        val STAT_EMPTY = Color(0.25f, 0.29f, 0.34f, 1f)
        val STAT_SEPARATOR = Color(0.55f, 0.62f, 0.68f, 0.65f)
    }
}

data class CarSelectionOption(
    val model: CarModel,
    val preview: TextureRegion,
)

/** Maps the supported performance range onto the five-square selection UI. */
internal fun performanceSquareCount(multiplier: Float): Int {
    val normalized = (multiplier - CarPerformance.MIN_MULTIPLIER) /
        (CarPerformance.MAX_MULTIPLIER - CarPerformance.MIN_MULTIPLIER)
    return (1 + (normalized * 4f).roundToInt()).coerceIn(1, 5)
}
