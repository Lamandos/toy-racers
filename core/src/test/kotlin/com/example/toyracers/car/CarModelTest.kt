package com.example.toyracers.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CarModelTest {
    @Test
    fun `five selectable cars have unique asset paths`() {
        assertEquals(5, CarModel.entries.size)
        assertEquals(
            5,
            CarModel.entries
                .map(CarModel::assetPath)
                .toSet()
                .size,
        )
    }

    @Test
    fun `every unselected model becomes an opponent`() {
        CarModel.entries.forEach { playerModel ->
            val opponents = opponentModelsFor(playerModel)

            assertEquals(5, opponents.size)
            assertFalse(opponents.contains(playerModel))
            assertEquals(CarModel.entries.toSet() - playerModel, opponents.toSet())
        }
    }

    @Test
    fun `performance totals are balanced and each spread is at most thirty percent`() {
        val totals = CarModel.entries.map { it.performance.total }
        val acceleration = CarModel.entries.map { it.performance.acceleration }
        val maxSpeed = CarModel.entries.map { it.performance.maxSpeed }
        val handling = CarModel.entries.map { it.performance.handling }

        totals.forEach { assertEquals(totals.first(), it, TOLERANCE) }
        listOf(acceleration, maxSpeed, handling).forEach { values ->
            assertTrue(values.max() - values.min() <= 0.30f + TOLERANCE)
        }
    }

    @Test
    fun `performance modifies only requested handling characteristics`() {
        val base = CarConfig()
        val tuned = CarModel.RED_STRIPE.performance.applyTo(base)

        assertEquals(base.acceleration * 1.10f, tuned.acceleration, TOLERANCE)
        assertEquals(base.maxForwardSpeed * 0.95f, tuned.maxForwardSpeed, TOLERANCE)
        assertEquals(base.steeringSpeed * 0.80f, tuned.steeringSpeed, TOLERANCE)
        assertEquals(base.brakeForce, tuned.brakeForce, TOLERANCE)
        assertEquals(base.collisionRadius, tuned.collisionRadius, TOLERANCE)
    }

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
