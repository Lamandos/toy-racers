package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackRectangle
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Deterministic circle-based collision detection and response. */
class CollisionSystem(
    private val config: CollisionConfig = CollisionConfig(),
) {
    fun resolveTrackCollision(
        state: CarState,
        radius: Float,
        track: Track,
    ): CollisionResult {
        require(radius > 0f) { "Collision radius must be positive" }
        require(track.worldBounds.width >= radius * 2f) {
            "Collision radius does not fit inside world bounds width"
        }
        require(track.worldBounds.height >= radius * 2f) {
            "Collision radius does not fit inside world bounds height"
        }
        val contacts = mutableListOf<CollisionContact>()

        var passesRemaining = MAX_RESOLUTION_PASSES
        while (passesRemaining > 0) {
            passesRemaining--
            val contactCountBeforePass = contacts.size
            resolveOuterBoundary(state, radius, track.worldBounds, contacts)
            if (contacts.size == contactCountBeforePass) {
                break
            }
        }

        updateLongitudinalSpeed(state)
        return if (contacts.isEmpty()) CollisionResult.NONE else CollisionResult(contacts)
    }

    fun resolveCarCollision(
        first: CarState,
        firstRadius: Float,
        second: CarState,
        secondRadius: Float,
    ): CollisionResult {
        require(firstRadius > 0f) { "First collision radius must be positive" }
        require(secondRadius > 0f) { "Second collision radius must be positive" }

        val offsetX = second.x - first.x
        val offsetY = second.y - first.y
        val distanceSquared = offsetX * offsetX + offsetY * offsetY
        val combinedRadius = firstRadius + secondRadius
        if (distanceSquared >= combinedRadius * combinedRadius) {
            return CollisionResult.NONE
        }

        val distance = sqrt(distanceSquared)
        val normalX = if (distance > MIN_DISTANCE) offsetX / distance else 1f
        val normalY = if (distance > MIN_DISTANCE) offsetY / distance else 0f
        val penetration = combinedRadius - distance
        val correction = penetration / 2f
        first.x -= normalX * correction
        first.y -= normalY * correction
        second.x += normalX * correction
        second.y += normalY * correction

        val relativeVelocityX = first.velocityX - second.velocityX
        val relativeVelocityY = first.velocityY - second.velocityY
        val closingSpeed =
            (relativeVelocityX * normalX + relativeVelocityY * normalY).coerceAtLeast(0f)
        val impulse = min(
            closingSpeed * (1f + config.carRestitution) / 2f,
            config.maxCarImpulse,
        )
        first.velocityX -= normalX * impulse
        first.velocityY -= normalY * impulse
        second.velocityX += normalX * impulse
        second.velocityY += normalY * impulse
        updateLongitudinalSpeed(first)
        updateLongitudinalSpeed(second)

        return CollisionResult(
            listOf(
                CollisionContact(
                    type = CollisionType.CAR,
                    normalX = -normalX,
                    normalY = -normalY,
                    penetration = penetration,
                    impactSpeed = closingSpeed,
                ),
            ),
        )
    }

    private fun resolveOuterBoundary(
        state: CarState,
        radius: Float,
        boundary: TrackRectangle,
        contacts: MutableList<CollisionContact>,
    ) {
        val minimumX = boundary.x + radius
        val maximumX = boundary.maxX - radius
        val minimumY = boundary.y + radius
        val maximumY = boundary.maxY - radius

        if (state.x < minimumX) {
            val penetration = minimumX - state.x
            state.x = minimumX
            addWallContact(state, 1f, 0f, penetration, CollisionType.WORLD_BOUNDARY, contacts)
        } else if (state.x > maximumX) {
            val penetration = state.x - maximumX
            state.x = maximumX
            addWallContact(state, -1f, 0f, penetration, CollisionType.WORLD_BOUNDARY, contacts)
        }

        if (state.y < minimumY) {
            val penetration = minimumY - state.y
            state.y = minimumY
            addWallContact(state, 0f, 1f, penetration, CollisionType.WORLD_BOUNDARY, contacts)
        } else if (state.y > maximumY) {
            val penetration = state.y - maximumY
            state.y = maximumY
            addWallContact(state, 0f, -1f, penetration, CollisionType.WORLD_BOUNDARY, contacts)
        }
    }

    private fun addWallContact(
        state: CarState,
        normalX: Float,
        normalY: Float,
        penetration: Float,
        type: CollisionType,
        contacts: MutableList<CollisionContact>,
    ) {
        val velocityIntoAllowedArea = state.velocityX * normalX + state.velocityY * normalY
        val impactSpeed = (-velocityIntoAllowedArea).coerceAtLeast(0f)
        if (velocityIntoAllowedArea < 0f) {
            state.velocityX -= normalX * velocityIntoAllowedArea
            state.velocityY -= normalY * velocityIntoAllowedArea
            state.velocityX *= config.wallSpeedRetention
            state.velocityY *= config.wallSpeedRetention
        }
        contacts += CollisionContact(type, normalX, normalY, penetration, impactSpeed)
    }

    private fun updateLongitudinalSpeed(state: CarState) {
        val radians = Math.toRadians(state.rotationDeg.toDouble())
        state.speed =
            state.velocityX * cos(radians).toFloat() +
            state.velocityY * sin(radians).toFloat()
        if (hypot(state.velocityX, state.velocityY) < MIN_DISTANCE) {
            state.velocityX = 0f
            state.velocityY = 0f
            state.speed = 0f
        }
    }

    private companion object {
        const val MAX_RESOLUTION_PASSES = 4
        const val MIN_DISTANCE = 0.0001f
    }
}
