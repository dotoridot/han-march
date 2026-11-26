const assert = require("node:assert/strict");
const test = require("node:test");
const Game = require("../game.js");

const idle = { x: 0, y: 0 };

function step(run, seconds, input = idle) {
  for (let i = 0; i < seconds * 50; i++) Game.tick(run, 0.02, input);
}

function afterDefense() {
  const run = Game.start([]);
  step(run, 7.1);
  run.wave = 4;
  run.next = Infinity;
  run.foes.length = 0;
  run.wounds.forEach((wound, index) => { wound.state = index === 0 ? "saved" : "lost"; });
  Game.tick(run, 0.02, idle);
  assert.equal(run.phase, "camp");
  return run;
}

test("18면의 경계, 항우 한 면, 한 번만 등용", () => {
  const ids = Array.from({ length: 18 }, (_, index) => Game.resultForFace(index + 1));
  for (const { id, faces } of Game.odds) assert.equal(ids.filter((result) => result === id).length, faces);
  assert.equal(ids.at(-1), "xiang");
  const run = afterDefense();
  assert.deepEqual(Game.roll(run, () => 0.999), { face: 18, id: "xiang", duplicate: false });
  assert.equal(Game.roll(run, () => 0), null);
  assert.deepEqual(run.party.map((u) => u.id), ["liu", "fan", "xiao", "xiang"]);
  assert.ok(run.records.has("xiang"));
});

test("중복 등용은 편성을 유지하고 고른 숨을 해금하며 특기를 한 번만 적용", () => {
  const run = afterDefense();
  assert.equal(Game.give(run, "fan", "breath"), false);
  assert.deepEqual(Game.roll(run, () => 0), { face: 1, id: "fan", duplicate: true });
  assert.equal(run.party.length, 3);
  assert.equal(Game.give(run, "fan", "breath"), true);
  assert.equal(Game.give(run, "liu", "guard"), false);
  assert.equal(run.party[1].trait, "breath");
  assert.equal(run.party[0].trait, null);
  assert.ok(Game.depart(run));
  assert.equal(run.party[1].trait, "breath");
});

test("움직임, 공격 방향, 피격, 피로와 집결 신호", () => {
  const run = Game.start([]);
  run.next = Infinity;
  run.party[1].cd = 5;
  const player = run.party[0];
  step(run, 0.25, { ...idle, x: -1 });
  assert.ok(player.x < 220);
  const enemy = {
    id: "qin", x: player.x + 26, y: player.y, hp: 55, max: 55, face: 0,
    fatigue: 0, morale: 72, cd: 4, wind: 0, hit: 0, swing: 0, stride: 0,
  };
  run.foes.push(enemy);
  Game.tick(run, 0.02, { ...idle, aim: { x: player.x - 30, y: player.y }, attack: true });
  assert.equal(enemy.hp, 55);
  assert.ok(player.fatigue > 0);
  step(run, 0.7);
  Game.tick(run, 0.02, { ...idle, aim: enemy, attack: true });
  assert.ok(enemy.hp < 55);
  assert.ok(enemy.hit > 0);
  const morale = player.morale;
  Game.tick(run, 0.02, { ...idle, rally: true });
  assert.ok(player.morale > morale);
  assert.equal(player.fatigue, 0);
  assert.ok(run.rallyCD > 0);
  const rallyTime = run.rallyCD;
  Game.tick(run, 0.02, { ...idle, rally: true });
  assert.ok(run.rallyCD < rallyTime);
});

test("구조 시간과 결과, 야영지 약 대상 한 명", () => {
  const run = Game.start([]);
  run.next = Infinity;
  const player = run.party[0];
  const [first, second, third] = run.wounds;
  Object.assign(player, { x: first.x, y: first.y });
  step(run, 1.4, { ...idle, hold: true });
  assert.equal(first.state, "saved");
  assert.ok(run.records.has("rescue"));
  second.deadline = 2;
  second.state = "waiting";
  step(run, 6.5);
  assert.equal(second.state, "lost");
  run.party[1].hp = 0;
  run.wave = 4;
  third.state = "lost";
  Game.tick(run, 0.02, idle);
  assert.deepEqual(run.defenseResult, { saved: 1, lost: 2, fallen: ["번쾌"] });
  assert.equal(Game.heal(run, "fan"), true);
  assert.equal(run.party[1].hp, 68);
  assert.equal(Game.heal(run, "liu"), false);
});

test("구조 보상은 위험이 사라진 뒤 성문 보강에 쓴다", () => {
  const run = Game.start([]);
  run.next = Infinity;
  const player = run.party[0];
  Object.assign(player, { x: run.wounds[0].x, y: run.wounds[0].y });
  step(run, 1.4, { ...idle, hold: true });
  assert.equal(run.repairs, 1);
  run.gate = 54;
  Object.assign(player, Game.points.gate);
  step(run, 1.7, { ...idle, hold: true });
  assert.equal(run.gate, 78);
  assert.equal(run.repairs, 0);
});

test("번쾌와 항우는 체력 및 피로에 따라 추적을 줄이고 대열로 돌아온다", () => {
  const run = afterDefense();
  Game.roll(run, () => 0.999);
  Game.depart(run);
  const [player, fan, , xiang] = run.party;
  const enemy = run.foes[0];
  Object.assign(enemy, { x: player.x + 46, y: player.y, cd: 10 });
  run.foes = [enemy];
  Game.tick(run, 0.02, idle);
  assert.equal(fan.status, "유방 호위");
  assert.equal(xiang.status, "적 대열 돌파");
  assert.equal(Game.aimTarget(run), enemy);
  fan.hp = 30;
  xiang.fatigue = 92;
  Game.tick(run, 0.02, idle);
  assert.equal(fan.status, "체력 저하로 추적 축소");
  assert.equal(xiang.status, "피로로 대열 복귀");
});

test("소하는 지혈, 동료 응급 처치와 위험 시 복귀를 한다", () => {
  const run = Game.start([]);
  run.next = Infinity;
  step(run, 7.1);
  const [player, , xiao] = run.party;
  const wound = run.wounds[0];
  Object.assign(player, { x: wound.x + 20, y: wound.y });
  Object.assign(xiao, { x: wound.x + 10, y: wound.y });
  const until = wound.deadline;
  Game.tick(run, 0.02, idle);
  assert.equal(wound.deadline, until + 28);
  assert.equal(xiao.status, "부상자 지혈");
  player.hp -= 30;
  const hurt = player.hp;
  Game.tick(run, 0.02, idle);
  assert.equal(player.hp, hurt + 13);
  xiao.hp = 20;
  Game.tick(run, 0.02, idle);
  assert.equal(xiao.status, "위험 감지, 유방에게 이동");
});

test("정면은 지원과 사기를, 측문은 순찰 지연을 적용", () => {
  for (const route of ["front", "side"]) {
    const run = afterDefense();
    Game.give(run, "fan", "guard");
    Game.depart(run);
    const player = run.party[0];
    const garrison = run.foes.find((u) => u.id === "captain");
    const before = garrison.hp;
    run.foes = run.foes.filter((enemy) => enemy.y < 109);
    Object.assign(player, Game.points[route]);
    const initial = player.morale;
    step(run, 2.6, { ...idle, hold: true });
    assert.equal(run.route, route);
    assert.ok(run.records.has(route));
    assert.equal(garrison.hp, route === "front" ? before - 21 : before);
    assert.equal(player.morale, route === "front" ? Math.min(initial + 20, 100) : initial);
    if (route === "side") assert.ok(run.next >= 35);
    assert.equal(Game.barriers(run).some((block) => block.x === (route === "front" ? 208 : 383)), false);
  }
});

test("군량고의 적을 정리해야 승리하고 패배 뒤 발견만 유지", () => {
  const run = afterDefense();
  Game.give(run, "fan", "guard");
  Game.depart(run);
  Object.assign(run.party[0], Game.points.front);
  run.foes = run.foes.filter((enemy) => enemy.id === "captain");
  step(run, 2.6, { ...idle, hold: true });
  Object.assign(run.party[0], Game.points.supply);
  step(run, 2.3, { ...idle, hold: true });
  assert.equal(run.phase, "assault");
  run.foes = [];
  step(run, 2.3, { ...idle, hold: true });
  assert.ok(run.loading);
  assert.equal(run.phase, "assault");
  run.loading.patrol = 6;
  run.foes = [];
  step(run, 106, idle);
  assert.equal(run.phase, "won");

  const next = Game.start(run.records);
  next.gate = 0;
  Game.tick(next, 0.02, idle);
  assert.equal(next.phase, "lost");
  const restarted = Game.start(next.records);
  assert.ok(restarted.records.has("lose") && restarted.records.has("win"));
  assert.deepEqual(restarted.party.map((u) => [u.id, u.trait]), [["liu", null], ["fan", null]]);
  assert.equal(restarted.rolled, null);
  assert.equal(restarted.gift, null);
});
