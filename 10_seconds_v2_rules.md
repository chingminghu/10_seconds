# 10 Seconds — Manual Recording Rules (V2 Draft)

This document specifies the parallel V2 rules implemented by
`res://scripts/v2/run_controller_v2.gd`. The current Anchor-to-Anchor version
remains unchanged.

## Core flow

- Player movement remains enabled during normal play.
- The configured Anchor is only the Player's initial and reset spawn point.
- Touching an active Orb requests its configured recording charge amount.
- A charge request succeeds only while unspent charges are below capacity. A
  blocked Orb remains active and is not consumed.
- A renewable Orb becomes active again after `renewable_time`; a non-renewable
  Orb remains consumed until a full reset.
- A level has a fixed recording queue capacity. The default is one.
- An Orb is not consumed when charges are already at the configured maximum;
  touching it again after spending a charge can claim it.
- J starts recording. Starting consumes one charge and immediately pushes the
  in-progress Segment to the back of the fixed-size queue.
- J during recording requests a stop. If no later physics sample exists yet,
  recording stops after the next sample so the Segment remains valid.
- Recording automatically stops at 10 seconds by default.
- K pops the oldest completed Segment from the front of the queue and plays it
  backward as an Echo.
- An unfinished front Segment cannot be played.
- At most one Echo plays at a time.
- Recording and Echo playback may overlap when the queue contains an older,
  completed Segment.
- R performs a full reset: current recording, Echo, queue, Anchor claims,
  charges, player transform, and resettable level objects return to their
  initial level state.
- E and Q have no V2 behavior.

## Capacity and charges

`recording_capacity` controls both the fixed queue size and the maximum number
of unspent recording charges. `starting_recording_charges` defaults to zero;
Orbs supply recording charges during play. A level may choose a non-zero
starting value when explicitly required.

Stored queue elements and unspent charges are tracked separately. This allows
an Anchor to grant a future charge while an older recording is still stored,
but the queue must have free space before J can begin another recording.

## Input compatibility

V2 responds directly to physical J, K, and R keys without changing
`project.godot`. It also supports optional InputMap actions:

```text
record_v2     J
playback_v2   K
retry_current R (existing fallback action)
```

## Scene integration

Create a new level scene or duplicate an existing one, remove/disable the old
`RunController`, and instantiate `res://scenes/v2/run_controller_v2.tscn`.
Assign:

```text
player
spawn_anchor
orbs_root
goal
recording_controller
echo_scene
echo_container
snapshot_controller
```

The Anchor is not connected to gameplay signals in V2; it only provides
`get_spawn_transform()`. Orbs are collected recursively from `orbs_root` and
request a charge through their `touch_requested` signal. RunControllerV2 calls
`Orb.touched()` only after confirming charge capacity is available.

## UI signals

The V2 controller exposes signals for charge changes, queue changes, recording
start/finish/rejection, playback start/finish/rejection, Orb grants/blocks,
reset, and level completion. A V2 HUD should display at minimum:

```text
Charges: available / maximum
Queue: stored / capacity
REC time: elapsed / maximum
J: record or stop
K: play oldest recording
R: reset all
```
