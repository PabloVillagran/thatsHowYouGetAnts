# Project constraints

- Use Godot 4.7.
- Develop for and on Android.
- Make a 2D idle game about managing an ant colony.
- The core objective is “big number goes bigger.”
- Main-game elements use `Polygon2D` nodes or particles, except that queens, workers, and defenders use the role-specific transparent pixel-art sprites in `assets/Ants`.
- Other imported artwork is limited to GUI elements.
- The shared `AntSource` world root is scaled 4x in both playable scenes, quadrupling every game object's rendered size and world spacing. CanvasLayer GUI elements stay at their original size.

## Ant behavior contract

- Step-grid tracking is capability-based: `AntParticle.can_dig` determines whether an ant contributes visits. Currently only workers are spawned with digging enabled; future ant types may opt into the same tracker by enabling the flag. All ants use local step counts for movement speed: 0 steps gives a 75% slowdown, increasing linearly to normal speed at 100. Worker-group leaders choose weighted shortest routes on the triangular grid, where edge cost is distance divided by average local speed, preferring stepped terrain when it makes travel faster; followers track the ant ahead without calculating routes. With no visited points, leaders travel directly to their targets.
- Workers spawn in the 10 by 10 pixel queen deposit square and join the smallest eligible leader group, with nearest leader breaking ties. Both variants divide workers as evenly as possible across available queen-led groups; one queen means one group for all workers, with no per-group cap. Group counts and sizes rebalance as queens or workers are added and workers expire. Leaders select the nearest live food polygon. Group ants scatter within the polygon radius plus 1 pixel immediately on arrival, without waiting for every ant to arrive. Ants gather independently; once every member's gather timer ends, followers keep following the ant ahead of them on the return trip. Each ant deposits food on arrival at its stockpile position; the group waits for everyone to arrive before following the leader to the next source. Depletion recovery follows the rules in `.codex/ant_source_behavior_and_plan.md`. Only regular food polygons are forage targets; death drops are ignored.
- In Queen Ant 1, workers expire after 30 seconds plus 10 seconds per worker-lifetime upgrade level. Expired workers disappear; carried food becomes a harvestable 1 by 1 pixel food drop at the worker's death position.
- Each depleted food polygon in either variant rolls a 1-in-10 chance to spawn tappable super food at the source. It is a bright yellow oval bug at 0 degrees, distinct from the orange food polygons, with glitter particles that scale with it. Its screen-space size follows camera zoom, with a 30-pixel minimum. It stays hidden and untappable until its initial camera-scaled size is set, then disappears 50 seconds after spawning. It is player-only, doubles worker movement speed for 10 seconds, and refreshes an active boost. Draw it above ants and below the CanvasLayer UI.
