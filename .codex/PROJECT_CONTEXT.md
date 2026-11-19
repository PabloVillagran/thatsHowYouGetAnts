# Project context

- Engine: Godot 4.7.
- Platform: Android; developed on Android.
- Format: 2D idle game.
- Theme: managing an ant colony.
- Core objective: “big number goes bigger.”
- Main-game visuals: use only `Polygon2D` nodes and particles for game elements.
- Assets: reserve assets for GUI elements; the main game should not use imported art assets.

## Version menu

- `scenes/main_menu.tscn` is the startup scene configured in `project.godot`. Its text-based menu separates the game versions.
- Selecting Incremental 1 opens `MainScene.tscn`, the existing game.
- Selecting Queen Ant 1 opens `scenes/queen_ant_1.tscn`, a separate variant that uses the existing food-source foraging loop.
- The menu has no in-game return navigation; restarting the app returns to the version menu.

## Food amount

- The global `GameState` autoload in `scripts/game_state.gd` owns `food_amount`, initialized to 250 and clamped so it cannot fall below zero.
- Change the amount through `GameState.add_food(amount)` and `GameState.spend_food(amount)`. Adding ignores non-positive values; spending returns `false` when the requested amount is negative or unavailable, and otherwise deducts it and returns `true`.
- `GameState.food_changed(amount)` is emitted when the amount changes. UI that displays food should listen to this signal and also read `GameState.food_amount` when it starts.
- The main scene has a text-only food label pinned to the bottom of the screen. Food sources, per-worker collection and delivery, and automatic queen food production are implemented.
- Workers move in leader-and-follower clusters of up to 10 ants. Each cluster searches for food independently. The first worker costs 5 food; each next worker price grows by 1.25x.
- Queens cost 1,000 food initially and each next queen price grows by 1.5x. Every queen produces one food every five seconds. The queen production upgrade adds one food per queen per five-second interval.
- The carry upgrade adds one food per worker trip per level. Speed increases by 10% per level. Food efficiency increases generated food-source stockpiles by 10% per level.
- Each upgrade starts at 25 food and each upgrade's next cost grows independently by 1.15x. The text-only purchase UI abbreviates large displayed values with K, M, and B.
- Queen Ant 1 keeps the same food-foraging gameplay, but queens spawn one worker per five seconds each instead of generating food directly. Its queen production upgrade increases worker spawn rate; workers expire after 30 seconds, and each worker-lifetime upgrade level adds 10 seconds. Queen Ant 1 does not offer direct worker purchases.
- The first worker in each Queen Ant 1 cluster spawns at the queen; later workers follow the preceding ant. Expired workers remain as hollow ants with a 1-pixel blue outline. A worker that dies while carrying food leaves a harvestable, 1 by 1 pixel food drop inside the queen's 10 by 10 pixel delivery area.
- `GameState` loads and saves a local JSON snapshot at `user://game_state.json`. Every successful purchase saves food, colony counts, upgrade levels, and next prices. Older snapshots default new economy fields to their initial values.

## Ant spawning and foraging

- `AntSource` is a direct child of each game scene and centers its world origin on the viewport at startup; the camera frames the same center. Ant polygons must remain large enough to see at the default zoom.
- A loaded colony always has at least one queen, including after recovering a save with a zero queen count.
- Workers form leader-and-follower clusters capped at 10 ants. Each new cluster starts at the queen's spawn point; its leader searches for the nearest live food source immediately, and the other workers follow in order.
- Workers gather food individually, return to a randomly selected point in the 10 by 10 pixel square centered on the queen's spawn point, and add their carried food to the global amount.
- If a Queen Ant 1 worker expires while carrying food, its carried amount becomes a harvestable 1 by 1 pixel food drop inside that same 10 by 10 pixel square. Expired ants remain as hollow shapes with a 1-pixel blue outline.
