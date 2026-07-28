# `track_02` collision authoring

Open `track_02.tmx` in [Tiled](https://www.mapeditor.org/). The background image is linked
relatively, so keep the `.tmx` and `.png` files in the same directory.

## Required road contours

On the green `road` object layer:

The `road_outer` and `road_inner` contours are already authored for gameplay. Refine their
points if visual testing reveals a mismatch with the asphalt edges.

Keep the object names exactly `road_outer` and `road_inner`. Both objects must remain polygons.
The game treats the area inside `road_outer` and outside `road_inner` as asphalt.

## Solid-object collisions

On the yellow `collisions` object layer, draw one object around each solid obstacle:

- use polygons for walls, furniture, and irregular objects;
- use ellipses for round objects;
- use several small convex polygons instead of one deeply concave polygon when practical.

Do not use rectangle objects: the runtime loader currently accepts only polygons and ellipses.
Keep every collision object directly on the `collisions` layer.

## Before runtime integration

Save the map and visually check it in Tiled with the `road` and `collisions` layers visible.
Start positions, checkpoints, racing line, scale, and camera bounds are defined in `TrackLoader`.
