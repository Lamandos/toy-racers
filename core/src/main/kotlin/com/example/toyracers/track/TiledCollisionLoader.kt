package com.example.toyracers.track

import org.w3c.dom.Element
import java.io.InputStream
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.ParserConfigurationException

/**
 * Reads collision contours from the `collisions` object layer of a Tiled TMX map.
 *
 * Tiled stores object coordinates in image pixels with Y pointing down. Track coordinates use
 * authored image units with Y pointing up, then apply the track's world scale.
 */
class TiledCollisionLoader(
    private val imageWidthPixels: Float,
    private val imageHeightPixels: Float,
    private val authoredWidth: Float,
    private val worldScale: Float,
) {
    init {
        require(imageWidthPixels > 0f)
        require(imageHeightPixels > 0f)
        require(authoredWidth > 0f)
        require(worldScale > 0f)
    }

    fun load(input: InputStream): List<TrackCollisionShape> = loadTrackObjects(input).collisionShapes

    fun loadTrackObjects(input: InputStream): TiledTrackObjects {
        val document = documentBuilderFactory().newDocumentBuilder().parse(input)
        val imageLayers = document.getElementsByTagName("imagelayer")
        val trackImageLayer =
            (0 until imageLayers.length)
                .map { imageLayers.item(it) as Element }
                .firstOrNull { it.getAttribute("name") == TRACK_IMAGE_LAYER_NAME }
                ?: error("TMX map must contain a '$TRACK_IMAGE_LAYER_NAME' image layer")
        val imageOffsetX = trackImageLayer.optionalFloatAttribute("offsetx")
        val imageOffsetY = trackImageLayer.optionalFloatAttribute("offsety")
        val objectGroups = document.getElementsByTagName("objectgroup")
        val layers =
            (0 until objectGroups.length)
                .map { objectGroups.item(it) as Element }
                .associateBy { it.getAttribute("name") }
        val collisionLayer =
            layers[COLLISION_LAYER_NAME]
                ?: error("TMX map must contain a '$COLLISION_LAYER_NAME' object layer")
        val objects = collisionLayer.getElementsByTagName("object")
        val collisionOffsetX =
            collisionLayer.optionalFloatAttribute("offsetx") - imageOffsetX
        val collisionOffsetY =
            collisionLayer.optionalFloatAttribute("offsety") - imageOffsetY
        val collisionShapes =
            (0 until objects.length).map { index ->
                parseObject(
                    objects.item(index) as Element,
                    collisionOffsetX,
                    collisionOffsetY,
                )
            }
        val roadLayer =
            layers[ROAD_LAYER_NAME]
                ?: error("TMX map must contain a '$ROAD_LAYER_NAME' object layer")
        return TiledTrackObjects(
            collisionShapes = collisionShapes,
            roadOuter =
                parseNamedPolygon(
                    roadLayer,
                    ROAD_OUTER_NAME,
                    imageOffsetX,
                    imageOffsetY,
                ),
            roadInner =
                parseNamedPolygon(
                    roadLayer,
                    ROAD_INNER_NAME,
                    imageOffsetX,
                    imageOffsetY,
                ),
        )
    }

    private fun parseNamedPolygon(
        layer: Element,
        objectName: String,
        imageOffsetX: Float,
        imageOffsetY: Float,
    ): TrackPolygon {
        val objects = layer.getElementsByTagName("object")
        val element =
            (0 until objects.length)
                .map { objects.item(it) as Element }
                .firstOrNull { it.getAttribute("name") == objectName }
                ?: error("Tiled layer '$ROAD_LAYER_NAME' must contain '$objectName'")
        return parseObject(
            element,
            layer.optionalFloatAttribute("offsetx") - imageOffsetX,
            layer.optionalFloatAttribute("offsety") - imageOffsetY,
        ) as? TrackPolygon
            ?: error("Tiled road contour '$objectName' must be a polygon")
    }

    private fun parseObject(
        element: Element,
        layerOffsetX: Float,
        layerOffsetY: Float,
    ): TrackCollisionShape {
        val x = element.floatAttribute("x") + layerOffsetX
        val y = element.floatAttribute("y") + layerOffsetY
        val polygons = element.getElementsByTagName("polygon")
        if (polygons.length > 0) {
            val points =
                (polygons.item(0) as Element)
                    .getAttribute("points")
                    .trim()
                    .split(Regex("\\s+"))
                    .map { point ->
                        val coordinates = point.split(",")
                        require(coordinates.size == 2) { "Invalid Tiled polygon point: $point" }
                        toTrackPoint(
                            pixelX = x + coordinates[0].toFloat(),
                            pixelY = y + coordinates[1].toFloat(),
                        )
                    }
            return TrackPolygon(points)
        }

        if (element.getElementsByTagName("ellipse").length > 0) {
            val width = element.floatAttribute("width")
            val height = element.floatAttribute("height")
            if (kotlin.math.abs(width - height) <= CIRCLE_TOLERANCE_PIXELS) {
                return TrackCircle(
                    center = toTrackPoint(x + width / 2f, y + height / 2f),
                    radius = pixelsToWorld(width / 2f),
                )
            }
            return TrackPolygon(
                List(ELLIPSE_SEGMENTS) { index ->
                    val angle = Math.PI * 2.0 * index / ELLIPSE_SEGMENTS
                    toTrackPoint(
                        pixelX = x + width / 2f + kotlin.math.cos(angle).toFloat() * width / 2f,
                        pixelY = y + height / 2f + kotlin.math.sin(angle).toFloat() * height / 2f,
                    )
                },
            )
        }

        error("Collision object '${element.getAttribute("name")}' must be a polygon or ellipse")
    }

    private fun toTrackPoint(
        pixelX: Float,
        pixelY: Float,
    ): TrackPoint =
        TrackPoint(
            x = pixelsToWorld(pixelX),
            y = pixelsToWorld(imageHeightPixels - pixelY),
        )

    private fun pixelsToWorld(pixels: Float): Float = pixels / imageWidthPixels * authoredWidth * worldScale

    private fun Element.floatAttribute(name: String): Float =
        getAttribute(name).toFloatOrNull()
            ?: error("TMX object is missing numeric '$name'")

    private fun Element.optionalFloatAttribute(name: String): Float = getAttribute(name).toFloatOrNull() ?: 0f

    private fun documentBuilderFactory(): DocumentBuilderFactory =
        DocumentBuilderFactory.newInstance().apply {
            // XInclude processing is disabled by default. Android's parser throws even when asked
            // to explicitly set that default, so leave it untouched for platform compatibility.
            isExpandEntityReferences = false
            setFeatureIfSupported("http://apache.org/xml/features/disallow-doctype-decl", true)
            setFeatureIfSupported("http://xml.org/sax/features/external-general-entities", false)
            setFeatureIfSupported("http://xml.org/sax/features/external-parameter-entities", false)
        }

    private fun DocumentBuilderFactory.setFeatureIfSupported(
        feature: String,
        enabled: Boolean,
    ) {
        try {
            setFeature(feature, enabled)
        } catch (_: ParserConfigurationException) {
            // Android's bundled parser does not implement every standard Xerces/SAX feature.
        }
    }

    private companion object {
        const val COLLISION_LAYER_NAME = "collisions"
        const val TRACK_IMAGE_LAYER_NAME = "track"
        const val ROAD_LAYER_NAME = "road"
        const val ROAD_OUTER_NAME = "road_outer"
        const val ROAD_INNER_NAME = "road_inner"
        const val CIRCLE_TOLERANCE_PIXELS = 0.01f
        const val ELLIPSE_SEGMENTS = 24
    }
}

data class TiledTrackObjects(
    val collisionShapes: List<TrackCollisionShape>,
    val roadOuter: TrackPolygon,
    val roadInner: TrackPolygon,
)
