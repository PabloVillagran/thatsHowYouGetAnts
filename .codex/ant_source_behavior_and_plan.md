# AntSource behavior and implementation plan

## Purpose

`AntSource` is the colony's on-screen ant emitter and coordinator. It owns a collection of independently moving ant particles. The initial test colony contains 14 ants across queen, worker, and warrior clusters.

## Ant appearance and states

- Draw each ant at approximately 1 pixel wide by 2 pixels long.
- Each ant has one of three states: `idle`, `walking`, or `gathering`.
- `gathering` is part of the state model, but its behavior will be added when the food element is introduced. Until then, ants should not enter this state.
- Main-game ant visuals must follow the project rule to use `Polygon2D` or particles; do not add imported art assets for ants.

## Movement behavior

- On startup, the ants form a small colony around the source's center of mass.
- Idle ants continually scatter to random points no more than 10 pixels from their individual idle anchors.
- The first emitted worker is the worker-cluster leader. It chooses and walks toward a destination.
- Remaining workers follow the worker emitted immediately before them, producing a worker leader-to-follower chain. Warriors form a separate scouting chain.
- Workers scatter while idle during startup; after their first destination, their leader searches for food and the rest follow in order.

## Implementation plan

1. **Create the scene structure.** Keep `scenes/ant_source.tscn` as the reusable `AntSource` scene. Add a source controller and an ant visual/agent representation that can be instanced once per ant.
2. **Represent each ant independently.** Give each ant a state, position, heading, and target. Use a small `Polygon2D` shape sized to approximately 1 by 2 pixels, oriented along its heading. This allows precise per-ant steering and state changes while complying with the visual constraint; avoid relying on a single opaque GPU particle effect for agents that need individual behavior.
3. **Spawn the test colony.** Have `AntSource` create 14 agents in three clusters: one queen, 10 workers, and three warriors. Preserve emission order within the worker cluster so its first ant is the leader.
4. **Add idle motion.** Give every idle ant a personal scatter anchor and keep its idle movement within 10 pixels of that anchor. Avoid abrupt jumps when switching between idle and walking.
5. **Add leader and follower movement.** Give the leader a destination and move it toward that point. Make each worker and warrior follower trail its predecessor with a configurable spacing and smooth steering. Prevent followers from collapsing into the same position.
6. **Define state transitions.** Implement `idle` and `walking` transitions now. Keep `gathering` declared and reserved for the later food interaction; do not invent gathering rules yet.
7. **Integrate and inspect.** Instance `AntSource` in the main scene, then confirm visually that all 14 ants appear in separate clusters, the queen remains idle, workers seek food and follow in order, and warriors scout with idle pauses between destinations.

## Completion criteria for this stage

- The reusable AntSource scene displays 14 ants (1 queen, 10 workers, 3 warriors) at roughly 1 by 2 pixels each.
- The ant representation remains readable at the project's intended display scale.
- Idle ants scatter within 10 pixels of their individual anchors without changing their `idle` state.
- The first worker leads its cluster toward destinations; worker and warrior followers trail their own cluster leaders in emission order.
- Ants have the three named states, while gathering behavior remains deferred until food exists.

## Initial ant types

- `queen`: white.
- `worker`: blue.
- `warrior`: dark red.
- The prototype contains one queen, 10 workers, and three warriors in separate clusters. The first emitted worker leads the worker chain; the queen and warriors have separate behavior.

## Food search behavior

- After the colony completes its initial destination, the leader looks for the nearest `Node2D` in the `food_sources` group within `food_search_range` (default 120 pixels).
- If a source is found, the leader walks to it and the remaining ants follow their predecessor.
- If no source is in range, the leader picks a random scouting point within `food_search_range`; followers trail behind. After its idle pause, the colony searches again.
- At a food source, ants wait in `idle`. Gathering and food collection remain deferred until those mechanics are defined.
- Food source nodes should join the `food_sources` group. The search range is adjustable on `AntSource`.

## Ant clusters and role behavior

- `QueenCluster` contains one queen, positioned separately from the other clusters. The queen remains in the `idle` state and scatters within 10 pixels of her idle anchor.
- `WorkerCluster` contains 10 workers. The first worker leads; the others follow in emission order. Workers use the existing startup idle, destination walking, food seeking, and idle-at-food behavior. They pause in `idle` for 3 seconds before their first trip and between destinations.
- `WarriorCluster` contains three warriors. Its leader repeatedly scouts random destinations within `warrior_scout_range` (default 32 pixels) of the warrior cluster center, and the other warriors follow. Warriors use `walking` while scouting and pause in `idle` between destinations.
- Cluster containers are separate children of `AntSource`; queen and warrior clusters have their own scene offsets.

## Idle pause between destinations

- Mobile ants remain in `idle` for `idle_pause_duration` (default 3 seconds) before starting their initial trip and after reaching each destination. Each ant scatters within 10 pixels of its idle anchor.
- Warriors pause between scouting points, then continue scouting within their cluster range.
- Workers pause before searching again after a scout point. At a food source, they remain idle after the pause while gathering behavior is still undefined.
- The queen stays idle at all times and scatters within her 10-pixel idle range.

## Main scene composition

- `MainScene.tscn` disables worker and warrior spawning on its `AntSource` instance, so the main scene shows only the queen. The reusable `AntSource` defaults still allow both clusters to spawn when enabled on other instances.

## Global food amount

- `GameState` is registered as an autoload in `project.godot`; `scripts/game_state.gd` owns the global integer `food_amount`, initially 0.
- Use `GameState.add_food(amount)` to add positive amounts, or `GameState.spend_food(amount)` to deduct food when enough is available. `spend_food` reports success as a boolean. The counter is clamped at zero.
- `food_changed(amount)` notifies listeners after assignments; the main scene's text label listens and shows `Food: <amount>` at the bottom of the viewport.
- This shared counter is implemented, but food source nodes, worker gathering, and automatic food production remain deferred.

## Worker group capacity and purchases

- Worker purchases cost 100 food and are tracked in worker groups with a maximum of 100 ants per group.
- When the current group reaches capacity, the next successful purchase starts a new group. The buy button is disabled when food is below 100, and purchasing is rejected without deducting food if the balance is insufficient.

## Local game saves

- `GameState` persists a JSON snapshot to `user://game_state.json`, which is in Godot's per-user application data directory.
- Pressing the worker purchase button saves `update_time` (Unix time), `food_amount`, `queen_amount`, `worker_amount`, and `warrior_amount` after the purchase attempt.
- At startup, a valid snapshot restores the food balance and ant counts. When no snapshot exists, `AntSource` uses its scene spawn settings and default counts.
- Saving is currently triggered by the worker button; other gameplay changes are not written until that button is pressed.
