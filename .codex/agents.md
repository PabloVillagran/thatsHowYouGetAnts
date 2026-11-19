# Project constraints

- Use Godot 4.7.
- Develop for and on Android.
- Make a 2D idle game about managing an ant colony.
- The core objective is “big number goes bigger.”
- Main-game elements must be represented with `Polygon2D` nodes or particles.
- Do not use assets for the main game; assets may be used only for GUI elements.

## Ant behavior contract

- Workers spawn in the 10 by 10 pixel queen deposit square and join the nearest leader within 40 pixels if that cluster has fewer than 10 ants; otherwise they become a leader. Leaders select the nearest live food polygon. Their cluster travels together, scatters within the polygon radius plus 1 pixel, gathers, and returns together to the deposit square. If a polygon depletes during outbound travel, ants rejoin a nearby leader with room or form a new cluster. If it depletes during gathering, ants first seek a nearby leader; otherwise they return to the deposit square and seek a leader there, becoming one if none is available. Only regular food polygons are forage targets; death drops are ignored.
- In Queen Ant 1, workers expire after 30 seconds plus 10 seconds per worker-lifetime upgrade level. Expired workers disappear; carried food becomes a harvestable 1 by 1 pixel food drop at the worker's death position.
