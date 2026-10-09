# Drift Sling — Rules

The authoritative source of truth for Drift Sling gameplay. If the
implementation conflicts with this document, fix the implementation.

## 1. Objective

Slingshot-launch your die-cast toy car around the playroom-table circuit
and finish as the fastest, flashiest driver.

- **Time Trial:** complete 2 laps in the shortest time. Drifts and coins add
  bonus score on top.
- **Drift Attack:** in 75 seconds, score as many points as possible by
  drifting and grabbing coins.
- **Free Cruise:** no clock, no finish line — drift for pure joy; quitting
  banks the score.

## 2. Setup

1. The player picks a mode (Time Trial / Drift Attack / Free Cruise), a
   difficulty (Sunday Cruise / Track Racer / Champion), and a circuit
   (Sunny Speedway / Wiggly Circuit / Spaghetti Bowl).
2. The car is placed on the start/finish line, pointing along the track.
3. A 3-2-1-GO countdown runs (engine-owned timers), then the player aims.
4. 8 checkpoints are placed evenly around the loop; 12 coins are scattered
   on the road.

## 3. Turn order

Drift Sling is a single-player real-time game; there are no turns.
Play proceeds through engine-owned phases:

1. `countdown` → 2. `aiming` → 3. `flying` ⇄ (brief `settling` on laps) →
   4. `over`.

## 4. Legal moves

- **Pull & release:** press on (or near) the car, drag backwards, and release.
  A pull longer than 24 px launches the car; launch speed scales with pull
  length, capped at 1500 px/s (× difficulty speed factor).
- **Steer:** while the car is rolling, drag anywhere — the car accelerates
  toward the finger.
- **Relaunch:** whenever the car is crawling (< 60 px/s) the player may pull
  back on the car again to relaunch it. A stalled car is never stuck.
- **Drift:** at speed, steering so the car's velocity points away from its
  nose (> 0.38 rad) starts a drift. Drifting lays skid marks and builds a
  chain meter.

## 5. Illegal moves

- Pulls shorter than 24 px are ignored (invalid-move sound, no launch).
- Pressing far from the car while aiming does nothing (invalid sound).
- Pulling on the car while it is moving fast does nothing — steering only.
- No input is accepted during `countdown`, `settling`, or `over`, or while
  paused.

## 6. Captures

Not applicable — there are no opponents or pieces to capture.

## 7. Special rules

- **Checkpoints:** the 8 checkpoints must be passed IN ORDER. Passing one
  scores +25 and plays a chime; the next checkpoint flag pulses ahead.
- **Laps:** passing checkpoint 8 completes a lap (+100, fanfare, brief
  banner pause). Time Trial ends after 2 laps.
- **Drift chains:** while drifting, the chain meter fills; each filled level
  (×difficulty need) raises the chain (x1, x2, …) and immediately scores
  chain × 25 with a popup and sparkle sound. When the drift ends, a chain
  bonus of chain × 50 is banked with a visible popup.
- **Coins:** driving within 34 px of a coin collects it (+50, ding). Coins do
  not respawn within a run.
- **Off-road:** leaving the painted road applies heavy extra drag (scales
  with difficulty). Slamming off-road above 950 px/s causes a CRASH: speed
  is cut to 25%, a thud plays, and a "CRASH!" popup shows.
- **Stall prompt:** crawling below 60 px/s for 6+ seconds shows the
  "Stalled? Pull back on the car!" hint — the car can always be relaunched.
- **Drift Attack clock:** 75 seconds, counted down by the engine; at zero the
  run ends (not a win).
- **Free Cruise:** no clock; the run ends when the player quits from pause.

## 8. Scoring

- Checkpoint: +25. Lap: +100. Coin: +50.
- Drift chain level-up: chain × 25 (immediate). Drift end: chain × 50 banked.
- Time Trial finish bonus: max(0, (180000 − finishMs) / 100).
- Best score, most coins, and best time-trial time per circuit/difficulty
  are persisted as garage records.

## 9. Winning conditions

- **Time Trial:** finishing 2 laps = a win; a new best time is celebrated.
- **Drift Attack:** there is no win — the run simply ends at 0:00; a new
  best score is celebrated.
- **Free Cruise:** quitting banks the score; never a win or loss.

## 10. Draw conditions

Not applicable — single-player game.

## 11. AI strategy

Not applicable — no opponents or bots. Difficulty tiers scale the physics
instead: Sunday Cruise (wide road, gentle off-road drag, slower top speed),
Track Racer (standard), Champion (narrow road, harsh off-road drag, faster
top speed, slower chain fill). Champion is a PRO feature.

## 12. Edge cases

- App backgrounded mid-run: the engine pauses (phase timer frozen) and
  audio pauses; resume restores exactly.
- Screen rotated/resized mid-run: the track rescales proportionally; the
  car keeps its relative position — the run is never reset.
- Watchdog: any phase found without a live timer is recovered (countdown
  continues, settling completes). `aiming`/`flying` are input-driven and
  cannot deadlock — the car is always relaunchable when slow.
- Pull released exactly at 24 px: treated as invalid (< 24 px required to
  be strictly greater).
- Coin and checkpoint both in range on the same frame: both score; popups
  stack.

## 13. Test cases

1. Profile name round-trips through the single JSON key in exact form;
   corrupt/missing data falls back to "Speedster".
2. Legacy `drift_player_name` key migrates once, then is removed.
3. Countdown ticks 3→2→1→GO and lands in `aiming` with the pull hint.
4. A 100 px pull launches the car and enters `flying` (launch event fired).
5. A 10 px pull is rejected (invalid event, still `aiming`).
6. Driving through the next checkpoint scores +25 and advances the
   checkpoint index; checkpoints out of order do not score.
7. Collecting a coin scores +50 and marks it taken (no double-collect).
8. A slow car (< 60 px/s) accepts a relaunch pull.
9. Watchdog recovers a `settling` phase with no live timer.
10. Trial finish after 2 laps sets `over`, records finish time, and applies
    the time bonus.
11. Attack mode ends at 0:00 with `won == false`.
12. Free (non-Pro) settings clamp Champion difficulty and Pro-only
    themes/car/track styles back to free defaults.
