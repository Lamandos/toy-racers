package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackCircle
import com.example.toyracers.track.TrackCollisionShape
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackPolygon
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
            track.innerObstacles.forEach { obstacle ->
                resolveRectangleObstacle(state, radius, obstacle, contacts)
            }
            track.collisionShapes.forEach { shape ->
                resolveCollisionShape(state, radius, shape, contacts)
            }
            if (contacts.size == contactCountBeforePass) {
                break
            }
        }

        updateLongitudinalSpeed(state)
        return if (contacts.isEmpty()) CollisionResult.NONE else CollisionResult(contacts)
    }

    private fun resolveCollisionShape(
        state: CarState,
        radius: Float,
        shape: TrackCollisionShape,
        contacts: MutableList<CollisionContact>,
    ) {
        when (shape) {
            is TrackCircle -> resolveCircleObstacle(state, radius, shape, contacts)
            is TrackPolygon -> resolvePolygonObstacle(state, radius, shape, contacts)
        }
    }

    private fun resolveCircleObstacle(
        state: CarState,
        radius: Float,
        obstacle: TrackCircle,
        contacts: MutableList<CollisionContact>,
    ) {
        val offsetX = state.x - obstacle.center.x
        val offsetY = state.y - obstacle.center.y
        val combinedRadius = radius + obstacle.radius
        val distanceSquared = offsetX * offsetX + offsetY * offsetY
        if (distanceSquared >= combinedRadius * combinedRadius) return
        val distance = sqrt(distanceSquared)
        val normalX = if (distance > MIN_DISTANCE) offsetX / distance else 1f
        val normalY = if (distance > MIN_DISTANCE) offsetY / distance else 0f
        resolveShapeContact(
            state,
            normalX,
            normalY,
            combinedRadius - distance,
            contacts,
        )
    }

    private fun resolvePolygonObstacle(
        state: CarState,
        radius: Float,
        obstacle: TrackPolygon,
        contacts: MutableList<CollisionContact>,
    ) {
        val center = TrackPoint(state.x, state.y)
        val closest = closestPolygonEdge(center, obstacle)
        val offsetX = state.x - closest.point.x
        val offsetY = state.y - closest.point.y
        val distance = hypot(offsetX, offsetY)
        val inside = pointInsidePolygon(center, obstacle.vertices)
        if (!inside && distance >= radius) return

        val normalX: Float
        val normalY: Float
        val penetration: Float
        if (inside) {
            val outward = outwardNormal(closest.edgeStart, closest.edgeEnd, obstacle.vertices)
            normalX = outward.first
            normalY = outward.second
            penetration = radius + distance
        } else if (distance <= MIN_DISTANCE) {
            val outward = outwardNormal(closest.edgeStart, closest.edgeEnd, obstacle.vertices)
            normalX = outward.first
            normalY = outward.second
            penetration = radius
        } else {
            normalX = offsetX / distance
            normalY = offsetY / distance
            penetration = radius - distance
        }
        resolveShapeContact(state, normalX, normalY, penetration, contacts)
    }

    private fun resolveShapeContact(
        state: CarState,
        normalX: Float,
        normalY: Float,
        penetration: Float,
        contacts: MutableList<CollisionContact>,
    ) {
        state.x += normalX * penetration
        state.y += normalY * penetration
        addWallContact(
            state,
            normalX,
            normalY,
            penetration,
            CollisionType.TRACK_OBJECT,
            contacts,
        )
    }

    private fun closestPolygonEdge(
        point: TrackPoint,
        polygon: TrackPolygon,
    ): ClosestPolygonEdge {
        var closest: ClosestPolygonEdge? = null
        polygon.vertices.indices.forEach { index ->
            val start = polygon.vertices[index]
            val end = polygon.vertices[(index + 1) % polygon.vertices.size]
            val edgeX = end.x - start.x
            val edgeY = end.y - start.y
            val lengthSquared = edgeX * edgeX + edgeY * edgeY
            val fraction = (
                (point.x - start.x) * edgeX +
                    (point.y - start.y) * edgeY
                ) / lengthSquared
            val clampedFraction = fraction.coerceIn(0f, 1f)
            val edgePoint = TrackPoint(
                start.x + edgeX * clampedFraction,
                start.y + edgeY * clampedFraction,
            )
            val distance = hypot(point.x - edgePoint.x, point.y - edgePoint.y)
            if (closest == null || distance < closest!!.distance) {
                closest = ClosestPolygonEdge(edgePoint, start, end, distance)
            }
        }
        return checkNotNull(closest)
    }

    private fun pointInsidePolygon(
        point: TrackPoint,
        vertices: List<TrackPoint>,
    ): Boolean {
        var inside = false
        var previous = vertices.last()
        vertices.forEach { current ->
            if (
                (current.y > point.y) != (previous.y > point.y) &&
                point.x < (
                    (previous.x - current.x) * (point.y - current.y) /
                        (previous.y - current.y) + current.x
                    )
            ) {
                inside = !inside
            }
            previous = current
        }
        return inside
    }

    private fun outwardNormal(
        start: TrackPoint,
        end: TrackPoint,
        vertices: List<TrackPoint>,
    ): Pair<Float, Float> {
        val edgeX = end.x - start.x
        val edgeY = end.y - start.y
        val length = hypot(edgeX, edgeY)
        val signedArea = vertices.indices.sumOf { index ->
            val current = vertices[index]
            val next = vertices[(index + 1) % vertices.size]
            (current.x * next.y - next.x * current.y).toDouble()
        }
        return if (signedArea >= 0.0) {
            Pair(edgeY / length, -edgeX / length)
        } else {
            Pair(-edgeY / length, edgeX / length)
        }
    }

    private fun resolveRectangleObstacle(
        state: CarState,
        radius: Float,
        obstacle: TrackRectangle,
        contacts: MutableList<CollisionContact>,
    ) {
        val nearestX = state.x.coerceIn(obstacle.x, obstacle.maxX)
        val nearestY = state.y.coerceIn(obstacle.y, obstacle.maxY)
        val offsetX = state.x - nearestX
        val offsetY = state.y - nearestY
        val distanceSquared = offsetX * offsetX + offsetY * offsetY
        if (distanceSquared >= radius * radius) return

        val distance = sqrt(distanceSquared)
        val normalAndPenetration = if (distance > MIN_DISTANCE) {
            Triple(offsetX / distance, offsetY / distance, radius - distance)
        } else {
            insideRectangleNormal(state, radius, obstacle)
        }
        state.x += normalAndPenetration.first * normalAndPenetration.third
        state.y += normalAndPenetration.second * normalAndPenetration.third
        addWallContact(
            state = state,
            normalX = normalAndPenetration.first,
            normalY = normalAndPenetration.second,
            penetration = normalAndPenetration.third,
            type = CollisionType.TRACK_OBJECT,
            contacts = contacts,
        )
    }

    private fun insideRectangleNormal(
        state: CarState,
        radius: Float,
        obstacle: TrackRectangle,
    ): Triple<Float, Float, Float> {
        val distances = listOf(
            Triple(-1f, 0f, state.x - obstacle.x),
            Triple(1f, 0f, obstacle.maxX - state.x),
            Triple(0f, -1f, state.y - obstacle.y),
            Triple(0f, 1f, obstacle.maxY - state.y),
        )
        val nearestSide = distances.minBy { it.third }
        return Triple(nearestSide.first, nearestSide.second, radius + nearestSide.third)
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

    private data class ClosestPolygonEdge(
        val point: TrackPoint,
        val edgeStart: TrackPoint,
        val edgeEnd: TrackPoint,
        val distance: Float,
    )
}
