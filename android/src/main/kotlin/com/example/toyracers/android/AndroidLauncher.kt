package com.example.toyracers.android

import android.os.Bundle
import com.badlogic.gdx.backends.android.AndroidApplication
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration
import com.example.toyracers.ToyRacersGame

/** Launches the Android application. */
class AndroidLauncher : AndroidApplication() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialize(
            ToyRacersGame(),
            AndroidApplicationConfiguration().apply {
                // Configure your application here.
                useImmersiveMode = true // Recommended, but not required.
            },
        )
    }
}
