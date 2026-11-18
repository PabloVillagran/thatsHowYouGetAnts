# Project context

- Engine: Godot 4.7.
- Platform: Android; developed on Android.
- Format: 2D idle game.
- Theme: managing an ant colony.
- Core objective: “big number goes bigger.”
- Main-game visuals: use only `Polygon2D` nodes and particles for game elements.
- Assets: reserve assets for GUI elements; the main game should not use imported art assets.

## Food amount

- The global `GameState` autoload in `scripts/game_state.gd` owns `food_amount`, initialized to 0 and clamped so it cannot fall below zero.
- Change the amount through `GameState.add_food(amount)` and `GameState.spend_food(amount)`. Adding ignores non-positive values; spending returns `false` when the requested amount is negative or unavailable, and otherwise deducts it and returns `true`.
- `GameState.food_changed(amount)` is emitted when the amount changes. UI that displays food should listen to this signal and also read `GameState.food_amount` when it starts.
- The main scene's text-only food label is pinned to the bottom of the screen and displays the current amount. Food sources and ant collection are separate mechanics and have not yet been implemented.
- Worker purchases are organized into groups capped at 100 ants. Once the current worker group reaches 100, the next purchase starts another group; each worker still costs 100 food.
- `GameState` loads and saves a local JSON snapshot at `user://game_state.json`. Pressing the worker purchase button saves the Unix update timestamp, food amount, and queen, worker, and warrior counts. On startup, a saved snapshot restores the food balance and colony counts; without a snapshot, scene defaults apply.
