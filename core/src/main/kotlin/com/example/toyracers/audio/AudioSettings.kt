package com.example.toyracers.audio

/** User-controlled audio levels. Values are normalized to 0..1. */
data class AudioSettings(
    val masterVolume: Float = 1f,
    val musicVolume: Float = 0.55f,
    val sfxVolume: Float = 0.8f,
    val vibrationEnabled: Boolean = true,
) {
    init {
        require(masterVolume in 0f..1f)
        require(musicVolume in 0f..1f)
        require(sfxVolume in 0f..1f)
    }

    val effectiveMusicVolume: Float get() = masterVolume * musicVolume
    val effectiveSfxVolume: Float get() = masterVolume * sfxVolume
}
