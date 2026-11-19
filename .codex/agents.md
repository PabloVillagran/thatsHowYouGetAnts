# Project constraints

- Use Godot 4.7.
- Develop for and on Android.
- Make a 2D idle game about managing an ant colony.
- The core objective is “big number goes bigger.”
- Main-game elements must be represented with `Polygon2D` nodes or particles.
- Do not use assets for the main game; assets may be used only for GUI elements.

## Ant behavior contract

- Worker clusters have at most 10 ants. The leader searches for the nearest food source and followers trail in order; each worker gathers and returns food individually.
- The first worker in each cluster starts at the queen's spawn point. Delivered food targets the 10 by 10 pixel area centered there.
- In Queen Ant 1, workers expire after 30 seconds plus 10 seconds per worker-lifetime upgrade level. Expired workers remain as hollow ants with a 1-pixel blue outline; carried food becomes a harvestable 1 by 1 pixel food drop in the queen's delivery area.
