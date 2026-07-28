package com.example.toyracers.collision

data class CollisionResult(
    val contacts: List<CollisionContact> = emptyList(),
) {
    val collided: Boolean
        get() = contacts.isNotEmpty()
    val maxImpactSpeed: Float
        get() = contacts.maxOfOrNull(CollisionContact::impactSpeed) ?: 0f

    companion object {
        val NONE = CollisionResult()
    }
}

data class CollisionContact(
    val type: CollisionType,
    val normalX: Float,
    val normalY: Float,
    val penetration: Float,
    val impactSpeed: Float,
)

enum class CollisionType {
    WORLD_BOUNDARY,
    TRACK_OBJECT,
    CAR,
}
