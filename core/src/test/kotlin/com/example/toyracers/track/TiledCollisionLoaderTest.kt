package com.example.toyracers.track

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream

class TiledCollisionLoaderTest {
    private val loader =
        TiledCollisionLoader(
            imageWidthPixels = 100f,
            imageHeightPixels = 50f,
            authoredWidth = 10f,
            worldScale = 2f,
        )

    @Test
    fun `polygon and circle convert from image pixels into scaled world coordinates`() {
        val shapes =
            loader.load(
                ByteArrayInputStream(
                    """
                    <map>
                      <imagelayer name="track"/>
                      <objectgroup name="road">
                        <object name="road_outer" x="0" y="50">
                          <polygon points="0,-50 100,-50 100,0 0,0"/>
                        </object>
                        <object name="road_inner" x="25" y="35">
                          <polygon points="0,-20 50,-20 50,0 0,0"/>
                        </object>
                      </objectgroup>
                      <objectgroup name="collisions">
                        <object name="box" x="10" y="20">
                          <polygon points="0,0 20,0 20,10 0,10"/>
                        </object>
                        <object name="cup" x="40" y="10" width="10" height="10">
                          <ellipse/>
                        </object>
                      </objectgroup>
                    </map>
                    """.trimIndent().toByteArray(),
                ),
            )

        val polygon = shapes[0] as TrackPolygon
        assertEquals(2f, polygon.vertices[0].x, TOLERANCE)
        assertEquals(6f, polygon.vertices[0].y, TOLERANCE)
        assertEquals(6f, polygon.vertices[2].x, TOLERANCE)
        assertEquals(4f, polygon.vertices[2].y, TOLERANCE)

        val circle = shapes[1] as TrackCircle
        assertEquals(9f, circle.center.x, TOLERANCE)
        assertEquals(7f, circle.center.y, TOLERANCE)
        assertEquals(1f, circle.radius, TOLERANCE)
    }

    @Test(expected = IllegalStateException::class)
    fun `missing collision layer is rejected`() {
        loader.load(
            ByteArrayInputStream(
                """
                <map>
                  <imagelayer name="track"/>
                  <objectgroup name="road"/>
                </map>
                """.trimIndent().toByteArray(),
            ),
        )
    }

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
