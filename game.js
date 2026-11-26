(() => {
  "use strict";

  const width = 480;
  const height = 288;
  const roster = {
    liu: { name: "유방", hp: 118, speed: 92, damage: 29, reach: 48, color: "#eab354", role: "패현군 지휘" },
    fan: { name: "번쾌", hp: 122, speed: 66, damage: 21, reach: 29, color: "#e59557", role: "근접 호위" },
    xiao: { name: "소하", hp: 76, speed: 60, damage: 9, reach: 23, color: "#aab65e", role: "부상자 지원" },
    xiang: { name: "항우", hp: 137, speed: 81, damage: 39, reach: 38, color: "#d58cae", role: "적 대열 돌파" },
    zhou: { name: "주발", hp: 102, speed: 64, damage: 22, reach: 34, color: "#eeb060", role: "대열 유지" },
    cao: { name: "조참", hp: 90, speed: 74, damage: 24, reach: 34, color: "#8db1cd", role: "기동 지원" },
    qin: { name: "진군 보병", hp: 44, speed: 42, damage: 9, reach: 20, color: "#cdc2a4" },
    pike: { name: "진군 장창병", hp: 62, speed: 38, damage: 15, reach: 34, color: "#df9569" },
    captain: { name: "진군 대장", hp: 113, speed: 40, damage: 21, reach: 32, color: "#ef7864" },
  };
  const odds = [
    { id: "fan", faces: 6 }, { id: "xiao", faces: 5 }, { id: "zhou", faces: 3 },
    { id: "cao", faces: 3 }, { id: "xiang", faces: 1 },
  ];
  const traits = {
    guard: { name: "철벽", detail: "받는 피해 35% 감소" },
    edge: { name: "예봉", detail: "공격 피해 32% 증가" },
    breath: { name: "고른 숨", detail: "피로 회복 속도 70% 증가" },
  };
  const stories = {
    pei: ["패현 성문의 밤", "성문이 닫히자 횃불이 성벽을 타고 번졌다. 유방은 번쾌에게 문 앞을 맡겼다."],
    xiao: ["소하의 명부", "소하는 문서 대신 들것을 들고 유방 곁에 섰다. 성 안의 누구도 장부에서 빠지지 않게 하겠다고 했다."],
    rescue: ["들것의 행렬", "성 안으로 들어오는 들것을 보고 야영지 사람들이 물을 끓였다."],
    lost: ["비어 있는 들것", "야영지에 세운 들것 가운데 끝내 주인을 찾지 못한 것이 있었다."],
    xiang: ["먼저 도착한 항우", "이 이야기에서는 항우가 패현군에 먼저 합류한다. “오중보다 먼저 이 깃발을 봤다. 오늘만은 내가 길을 열지.”"],
    front: ["산등성이의 나팔", "정면의 동료들이 나팔에 응답했다. 유방이 성채 안으로 들어갈 길을 함께 열었다."],
    side: ["마른 도랑의 문", "측문 빗장이 안에서 열렸다. 진군이 정면을 보고 있는 사이 군량고로 들어갔다."],
    win: ["군량고의 새벽", "진군의 봉인이 떨어지고 군량 자루가 피란민에게 건너갔다."],
    lose: ["접힌 깃발", "살아 돌아온 사람들은 이 밤의 일을 기록하고 깃발을 접었다."],
  };
  const points = {
    gate: { x: 240, y: 97 }, front: { x: 238, y: 159 },
    side: { x: 408, y: 130 }, supply: { x: 264, y: 55 },
  };
  const wounds = [
    { x: 151, y: 180, name: "문지기", arrives: 0, deadline: 58 },
    { x: 330, y: 182, name: "짐꾼", arrives: 44, deadline: 102 },
    { x: 240, y: 47, name: "전령", arrives: 100, deadline: 167 },
  ];
  const defenseWaves = [
    [["qin", "qin", "qin"], ["qin", "qin"], ["qin", "pike"]],
    [["qin", "pike", "qin"], ["qin", "pike"], ["qin", "qin", "pike"]],
    [["pike", "qin", "pike"], ["qin", "pike", "qin"], ["qin", "qin", "pike"]],
    [["pike", "qin", "pike", "qin"], ["pike", "qin", "qin"], ["pike", "captain", "qin", "pike"]],
  ];
  const loadPatrols = [
    { at: 0, left: true, foes: ["qin", "pike", "qin"] },
    { at: 15, left: false, foes: ["pike", "qin", "qin"] },
    { at: 31, left: true, foes: ["pike", "qin", "pike"] },
    { at: 47, left: false, foes: ["captain", "qin", "pike"] },
    { at: 67, left: true, foes: ["qin", "pike", "qin"] },
    { at: 84, left: false, foes: ["pike", "qin", "qin"] },
  ];
  const barricades = {
    defense: [
      { x: 13, y: 79, w: 194, h: 16 }, { x: 273, y: 79, w: 194, h: 16 },
      { x: 84, y: 138, w: 26, h: 14 }, { x: 366, y: 156, w: 26, h: 14 },
    ],
    assault: [
      { x: 13, y: 101, w: 195, h: 16 }, { x: 270, y: 101, w: 113, h: 16 },
      { x: 431, y: 101, w: 34, h: 16 },
      { x: 121, y: 184, w: 23, h: 13 }, { x: 315, y: 181, w: 25, h: 14 },
    ],
  };
  const clamp = (n, lo, hi) => Math.min(hi, Math.max(n, lo));
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const angle = (a, b) => Math.atan2(b.y - a.y, b.x - a.x);
  const diff = (a, b) => Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b)));
  const active = (unit) => unit.hp > 0;
  const name = (unit) => roster[unit.id].name;
  const nearest = (from, units) => units.reduce((best, unit) =>
    !best || dist(from, unit) < dist(from, best) ? unit : best, null);

  function unit(id, x, y) {
    const { hp } = roster[id];
    return { id, x, y, hp, max: hp, face: Math.PI / 2, fatigue: 0, morale: 72,
      cd: 0, wind: 0, hit: 0, swing: 0, moving: false, stride: 0, trait: null, status: "" };
  }

  function create(records = []) {
    return {
      phase: "title", records: new Set(records), party: [], foes: [], effects: [], log: [],
      elapsed: 0, time: 0, gate: 100, wounds: [], wave: 0, route: null, secure: 0, scene: "defense",
      rally: 0, rallyCD: 0, healed: false, gift: null, rolled: null, recruit: "",
      rescue: null, death: "", next: 4, defeated: 0, defenseResult: null,
      patrol: 0, repairs: 0, loading: null,
    };
  }

  function record(run, id) {
    run.records.add(id);
  }

  function note(run, text) {
    run.log.unshift({ at: run.elapsed, text });
    run.log.length = Math.min(6, run.log.length);
  }

  function start(records) {
    const run = create(records);
    run.phase = "defense";
    run.party = [unit("liu", 240, 213), unit("fan", 264, 209)];
    run.wounds = wounds.map((wound) => ({ ...wound, state: wound.arrives ? "pending" : "waiting" }));
    record(run, "pei");
    note(run, "번쾌가 합류했습니다. 성문에 닿은 진군부터 밀어내세요.");
    return run;
  }

  function camp(run) {
    const saved = run.wounds.filter((wound) => wound.state === "saved").length;
    run.defenseResult = { saved, lost: run.wounds.length - saved, fallen: run.party.filter((u) => u.hp <= 0).map(name) };
    run.wounds.filter((w) => w.state !== "saved").forEach((w) => { w.state = "lost"; });
    run.phase = "camp";
    run.scene = "camp";
    run.foes = [];
    run.effects = [];
    run.rescue = null;
    run.party.forEach((u, i) => {
      u.x = 232 + i * 25;
      u.y = i % 2 ? 177 : 190;
      u.moving = false;
      u.wind = 0;
      u.swing = 0;
      u.hit = 0;
      u.face = angle(u, { x: 240, y: 153 });
    });
    if (saved) record(run, "rescue");
    if (run.defenseResult.lost) record(run, "lost");
    note(run, "소하 “들것 " + saved + "개가 돌아왔소. 약 한 첩을 누구에게 쓰겠소?”");
  }

  function heal(run, id) {
    const recipient = run.party.find((u) => u.id === id);
    if (run.phase !== "camp" || run.healed || !recipient) return false;
    run.healed = recipient.id;
    recipient.face = angle(recipient, { x: 240, y: 154 });
    run.party[0].face = recipient === run.party[0] ? recipient.face : angle(run.party[0], recipient);
    recipient.hp = clamp(recipient.hp + 68, 0, recipient.max);
    recipient.fatigue = Math.max(0, recipient.fatigue - 44);
    recipient.morale = clamp(recipient.morale + 18, 0, 100);
    note(run, name(recipient) + "에게 야영지 약을 썼습니다. 체력, 피로, 사기 회복.");
    return true;
  }

  function resultForFace(face) {
    let end = 0;
    for (const entry of odds) {
      end += entry.faces;
      if (face <= end) return entry.id;
    }
    return null;
  }

  function roll(run, random = Math.random) {
    if (run.phase !== "camp" || run.rolled) return null;
    const face = 1 + Math.floor(random() * 18);
    const id = resultForFace(face);
    run.rolled = { face, id, duplicate: run.party.some((u) => u.id === id) };
    if (run.rolled.duplicate) {
      run.recruit = name({ id }) + "의 재등장으로 ‘고른 숨’이 특기 후보에 추가됐습니다.";
    } else {
      const flank = unit(id, 184, 177);
      flank.face = angle(flank, run.party[0]);
      run.party.push(flank);
      run.recruit = name(flank) + " 합류. 남은 편성 " + (4 - run.party.length) + "자리.";
      if (id === "xiang") record(run, "xiang");
    }
    note(run, run.recruit);
    return run.rolled;
  }

  function give(run, id, trait) {
    const recipient = run.party.find((u) => u.id === id);
    if (run.phase !== "camp" || run.gift || !recipient || !["guard", "edge", ...(run.rolled?.duplicate ? ["breath"] : [])].includes(trait)) return false;
    recipient.trait = trait;
    if (recipient !== run.party[0]) {
      recipient.face = angle(recipient, run.party[0]);
      run.party[0].face = angle(run.party[0], recipient);
    }
    run.gift = { id, trait };
    note(run, name(recipient) + "에게 전투 보상 ‘" + traits[trait].name + "’을 부여했습니다.");
    return true;
  }

  function depart(run) {
    if (run.phase !== "camp") return false;
    run.phase = "assault";
    run.scene = "assault";
    run.time = 0;
    run.wave = 0;
    run.next = 12;
    run.secure = 0;
    run.rally = 0;
    run.rallyCD = 0;
    run.party.forEach((u, i) => {
      u.x = 238 + i * 17 - (i > 1 ? 40 : 0);
      u.y = 235 + i * 7;
      u.fatigue *= 0.35;
      u.morale = Math.max(u.morale, 58);
      u.cd = 0;
      u.face = -Math.PI / 2;
    });
    [[178, 153, "qin"], [302, 145, "qin"], [255, 134, "pike"],
      [251, 63, "captain"], [312, 49, "pike"], [213, 55, "qin"]]
      .forEach(([x, y, id]) => run.foes.push(unit(id, x, y)));
    note(run, "야영지 휴식으로 전열의 피로와 사기가 회복됐습니다.");
    note(run, "정면 초소에서 합류를 부르거나, 오른쪽 도랑을 따라 측문을 여세요.");
    return true;
  }

  function barriers(run) {
    const blocks = barricades[run.phase] || [];
    if (run.phase !== "assault") return blocks;
    const closed = [
      run.route !== "front" && { x: 208, y: 101, w: 62, h: 16 },
      run.route !== "side" && { x: 383, y: 101, w: 48, h: 16 },
    ].filter(Boolean);
    return [...blocks, ...closed];
  }

  function move(run, u, dx, dy) {
    const blocks = barriers(run);
    const blocked = (x, y) => blocks.some((b) => x > b.x - 5 && x < b.x + b.w + 5 && y > b.y - 5 && y < b.y + b.h + 5);
    const x = clamp(u.x + dx, 19, 461);
    const y = clamp(u.y + dy, 17, 269);
    const previousX = u.x;
    const previousY = u.y;
    if (!blocked(x, u.y)) u.x = x;
    if (!blocked(u.x, y)) u.y = y;
    u.moving = Math.hypot(u.x - previousX, u.y - previousY) > 0.05;
    if (u.moving) u.stride += 1.2 * Math.hypot(dx, dy);
  }

  function toward(run, u, target, speed, dt, stop = 0) {
    const direction = angle(u, target);
    u.face = direction;
    const step = Math.min(speed * dt, Math.max(0, dist(u, target) - stop));
    move(run, u, Math.cos(direction) * step, Math.sin(direction) * step);
  }

  function through(run, u, target, speed, dt, stop) {
    const opening = run.phase === "defense" ? 240 : run.route === "side" ? 408 : 238;
    const wallY = run.phase === "defense" ? 86 : 109;
    const across = (u.y - wallY) * (target.y - wallY) < 0;
    if (across && (run.phase === "defense" || run.route)) {
      toward(run, u, { x: opening, y: Math.abs(u.x - opening) > 13 ? (u.y < wallY ? wallY - 19 : wallY + 20) : (u.y < wallY ? wallY + 23 : wallY - 22) }, speed, dt);
    } else {
      toward(run, u, target, speed, dt, stop);
    }
  }

  function separated(run, a, b) {
    return barriers(run).some((block) => [0.25, 0.5, 0.75].some((t) => {
      const x = a.x + (b.x - a.x) * t;
      const y = a.y + (b.y - a.y) * t;
      return x > block.x && x < block.x + block.w && y > block.y && y < block.y + block.h;
    }));
  }

  function aimTarget(run) {
    const player = run.party[0];
    return nearest(player, run.foes.filter((u) => active(u) && dist(player, u) < roster.liu.reach + 14 &&
      !separated(run, player, u))) ||
      { x: player.x + Math.cos(player.face) * 30, y: player.y + Math.sin(player.face) * 30 };
  }

  function effect(run, x, y, text, color) {
    let lane = 0;
    while (lane < 3 && run.effects.some((e) => e.life > 0.47 &&
      Math.abs(e.x - x) < 19 && Math.abs(e.y - (y - lane * 8)) < 7)) lane++;
    run.effects.push({ x, y: y - lane * 8, text, color, life: 0.82 });
  }

  function strike(run, source, target, multiplier = 1) {
    const hitStrength = (source.fatigue > 74 ? 0.74 : 1) * (source.morale < 35 ? 0.78 : 1) * (source.trait === "edge" ? 1.32 : 1);
    const armor = (target.trait === "guard" ? 0.65 : 1) * (target.id === "liu" && run.rally > 0 ? 0.77 : 1);
    const hit = Math.max(1, Math.round(roster[source.id].damage * hitStrength * armor * multiplier));
    target.hp = Math.max(0, target.hp - hit);
    target.hit = 0.23;
    target.morale = Math.max(0, target.morale - 3);
    if (!target.hp) target.wind = 0;
    effect(run, target.x, target.y - 18, "−" + hit, run.party.includes(target) ? "#f28d58" : "#edb44e");
    if (!target.hp && run.party.includes(target)) {
      note(run, name(target) + " 쓰러짐. 쓰러진 동료는 야영지 약으로 일어날 수 있습니다.");
      run.party.filter(active).forEach((u) => { u.morale = Math.max(0, u.morale - 15); });
    } else if (!target.hp) {
      run.defeated++;
      source.morale = Math.min(100, source.morale + 6);
    }
  }

  function rally(run) {
    if (run.rallyCD > 0) return;
    run.rally = 6;
    run.rallyCD = 20;
    for (const u of run.party.filter(active)) {
      u.morale = Math.min(100, u.morale + 16);
      u.fatigue = Math.max(0, u.fatigue - 18);
    }
    note(run, "집결 신호. 동료가 유방 곁으로 이동하고 피로가 줄었습니다. 사기 +16.");
    effect(run, run.party[0].x, run.party[0].y - 24, "집결!", "#edb44e");
  }

  function nearby(run) {
    const player = run.party[0];
    if (run.phase === "defense") {
      const victim = nearest(player, run.wounds.filter((w) => w.state === "waiting"));
      if (victim && dist(player, victim) < 26) return { ...victim, action: "rescue", ref: victim };
      if (run.repairs && run.gate < 90 && dist(player, points.gate) < 28 &&
          !run.foes.some((u) => active(u) && dist(u, points.gate) < 48)) {
        return { ...points.gate, name: "성문 보강", action: "repair" };
      }
    }
    if (run.phase === "assault") {
      if (!run.route && dist(player, points.front) < 32) return { ...points.front, name: "정면 합류", action: "front" };
      if (!run.route && dist(player, points.side) < 30) return { ...points.side, name: "측문 열기", action: "side" };
      if (run.route && !run.loading && dist(player, points.supply) < 35) {
        return { ...points.supply, name: "군량고 개방", action: "supply" };
      }
    }
    return null;
  }

  function support(run, u, player, dt) {
    const vulnerable = nearest(u, run.party.filter((a) => a !== u && a.hp > 0 && a.hp < a.max - 13));
    const threatened = run.foes.some((enemy) => active(enemy) && dist(u, enemy) < 30);
    const injury = run.phase === "defense" && nearest(u, run.wounds.filter((w) => w.state === "waiting" && dist(u, w) < 48));
    if (u.hp < 26 || threatened) {
      u.status = "위험 감지, 유방에게 이동";
      through(run, u, player, 71, dt, 17);
    } else if (vulnerable && dist(u, vulnerable) < 66) {
      u.status = "동료 응급 처치";
      through(run, u, vulnerable, 58, dt, 16);
      if (dist(u, vulnerable) < 25 && u.cd === 0) {
        vulnerable.hp = Math.min(vulnerable.max, vulnerable.hp + 13);
        u.cd = 5;
        u.fatigue = Math.min(100, u.fatigue + 11);
        effect(run, vulnerable.x, vulnerable.y - 22, "+13", "#c6bd5a");
        note(run, "소하가 " + name(vulnerable) + "의 상처를 돌봤습니다. 체력 +13.");
      }
    } else if (injury && dist(player, injury) < 53) {
      u.status = "부상자 지혈";
      through(run, u, injury, 58, dt, 11);
      if (dist(u, injury) < 18 && !injury.stabilized) {
        injury.stabilized = true;
        injury.deadline += 28;
        note(run, "소하가 " + injury.name + "의 지혈을 마쳤습니다. 구조 가능 시간 +28초.");
      }
    } else {
      u.status = "유방 곁에서 대기";
      through(run, u, player, 66, dt, 27);
    }
  }

  function ally(run, u, player, dt) {
    if (run.rally > 0) {
      u.status = "집결, 피로 회복";
      const slot = run.party.indexOf(u);
      const offset = slot === 1 ? 23 : slot === 2 ? -23 : 0;
      through(run, u, { x: player.x + offset, y: player.y + (slot === 3 ? 27 : 16) }, roster[u.id].speed + 15, dt, 4);
      if (!u.moving) u.face = player.face;
      const threat = nearest(u, run.foes.filter((e) => active(e) && !separated(run, u, e)));
      if (u.id !== "xiao" && threat && dist(u, threat) < roster[u.id].reach && !u.cd) {
        u.face = angle(u, threat);
        u.cd = 0.85;
        u.swing = 0.22;
        strike(run, u, threat);
      }
      return;
    }
    if (u.id === "xiao") return support(run, u, player, dt);
    const settings = roster[u.id];
    const tired = u.fatigue > 78 || (u.status === "피로로 대열 복귀" && u.fatigue > 37);
    const careful = u.id === "fan" && u.hp < u.max * 0.36;
    const charging = u.id === "xiang" && !tired;
    const leash = careful ? 28 : charging ? 109 : u.id === "fan" ? 51 : 65;
    const foe = nearest(u, run.foes.filter((e) => active(e) && dist(player, e) < leash
      && (!separated(run, u, e) || run.route)));
    if (tired || !foe || dist(u, player) > leash + 25) {
      u.status = tired ? "피로로 대열 복귀" : careful ? "체력 저하로 추적 축소" : u.id === "fan" ? "유방 호위" : "대열 유지";
      through(run, u, player, settings.speed + 5, dt, u.id === "fan" ? 16 : 29);
      return;
    }
    u.status = charging ? "적 대열 돌파" : careful ? "체력 저하로 추적 축소" : u.id === "fan" ? "유방 호위" : "교전";
    const reach = settings.reach;
    through(run, u, foe, settings.speed * (charging ? 1.22 : 1), dt, reach - 4);
    if (dist(u, foe) <= reach && !u.cd && !separated(run, u, foe)) {
      u.cd = charging ? 0.65 : 0.9;
      u.swing = 0.24;
      u.fatigue = Math.min(100, u.fatigue + (charging ? 15 : 9));
      strike(run, u, foe);
      if (charging) {
        for (const flank of run.foes.filter((e) => e !== foe && active(e) && dist(u, e) < 40 && !separated(run, u, e))) {
          strike(run, u, flank, 0.43);
        }
      }
    }
  }

  function enemy(run, u, dt) {
    const gate = points.gate;
    const closest = nearest(u, run.party.filter(active));
    if (!closest) return;
    const gateDuty = run.phase === "defense" && dist(u, closest) > 64;
    const target = gateDuty ? gate : closest;
    const wallSide = run.phase === "assault" && (u.y - 109) * (closest.y - 109) < 0;
    if (wallSide && !run.route) {
      const guard = { x: u.id === "captain" ? 259 : u.x, y: u.y < 109 ? 74 : 139 };
      toward(run, u, guard, 25, dt, 2);
      u.wind = 0;
      return;
    }
    const settings = roster[u.id];
    if (u.wind > 0) {
      u.wind = Math.max(0, u.wind - dt);
      if (u.wind === 0) {
        u.swing = 0.25;
        if (gateDuty && dist(u, gate) < 32) {
          const damage = u.id === "captain" ? 9 : 4;
          run.gate = Math.max(0, run.gate - damage);
          effect(run, gate.x, gate.y - 9, "성문 −" + damage, "#f28d58");
        } else if (!gateDuty && dist(u, closest) < settings.reach + 9 && diff(u.face, angle(u, closest)) < 0.92 && !separated(run, u, closest)) {
          strike(run, u, closest);
        }
      }
      return;
    }
    const speed = settings.speed * (u.hit > 0 ? 0.5 : 1);
    through(run, u, target, speed, dt, (gateDuty ? 17 : settings.reach - 4));
    if (dist(u, target) < (gateDuty ? 27 : settings.reach) && !u.cd && (gateDuty || !separated(run, u, target))) {
      u.wind = u.id === "captain" ? 0.51 : 0.44;
      u.cd = u.id === "captain" ? 1.22 : 1.47;
      u.moving = false;
    }
  }

  function wave(run) {
    if (run.phase === "defense") {
      const waveIndex = Math.floor(run.patrol / 3);
      const group = run.patrol % 3;
      const lineup = defenseWaves[waveIndex][group];
      const center = [238, 153, 327][(waveIndex + group) % 3];
      lineup.forEach((id, i) => run.foes.push(unit(id, center + i * 23, 21 + (i % 2) * 7)));
      run.wave = waveIndex + 1;
      run.patrol++;
      run.next = run.patrol === 12 ? Infinity : run.time + [16, 17, 23][group];
      note(run, group === 0 ? "진군 " + run.wave + "차 파상. 성문으로 접근합니다." :
        "진군 후속대가 " + (center < 200 ? "서쪽에서" : center > 290 ? "동쪽에서" : "중앙으로") + " 접근합니다.");
      return;
    }
    const lineup = run.wave % 2 ? ["qin", "pike", "qin"] : ["qin", "qin"];
    lineup.forEach((id, i) => {
      const x = run.wave % 2 ? 426 - i * 33 : 40 + i * 30;
      run.foes.push(unit(id, x, 253 - (i % 3) * 18));
    });
    run.wave++;
    run.next = run.time + 27;
    note(run, "진군 순찰대가 야전 뒤편에서 접근합니다.");
  }

  function finish(run, won, reason) {
    run.phase = won ? "won" : "lost";
    run.death = reason;
    record(run, won ? "win" : "lose");
    note(run, reason);
  }

  function resolveInteraction(run, dt, held) {
    const point = nearby(run);
    const player = run.party[0];
    if (!point || !held || (run.rescue && run.rescue.action !== point.action)) run.rescue = null;
    if (!point || !held) return;
    if (!run.rescue) run.rescue = { action: point.action, progress: 0 };
    if (point.action === "supply" && run.foes.some((u) => active(u) && dist(u, point) < 51)) {
      run.rescue.progress = Math.max(0, run.rescue.progress - dt);
      return;
    }
    if (player.moving || player.hit > 0.15) return;
    player.face = angle(player, point);
    const duration = point.action === "rescue" ? (point.ref.stabilized ? 0.75 : 1.3) :
      point.action === "supply" ? 2.2 : point.action === "front" ? 2.5 : 1.65;
    run.rescue.progress += dt / duration;
    if (run.rescue.progress < 1) return;
    run.rescue = null;
    if (point.action === "rescue") {
      point.ref.state = "saved";
      run.repairs++;
      run.party.filter(active).forEach((u) => { u.morale = Math.min(100, u.morale + 8); });
      effect(run, point.x, point.y - 8, "구조 +1", "#c6bd5a");
      record(run, "rescue");
      note(run, point.name + " 구조 완료. 사기 +8, 성문 보강 자재 +1.");
    } else if (point.action === "repair") {
      run.repairs--;
      run.gate = Math.min(100, run.gate + 24);
      effect(run, point.x, point.y + 13, "성문 +24", "#c6bd5a");
      note(run, "구조한 주민이 성문을 보강했습니다. 성문 +24.");
    } else if (point.action === "supply") {
      run.loading = { started: run.time, progress: 0, patrol: 0 };
      note(run, "봉인을 열었습니다. 군량을 수레에 싣는 동안 창고를 지키세요.");
    } else {
      run.route = point.action;
      record(run, point.action);
      if (run.route === "front") {
        run.party.filter(active).forEach((u) => { u.morale = Math.min(100, u.morale + 20); });
        run.foes.filter((u) => active(u) && u.y < 108).forEach((u) => { u.hp = Math.max(1, u.hp - 21); });
        note(run, "정면 합류. 지원군이 진군 수비대를 압박했습니다. 살아 있는 동료 사기 +20.");
      } else {
        note(run, "측문이 열렸습니다. 수비대가 움직이기 전에 군량고로 들어가세요.");
        run.next = Math.max(run.next, run.time + 35);
      }
    }
  }

  function loadSupplies(run, player, dt) {
    const loading = run.loading;
    if (!loading) return;
    const patrol = loadPatrols[loading.patrol];
    if (patrol && run.time - loading.started >= patrol.at) {
      patrol.foes.forEach((id, i) => run.foes.push(unit(id, patrol.left ? 51 + i * 26 : 438 - i * 24, 23 + i * 9)));
      loading.patrol++;
      note(run, (patrol.left ? "서쪽" : "동쪽") + "의 진군이 군량고를 되찾으러 옵니다.");
    }
    const clear = dist(player, points.supply) < 79 && !run.foes.some((enemy) =>
      active(enemy) && dist(enemy, points.supply) < 48);
    if (clear) loading.progress += dt;
    if (loading.progress >= 105 && run.foes.every((enemy) => !active(enemy) || enemy.y > 105)) {
      finish(run, true, "진군 군량을 실어 패현군에 넘겼습니다.");
    }
  }

  function tick(run, dt, input) {
    if (!["defense", "assault"].includes(run.phase)) return;
    run.time += dt;
    run.elapsed += dt;
    run.rallyCD = Math.max(0, run.rallyCD - dt);
    run.rally = Math.max(0, run.rally - dt);
    for (const u of [...run.party, ...run.foes]) {
      u.cd = Math.max(0, u.cd - dt);
      u.hit = Math.max(0, u.hit - dt);
      u.swing = Math.max(0, u.swing - dt);
      u.moving = false;
      const rate = run.rally > 0 && run.party.includes(u) ? 12 : u.id === "liu" ? 7 : 9;
      u.fatigue = Math.max(0, u.fatigue - dt * rate * (u.trait === "breath" ? 1.7 : 1));
    }
    for (const e of run.effects) e.life -= dt;
    run.effects = run.effects.filter((e) => e.life > 0);
    const player = run.party[0];
    if (run.phase === "defense") {
      if (run.time > 7 && !run.party.some((u) => u.id === "xiao")) {
        run.party.push(unit("xiao", 217, 217));
        record(run, "xiao");
        note(run, "소하가 들것을 이끌고 합류했습니다. 가까운 부상자의 지혈을 도울 수 있습니다.");
      }
      for (const wound of run.wounds) {
        if (wound.state === "pending" && run.time >= wound.arrives) {
          wound.state = "waiting";
          note(run, wound.name + "이 전장에 쓰러졌습니다. 구조 표식을 확인하세요.");
        }
        if (wound.state === "waiting" && run.time >= wound.deadline) {
          wound.state = "lost";
          record(run, "lost");
          note(run, wound.name + "의 구조 시간이 지났습니다.");
        }
      }
    }
    if (!run.loading && run.time >= run.next && (run.phase === "defense" || run.foes.filter(active).length < 7)) wave(run);
    const length = Math.hypot(input.x, input.y) || 1;
    const speed = roster.liu.speed * (player.fatigue > 74 ? 0.82 : 1);
    if (input.x || input.y) {
      move(run, player, input.x / length * speed * dt, input.y / length * speed * dt);
      player.face = Math.atan2(input.y, input.x);
    }
    if (input.rally) rally(run);
    if (input.aim && (input.attack || !player.moving)) player.face = angle(player, input.aim);
    if (input.attack && input.aim && player.cd === 0) {
      player.cd = 0.61;
      player.swing = 0.26;
      player.fatigue = Math.min(100, player.fatigue + 8.5);
      for (const foe of run.foes.filter(active)) {
        if (dist(player, foe) <= roster.liu.reach && diff(player.face, angle(player, foe)) < 1.05 && !separated(run, player, foe)) {
          strike(run, player, foe, run.rally > 0 ? 1.12 : 1);
          move(run, foe, Math.cos(player.face) * 9, Math.sin(player.face) * 9);
        }
      }
    }
    run.party.slice(1).filter(active).forEach((u) => ally(run, u, player, dt));
    run.foes.filter(active).forEach((u) => enemy(run, u, dt));
    if (!player.hp) return finish(run, false, "유방이 쓰러지자 패현군이 철수했습니다.");
    if (!run.gate) return finish(run, false, "패현 성문이 무너져 방어에 실패했습니다.");
    resolveInteraction(run, dt, input.hold);
    if (run.phase === "assault") loadSupplies(run, player, dt);
    if (run.phase === "defense" && run.next === Infinity && run.wave === 4 && !run.foes.some(active)) {
      run.secure += dt;
      if (run.secure > 14 || run.wounds.every((w) => w.state !== "waiting")) camp(run);
    }
  }

  const api = { width, height, roster, odds, traits, stories, points, barricades, create, start, aimTarget,
    tick, nearby, heal, roll, resultForFace, give, depart, active, barriers };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else window.Pei = api;
})();
