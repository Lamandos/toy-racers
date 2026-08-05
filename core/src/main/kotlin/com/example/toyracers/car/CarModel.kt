package com.example.toyracers.car

/** Player-selectable models with balanced deterministic performance profiles. */
enum class CarModel(
    val displayName: String,
    val assetPath: String,
    val performance: CarPerformance,
) {
    RED_STRIPE(
        "RED STRIPE",
        "sprites/cars/red-stripe.png",
        CarPerformance(acceleration = 1.10f, maxSpeed = 0.95f, handling = 0.80f),
    ),
    BLUE_STRIPE(
        "BLUE STRIPE",
        "sprites/cars/blue-stripe.png",
        CarPerformance(acceleration = 0.95f, maxSpeed = 0.80f, handling = 1.10f),
    ),
    YELLOW_SPORT(
        "YELLOW SPORT",
        "sprites/cars/yellow-sport.png",
        CarPerformance(acceleration = 0.80f, maxSpeed = 1.10f, handling = 0.95f),
    ),
    GREEN_RACER(
        "GREEN RACER",
        "sprites/cars/green-racer.png",
        CarPerformance(acceleration = 0.95f, maxSpeed = 1.10f, handling = 0.80f),
    ),
    ORANGE_TRUCK(
        "ORANGE TRUCK",
        "sprites/cars/orange-truck.png",
        CarPerformance(acceleration = 0.80f, maxSpeed = 0.95f, handling = 1.10f),
    ),
}

/** Relative tuning applied to the common car baseline. */
data class CarPerformance(
    val acceleration: Float,
    val maxSpeed: Float,
    val handling: Float,
) {
    init {
        require(acceleration in MIN_MULTIPLIER..MAX_MULTIPLIER)
        require(maxSpeed in MIN_MULTIPLIER..MAX_MULTIPLIER)
        require(handling in MIN_MULTIPLIER..MAX_MULTIPLIER)
    }

    val total: Float
        get() = acceleration + maxSpeed + handling

    fun applyTo(base: CarConfig = CarConfig()): CarConfig = base.copy(
        acceleration = base.acceleration * acceleration,
        maxForwardSpeed = base.maxForwardSpeed * maxSpeed,
        steeringSpeed = base.steeringSpeed * handling,
    )

    companion object {
        const val MIN_MULTIPLIER = 0.80f
        const val MAX_MULTIPLIER = 1.10f
    }
}

internal fun opponentModelsFor(playerModel: CarModel): List<CarModel> =
    CarModel.entries.filterNot { it == playerModel } +
        CarModel.entries.first { it != playerModel }
