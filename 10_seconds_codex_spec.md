# 10 Seconds

Godot implementation specification for an AI coding agent

## 1. Document purpose

This document defines the gameplay rules, technical architecture, data model, scene structure, and implementation milestones for **10 Seconds**, a single-screen 2D platform puzzle game built with **Godot 4.x**.

The intended reader is Codex or another coding agent working directly in the repository. Treat the rules in this document as the current source of truth. When a detail is not explicitly defined, prefer the simplest implementation that preserves deterministic playback and makes the core mechanic easy to test.

## 2. High-level concept

**10 Seconds** is a 2D platform puzzle game based on recording and rewinding the player's previous movement.

Each level contains multiple ordered **Anchors** and one final goal. The entire level is visible on one fixed screen; the camera does not scroll.

The player travels from one Anchor to the next. Each Anchor-to-Anchor traversal is recorded. During the next traversal, the immediately previous recording is played backward as an interactive **Echo**, while the player's new traversal is recorded.

Example:

```text
Anchor A -> Anchor B
- Record Segment 1

Anchor B -> Anchor C
- Play Segment 1 backward as an Echo: B -> A
- Record Segment 2

Anchor C -> Anchor D
- Play Segment 2 backward as an Echo: C -> B
- Record Segment 3

Anchor D -> Goal
- Play Segment 3 backward as an Echo: D -> C
```

Only the most recently completed recording is replayed. There is never more than one Echo active at a time.

The key idea is:

> Use the previous recording to solve the current obstacle while recording actions that will help solve the next one.

## 3. Game Jam theme interpretation

The theme is **Count Down**.

It is represented in two ways:

1. Each traversal has a maximum recording duration of **10 seconds**.
2. The previous traversal is played backward, visually and mechanically resembling a videotape rewind.

When the 10-second timer reaches zero before the player reaches the required next Anchor, the current attempt fails and resets.

## 4. Core terminology

### Anchor

An Anchor replaces the conventional term "checkpoint".

An Anchor is a fixed temporal and spatial boundary between recordings. It serves as:

- the start point of the next recording;
- the end point of the current recording;
- the spawn point of the backward-playing Echo;
- a safe planning state before movement begins;
- a point to which the player may return when retrying.

Anchors are ordered. By default, the player must reach them in the sequence defined by the level.

### Segment

A Segment is one successful recording between two consecutive Anchors.

A Segment contains time-sampled player state required to reproduce the traversal backward.

### Echo

The Echo is an interactive replay of the immediately previous Segment, played in reverse chronological order.

The Echo:

- begins at the player's current Anchor;
- retraces the previous Segment toward the preceding Anchor;
- has a fixed trajectory that cannot be changed;
- can physically interact with the player and selected level objects;
- disappears or becomes inactive when playback reaches the beginning of the Segment.

### Goal

The Goal is the final destination. Reaching it completes the level. It may behave similarly to the final Anchor for arrival detection, but it does not begin another recording.

## 5. Authoritative gameplay rules

### 5.1 Fixed-screen level

- Each level must fit within one screen.
- The camera must remain fixed during normal gameplay.
- All Anchors, the Goal, major terrain, and relevant puzzle mechanisms should be visible from the start.
- The player should be able to inspect future traversal areas before recording the current Segment.

### 5.2 Planning state at an Anchor

When the player arrives at an Anchor, the game enters an **ANCHOR_READY** state.

While in this state:

- player movement is disabled;
- the countdown is stopped;
- no new recording is being written;
- the previous Segment is not yet playing;
- a Play/Record prompt is shown;
- the player may inspect the full screen and plan the next route.

The player must explicitly press the Play/Record action to begin.

### 5.3 Starting a traversal

When Play/Record is pressed at the current Anchor:

- player movement becomes enabled;
- the 10-second countdown starts;
- a new Segment starts recording;
- the previously completed Segment, if one exists, starts playing backward as the Echo;
- the game enters the **RECORDING** state.

The first traversal from the starting Anchor has no Echo because no previous Segment exists.

### 5.4 Successful arrival

A traversal succeeds only when the player reaches the specifically expected next Anchor before time expires.

On success:

- stop recording;
- store the current Segment as the new previous Segment;
- stop and remove the current Echo;
- update the current Anchor to the newly reached Anchor;
- enter ANCHOR_READY;
- prevent player movement until Play/Record is pressed again.

Touching a non-target Anchor should not complete the current Segment unless a level explicitly enables a non-linear route. The initial implementation should use a linear ordered Anchor sequence.

### 5.5 Timeout failure

If the countdown reaches zero before the player reaches the expected next Anchor:

- mark the current attempt as failed;
- discard the incomplete current recording;
- stop and remove the active Echo;
- reset transient level objects to their state at the beginning of the attempt;
- return the player to the Anchor where the attempt began;
- preserve the previously completed Segment;
- enter ANCHOR_READY.

This lets the player retry the same current traversal using the same previous Echo.

### 5.6 Manual retry of the current traversal

Provide a **Retry Current Anchor** action during recording.

It behaves like timeout failure:

- discard the incomplete recording;
- reset the attempt;
- return to the current Anchor;
- preserve the previously completed Segment.

### 5.7 Return to the previous Anchor for re-recording

Provide a separate **Return to Previous Anchor** action.

This action is needed when the player realizes that the previous successful Segment was recorded poorly and cannot solve the current puzzle.

Expected behavior:

- leave the current Anchor and return to the immediately previous Anchor;
- delete the Segment that ended at the current Anchor;
- restore the earlier Segment that should act as the Echo during the re-recording attempt, if such a Segment exists;
- restore the level to the appropriate snapshot for that Anchor;
- enter ANCHOR_READY at the previous Anchor.

Because only one Echo is normally active, implementation should still retain enough Segment history to support stepping back by at least one Anchor. The safest initial design is to maintain a stack of completed Segment records for the current level.

### 5.8 Echo trajectory is immutable

The Echo's recorded movement is completely immutable.

The following must never alter the Echo's playback position or timing:

- collision with the player;
- collision with crates;
- moving platforms;
- enemies;
- forces or impulses;
- being pushed;
- gravity simulation;
- level geometry changes.

The Echo must follow its recorded transform exactly, even if this causes it to overlap or push other physics bodies.

In implementation terms, the Echo is not a normal dynamically simulated character. Its transform is driven directly from recorded samples. Its collision body participates in collision detection, but external physics must not modify its transform.

### 5.9 Echo interaction

The Echo is physically interactive.

Required interactions:

- the player can stand on top of the Echo;
- the player can use the Echo as a temporary moving platform;
- the Echo can push the player because its own trajectory cannot be changed;
- the Echo can activate pressure plates;
- the Echo can trigger compatible mechanisms.

Potential later interactions:

- pushing crates;
- blocking projectiles or lasers;
- carrying or moving objects;
- activating switches;
- interacting with moving platforms.

The first prototype should prioritize standing on the Echo, being pushed by it, and pressure-plate activation.

### 5.10 Echo lifetime

When backward playback reaches the first recorded sample:

- stop playback;
- disable the Echo's collision;
- hide or dissolve the Echo;
- play a brief rewind-complete visual/audio cue if available.

The Echo must not loop.

### 5.11 Recording duration

Default maximum Segment duration:

```text
10.0 seconds
```

This value should be exported/configurable per level or globally, but the default and game title remain 10 seconds.

The timer should be visible during recording and count down continuously from 10.0 to 0.0.

## 6. Input actions

Define these actions in `project.godot`:

```text
move_left
move_right
jump
play_record
retry_current
return_previous_anchor
pause
```

Suggested default keyboard bindings:

```text
move_left: A / Left Arrow
move_right: D / Right Arrow
jump: Space
play_record: Enter / E
retry_current: R
return_previous_anchor: Backspace / Q
pause: Escape
```

Bindings should remain configurable.

## 7. Player behavior

Use a `CharacterBody2D` for the player.

Minimum movement features:

- horizontal acceleration or direct horizontal speed;
- gravity;
- floor detection;
- jump;
- optional coyote time;
- optional jump buffering;
- disabled movement in ANCHOR_READY and transition states.

For a Game Jam prototype, prioritize predictable movement over advanced platforming physics.

Suggested initial values, subject to tuning:

```text
move_speed = 220 px/s
jump_velocity = -420 px/s
gravity = 1200 px/s^2
coyote_time = 0.10 s
jump_buffer = 0.10 s
```

Do not tie recording to raw input only. Record resulting player state so Echo playback remains deterministic even if physics tuning later changes.

## 8. Recording model

### 8.1 What to record

At a fixed sampling interval, record at minimum:

```gdscript
class_name RecordedFrame

var timestamp: float
var global_position: Vector2
var rotation: float
var facing_direction: int
var animation_name: StringName
var animation_position: float
```

Optional fields:

```text
velocity
is_on_floor
sprite frame
interaction flags
event markers
```

The authoritative data for Echo motion is the recorded transform, not reconstructed input.

### 8.2 Sampling

Recommended prototype approach:

- sample in `_physics_process`;
- one frame per physics tick;
- store elapsed time and transform;
- playback in reverse using the same physics tick rate or timestamp interpolation.

For smoother and more robust playback, support interpolation between adjacent recorded frames based on playback time.

### 8.3 Segment data

Suggested resource/data shape:

```gdscript
class_name RecordedSegment
extends Resource

@export var start_anchor_id: StringName
@export var end_anchor_id: StringName
@export var duration: float
var frames: Array[RecordedFrame] = []
var events: Array[RecordedEvent] = []
```

Segments exist only for the current run and do not initially need to be serialized to disk.

### 8.4 Recording interactive events

For the first prototype, the Echo's body overlap should activate pressure plates directly during playback. No event recording is needed for simple overlap-based mechanisms.

For interactions whose backward behavior cannot be derived from collision alone, introduce timestamped recorded events later.

Avoid building a generalized event-reversal system until the core movement loop is proven.

## 9. Echo implementation

Use an `AnimatableBody2D` or another kinematic body whose transform is controlled directly.

Recommended structure:

```text
Echo (AnimatableBody2D)
├── CollisionShape2D
├── AnimatedSprite2D
├── InteractionArea2D
└── PlaybackController
```

Playback rules:

- initialize at the final frame of the previous Segment;
- set playback time to Segment duration;
- decrement playback time while the game is recording;
- evaluate the recorded transform at the current playback time;
- apply the transform directly;
- use a motion-aware movement method if needed so the physics engine can push the player;
- ignore forces that attempt to change the Echo's path.

Potential Godot approaches to test:

1. Drive `AnimatableBody2D.global_position` each physics frame and enable sync-to-physics behavior.
2. Use a `CharacterBody2D` but overwrite its position from the recording after collision queries.
3. Use a custom collision sweep between the previous and next recorded transforms to push overlapping bodies.

Prefer the simplest method that reliably allows the player to stand on and be pushed by the Echo without changing Echo playback.

## 10. Level state and reset model

Because attempts can be retried and prior Anchors can be revisited, each traversal must have a reliable reset state.

### 10.1 Attempt snapshot

At the start of each traversal, capture an **Attempt Snapshot** containing the state of resettable objects.

Each resettable object should implement a common contract, for example:

```gdscript
class_name Resettable
extends Node

func capture_state() -> Variant:
	return null

func restore_state(state: Variant) -> void:
	pass
```

Objects that may need snapshots:

- crates;
- doors;
- pressure plates;
- switches;
- moving platforms;
- hazards;
- breakable objects.

### 10.2 Anchor snapshots

To support Return to Previous Anchor, preserve a level snapshot for each reached Anchor or preserve enough deterministic state to restore it.

A practical design:

```text
AnchorProgressEntry
- anchor_id
- player_spawn_transform
- completed_segment_before_this_anchor
- level_snapshot_at_anchor
```

Maintain a stack of these entries.

### 10.3 First prototype simplification

For the earliest prototype, use mechanisms that automatically return to a neutral state when the Echo disappears or reload the current level scene on rollback, then reconstruct progress from retained Segment data.

However, scene reload must not lose the recording history needed to replay or re-record earlier Segments. Store run state in a separate `GameSession` node or autoload.

## 11. State machine

Implement a clear game-flow state machine.

Suggested states:

```gdscript
enum RunState {
	ANCHOR_READY,
	COUNT_IN,
	RECORDING,
	ARRIVAL_TRANSITION,
	ATTEMPT_FAILED,
	ROLLING_BACK,
	LEVEL_COMPLETE,
	PAUSED,
}
```

Minimum required transitions:

```text
ANCHOR_READY
  --play_record--> RECORDING

RECORDING
  --target anchor reached--> ARRIVAL_TRANSITION
  --timer expired--> ATTEMPT_FAILED
  --retry_current--> ATTEMPT_FAILED
  --return_previous_anchor--> ROLLING_BACK

ARRIVAL_TRANSITION
  --> ANCHOR_READY

ATTEMPT_FAILED
  --> ANCHOR_READY at same Anchor

ROLLING_BACK
  --> ANCHOR_READY at previous Anchor

RECORDING
  --goal reached--> LEVEL_COMPLETE
```

A short 3-2-1 count-in may be added later, but it should be optional. Pressing Play/Record must remain the explicit commitment point.

## 12. Recommended Godot project structure

```text
res://
├── project.godot
├── autoload/
│   └── game_session.gd
├── scenes/
│   ├── main.tscn
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── echo/
│   │   ├── echo.tscn
│   │   └── echo.gd
│   ├── anchor/
│   │   ├── anchor.tscn
│   │   └── anchor.gd
│   ├── goal/
│   │   ├── goal.tscn
│   │   └── goal.gd
│   ├── mechanisms/
│   │   ├── pressure_plate.tscn
│   │   ├── pressure_plate.gd
│   │   ├── door.tscn
│   │   └── door.gd
│   ├── ui/
│   │   ├── hud.tscn
│   │   └── hud.gd
│   └── levels/
│       ├── level_base.gd
│       ├── level_01.tscn
│       └── level_02.tscn
├── scripts/
│   ├── run_controller.gd
│   ├── recording_controller.gd
│   ├── recorded_frame.gd
│   ├── recorded_segment.gd
│   ├── attempt_snapshot.gd
│   └── resettable.gd
├── resources/
│   └── game_config.tres
├── art/
├── audio/
└── tests/
```

## 13. Main scene composition

Suggested level root:

```text
Level (Node2D)
├── StaticGeometry (Node2D / TileMapLayer)
├── Mechanisms (Node2D)
├── Anchors (Node2D)
├── Goal (Area2D)
├── Player (CharacterBody2D)
├── EchoContainer (Node2D)
├── RunController (Node)
├── RecordingController (Node)
├── FixedCamera (Camera2D)
└── HUD (CanvasLayer)
```

`RunController` owns progression and state transitions.

`RecordingController` owns frame capture, Segment creation, and playback timing data.

The Echo scene owns rendering and collision during playback but does not decide game progression.

## 14. Anchor implementation

Suggested scene:

```text
Anchor (Area2D)
├── CollisionShape2D
├── Sprite2D / AnimatedSprite2D
├── Label
└── InteractionIndicator
```

Exported properties:

```gdscript
@export var anchor_id: StringName
@export var order_index: int
@export var player_spawn_offset: Vector2
@export var is_start_anchor: bool = false
```

Responsibilities:

- detect player arrival;
- report arrival to RunController;
- show active/inactive visual state;
- provide a stable spawn transform;
- never independently change progress.

## 15. UI and presentation

### Required HUD

During ANCHOR_READY:

```text
ANCHOR 02
Press [Play/Record]
Return to previous Anchor [Q]
```

During RECORDING:

```text
REC ●
09.8
```

When an Echo is active:

```text
<< REWIND
```

On timeout:

```text
RECORDING FAILED
```

On level completion:

```text
PLAYBACK COMPLETE
```

### Visual direction

The presentation should evoke VHS playback without reducing gameplay readability.

Suggested effects:

- Echo is visually distinct from the player;
- semi-transparent sprite;
- scan lines or slight frame ghosting;
- reversed animation playback when practical;
- VHS-style REC, PLAY, STOP, and REWIND overlays;
- visible countdown timer;
- brief static distortion during state transitions.

Do not apply heavy full-screen distortion that obscures platforms or collisions.

### Audio direction

Suggested cues:

- Play/Record button click;
- tape mechanism start;
- rewind motor while Echo is active;
- countdown warning during final seconds;
- stop/click sound when arriving at an Anchor;
- tape-end sound when Echo playback finishes;
- failure eject or tracking-error sound.

## 16. Collision layers

Define explicit collision layers early.

Suggested layout:

```text
Layer 1: World
Layer 2: Player
Layer 3: Echo
Layer 4: Movable Objects
Layer 5: Mechanism Sensors
Layer 6: Hazards
Layer 7: Anchors and Goal
```

Required behavior:

- Player collides with World, Echo, and Movable Objects.
- Echo collides with World only as needed for contact reporting, but its transform remains authoritative.
- Echo can affect Player and Movable Objects.
- Pressure plates detect Player, Echo, and selected Movable Objects.
- Anchors detect Player only.

Exact masks may be adjusted during prototyping.

## 17. Initial prototype level

Build one single-screen gray-box level with three Anchors and a Goal:

```text
Anchor A -> Anchor B -> Anchor C -> Goal
```

The level must validate these mechanics in order:

### Segment A to B

- simple platform movement;
- teaches Play/Record and 10-second timer;
- no Echo.

### Segment B to C

- requires standing on the backward-moving Echo to reach a higher platform;
- proves the player can ride or jump from the Echo.

### Segment C to Goal

- requires the previous Echo to activate a pressure plate long enough to open a door;
- encourages the player to deliberately pause on a matching location during B to C;
- proves that current actions must prepare the next puzzle.

The complete level should be solvable without precision-perfect movement.

## 18. Development milestones

### Milestone 1: Basic platform controller

- Godot project starts correctly.
- Player can move and jump.
- Fixed camera shows the whole prototype level.
- Player movement can be enabled and disabled.

### Milestone 2: Anchors and run state

- Ordered Anchors are detected.
- Player waits at an Anchor until Play/Record is pressed.
- Reaching the expected next Anchor stops movement.
- Goal completes the level.

### Milestone 3: Timer and failure reset

- 10-second countdown starts with recording.
- Timeout resets to the current Anchor.
- Retry Current works.
- HUD reflects state.

### Milestone 4: Recording and visual Echo

- Player transforms are recorded.
- Previous Segment plays backward.
- Only one Echo exists.
- Echo disappears at the start of the recorded Segment.

### Milestone 5: Echo collision

- Player can stand on Echo.
- Echo can push Player without changing its own trajectory.
- Collision is stable enough for platform puzzles.

### Milestone 6: Pressure plate and door

- Pressure plate detects Echo.
- Door reacts to plate state.
- State resets correctly between attempts.

### Milestone 7: Return to previous Anchor

- Segment history stack is implemented.
- Player can step back one Anchor.
- The discarded Segment can be re-recorded.
- Correct earlier Echo is restored.

### Milestone 8: Game-feel pass

- VHS UI cues.
- Echo visual distinction.
- Audio feedback.
- countdown warnings;
- transitions and polish.

## 19. Test requirements

At minimum, verify the following manually or with GUT/unit tests where practical.

### Recording

- first Segment has no Echo;
- successful Segment stores all frames;
- failed Segment is discarded;
- Segment duration never exceeds configured limit;
- new success replaces the active previous Segment while history remains available for rollback.

### Playback

- Echo starts at the exact ending transform of the previous Segment;
- Echo reaches the exact starting transform;
- playback duration matches recorded duration;
- Echo does not drift across repeated attempts;
- player collision cannot change Echo trajectory;
- pausing the game does not desynchronize playback.

### Progression

- only expected next Anchor completes a Segment;
- player cannot move before Play/Record;
- timeout returns to correct Anchor;
- retry preserves previous Echo;
- return_previous_anchor removes the correct completed Segment;
- reaching Goal completes level.

### Reset

- doors, plates, crates, and hazards return to correct attempt state;
- no duplicate Echo remains after reset;
- timer is reset to 10 seconds;
- input is restored correctly after transitions.

## 20. Non-goals for the first version

Do not implement these until the core prototype is fun and stable:

- multiple simultaneous Echoes;
- branching Anchor routes;
- online multiplayer;
- user-editable recordings;
- arbitrary free-form time rewind;
- full world-state reversal;
- save/load of frame-by-frame recordings;
- complex enemy AI;
- procedural level generation;
- rewindable destructible environments;
- cinematic story systems.

## 21. Coding guidelines for Codex

- Use typed GDScript where practical.
- Prefer small, focused nodes and explicit signals.
- Keep RunController as the authority for state transitions.
- Keep recording data independent from Player implementation.
- Do not make Echo replay depend on current player physics parameters.
- Avoid global singletons except for persistent run/session data that must survive scene reload.
- Expose tuning values with `@export` or a configuration Resource.
- Add concise comments for non-obvious rewind and reset logic.
- Fail loudly in debug builds when Anchor ordering or required node references are invalid.
- Do not silently infer Anchor order from scene-tree order; use explicit `order_index`.
- Keep visual effects separate from authoritative gameplay state.

## 22. Acceptance criteria for the first playable build

The first playable build is complete when a player can:

1. See a full single-screen level containing Anchor A, B, C, and a Goal.
2. Stand at Anchor A and press Play/Record to begin.
3. Reach Anchor B within 10 seconds and save Segment 1.
4. Start from Anchor B while Segment 1 plays backward as an Echo.
5. Stand on or be pushed by the Echo to reach Anchor C.
6. Record Segment 2 in a way that prepares the final puzzle.
7. Start from Anchor C while Segment 2 plays backward.
8. Use the Echo to activate a pressure plate and reach the Goal.
9. Retry a failed current Segment without losing the previous valid Segment.
10. Return to the previous Anchor, delete a bad Segment, and record it again.

## 23. One-sentence pitch

> In ten seconds, reach the next Anchor, then use your journey playing backward to build the path ahead.
