package com.example.toyracers.input

/** Common source of normalized commands consumed by the car controller. */
fun interface CarInputProvider {
    fun readInput(): PlayerInput
}

typealias CarInput = PlayerInput
