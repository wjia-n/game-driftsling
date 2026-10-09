import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driftsling/engine/drift_engine.dart';

/// Engine state-machine tests for Drift Sling.
///
/// The engine owns ALL phases; the UI only renders. These tests cover the
/// countdown → aiming → flying flow, launch validation, checkpoint/coin
/// scoring, relaunch-after-stall, the watchdog, and run completion —
/// without needing timers or widgets.
DriftEngine _engine({DriftMode mode = DriftMode.trial}) {
  final e = DriftEngine(mode: mode, circuit: 0, difficulty: 0);
  addTearDown(e.dispose);
  e.setArena(const Size(400, 600));
  e.debugSkipCountdown();
  return e;
}

void main() {
  test('countdown skip lands in aiming with the pull hint', () {
    final e = _engine();
    expect(e.phase, DriftPhase.aiming);
    expect(e.banner, contains('Pull back'));
  });

  test('a strong pull launches the car into flying', () {
    final e = _engine();
    final events = <DriftEvent>[];
    e.onEvent = events.add;
    e.pressAt(e.pos);
    e.moveAt(e.pos + const Offset(-100, 0));
    e.release();
    expect(e.phase, DriftPhase.flying);
    expect(e.vel.distance, greaterThan(24));
    expect(events, contains(DriftEvent.launch));
  });

  test('a weak pull is rejected as invalid and stays aiming', () {
    final e = _engine();
    final events = <DriftEvent>[];
    e.onEvent = events.add;
    e.pressAt(e.pos);
    e.moveAt(e.pos + const Offset(-10, 0));
    e.release();
    expect(e.phase, DriftPhase.aiming);
    expect(e.vel.distance, 0);
    expect(events, contains(DriftEvent.invalid));
  });

  test('pressing far from the car while aiming is invalid', () {
    final e = _engine();
    final events = <DriftEvent>[];
    e.onEvent = events.add;
    e.pressAt(e.pos + const Offset(200, 200));
    expect(events, contains(DriftEvent.invalid));
  });

  test('passing the next checkpoint scores and advances', () {
    final e = _engine();
    e.debugForceFlying();
    final before = e.score;
    e.debugTeleport(e.pts[e.cps[e.nextCp % 8]]);
    e.step(1 / 60);
    expect(e.nextCp, 2);
    expect(e.score, before + 25);
  });

  test('collecting a coin scores +50 exactly once', () {
    final e = _engine();
    e.debugForceFlying();
    e.debugTeleport(e.coinPts[0]);
    e.step(1 / 60);
    expect(e.coins, 1);
    final afterFirst = e.score;
    e.step(1 / 60); // still sitting on the taken coin
    expect(e.coins, 1);
    expect(e.score, afterFirst); // no double-collect
  });

  test('a stalled car can always be relaunched', () {
    final e = _engine();
    e.debugForceFlying();
    e.vel = const Offset(10, 0); // crawling
    expect(e.canPull, isTrue);
    e.pressAt(e.pos);
    e.moveAt(e.pos + const Offset(-120, 0));
    e.release();
    expect(e.vel.distance, greaterThan(60));
  });

  test('watchdog recovers a settling phase with no live timer', () {
    final e = _engine();
    e.debugForceFlying();
    e.phase = DriftPhase.settling; // simulate a died timer
    e.debugRecover();
    expect(e.phase, DriftPhase.flying);
  });

  test('trial finish after 2 laps ends the run as a win', () {
    final e = _engine();
    e.debugForceFlying();
    e.lap = 2;
    e.nextCp = 7;
    e.debugTeleport(e.pts[e.cps[7]]);
    e.step(1 / 60);
    expect(e.over, isTrue);
    expect(e.won, isTrue);
    expect(e.phase, DriftPhase.over);
    expect(e.finishMs, isNotNull);
  });

  test('attack mode ends at zero with won == false', () {
    final e = _engine(mode: DriftMode.attack);
    e.debugForceFlying();
    e.timeLeft = 0.05;
    e.step(0.1);
    expect(e.over, isTrue);
    expect(e.won, isFalse);
  });

  test('quitToMenu ends a cruise run without win or loss', () {
    final e = _engine(mode: DriftMode.cruise);
    e.debugForceFlying();
    e.quitToMenu();
    expect(e.over, isTrue);
    expect(e.won, isNull);
  });

  test('restart resets the run to countdown', () {
    final e = _engine();
    e.debugForceFlying();
    e.restart();
    expect(e.over, isFalse);
    expect(e.phase, DriftPhase.countdown);
    expect(e.score, 0);
    expect(e.coins, 0);
  });
}
