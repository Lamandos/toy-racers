package com.example.toyracers.track

/** Stable identifiers and player-facing names for built-in tracks. */
enum class TrackId(
    val value: String,
    val displayName: String,
) {
    LIVING_ROOM("track-01", "LIVING ROOM"),
    BATHROOM("track-02", "BATHROOM"),
    ;

    companion object {
        fun fromValue(value: String): TrackId =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown track: $value")
    }
}
