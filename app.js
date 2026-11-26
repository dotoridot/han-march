(() => {
  "use strict";

  const { width, height, roster, odds, traits, stories } = Pei;
  const $ = (selector) => document.querySelector(selector);
  const field = $("#field");
  const ctx = field.getContext("2d");
  const dialog = $("#dialog");
  const dialogContent = $("#dialog-content");
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
  const keys = new Set();
  const saveKey = "chu-han.pei-banner.journal.v1";
  const locations = {
    title: ["패현 성문", "기원전 209년, 진 말"],
    defense: ["패현 성문", "첫째 전투, 성문 방어"],
    camp: ["패현군 야영지", "전열 재정비"],
    assault: ["진군 보급 거점", "둘째 전투, 군량고 공략"],
    won: ["진군 보급 거점", "군량고 확보"],
    lost: ["패현군", "철수"],
  };
  let run = Pei.create(load());
  let displayedPhase = null;
  let displayedRecords = run.records.size;
  let command = false;
  let pointer = null;
  let attacking = false;
  let attackPressed = false;
  let keyAttack = false;
  let dialogKind = "";
  let returnFocus = null;
  let lastFrame = null;
  let uiTime = 0;
  let campTrait = "guard";
  let campVoice = false;
  let suspended = false;
  let ambient = 0;
  let announced = null;

  function load() {
    try {
      const records = JSON.parse(localStorage.getItem(saveKey) || "[]");
      return Array.isArray(records) ? records.filter((id) => typeof id === "string" && Object.hasOwn(stories, id)) : [];
    } catch {
      return [];
    }
  }

  function save() {
    try {
      localStorage.setItem(saveKey, JSON.stringify([...run.records]));
    } catch {
      // 현재 탭에서 다시 시작할 때도 기록을 유지합니다.
    }
  }

  function time(seconds) {
    const value = Math.max(0, Math.floor(seconds));
    return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
  }

  function figures(content) {
    return content.replace(/\d+(?:[/:.]\d+)*(?:%)?/g, '<span class="number">$&</span>');
  }

  function combat() {
    return run.phase === "defense" || run.phase === "assault";
  }

  function releaseInput() {
    keys.clear();
    attacking = false;
    attackPressed = false;
    keyAttack = false;
    command = false;
  }

  function start() {
    if (dialog.open) closeDialog(false);
    campTrait = "guard";
    campVoice = false;
    suspended = false;
    run = Pei.start(run.records);
    pointer = null;
    releaseInput();
    updatePhase();
    field.focus({ preventScroll: true });
  }

  function open(kind) {
    returnFocus = kind === "camp" ? $('[data-action="camp"]') : document.activeElement;
    dialogKind = kind;
    dialog.classList.toggle("camp-dialog", kind === "camp");
    releaseInput();
    renderDialog();
    if (!dialog.open) dialog.showModal();
    $("#dialog-title").focus();
  }

  function closeDialog(restore = true) {
    const trigger = returnFocus;
    returnFocus = null;
    releaseInput();
    dialog.close();
    if (restore && trigger?.isConnected) trigger.focus({ preventScroll: true });
  }

  function button(action, label, extra = "") {
    return '<button type="button" data-action="' + action + '" ' + extra + ">" + label + "</button>";
  }

  function campScene() {
    const { saved, lost, fallen } = run.defenseResult;
    const healedName = run.healed && roster[run.healed].name;
    const recovery = healedName ? '<p class="result" data-camp-result="heal">' + healedName + '에게 약을 썼습니다.</p>' :
      '<p class="subtle">약 한 첩. 체력 +68, 피로 −44, 사기 +18. 쓰러진 동료도 복귀합니다.</p><div class="choices">' + run.party.map((u) =>
        button("heal:" + u.id, roster[u.id].name + ' <span class="denom">' + u.hp + "/" + u.max + "</span>",
          'aria-label="' + roster[u.id].name + ' 회복, 체력 ' + u.hp + '/' + u.max + '"')).join("") + "</div>";
    const candidates = ["guard", "edge", ...(run.rolled?.duplicate ? ["breath"] : [])];
    const gift = run.gift ? '<p class="result" data-camp-result="give">' + roster[run.gift.id].name + "에게 ‘" + traits[run.gift.trait].name + "’을 부여했습니다.</p>" :
      '<p class="subtle">특기 하나를 골라 한 명에게 부여하세요.</p><div class="choices">' +
      candidates.map((id) => button("trait:" + id,
        traits[id].name + (campTrait === id ? ' <small class="selected-state" aria-hidden="true">선택</small>' : ""),
        'aria-pressed="' + (campTrait === id) + '"')).join("") +
      '</div><p class="subtle">' + traits[campTrait].name + " — " + traits[campTrait].detail + '</p><div class="choices">' +
      run.party.map((u) => button("give:" + u.id, roster[u.id].name + "에게 부여",
        'aria-label="' + roster[u.id].name + "에게 부여, " + traits[campTrait].name + '"')).join("") + "</div>";
    const report = "소하 “" + (saved ? "들것 " + saved + "개가 돌아왔소. " : "돌아온 들것이 없소. ") +
      (lost ? lost + "명은 성 안으로 옮기지 못했소. " : "모두 성 안에서 치료 중이오. ") +
      (fallen.length ? fallen.join(", ") + "도 전열에서 쓰러졌소.”" : "동료들은 모두 두 발로 돌아왔소.”");
    const probabilities = odds.map(({ id, faces }) =>
      "<span>" + roster[id].name + ' <b class="denom">' + faces + "/18 (" + (100 * faces / 18).toFixed(2) + "%)</b></span>").join("");
    return '<p class="quote">' + report + '</p><p class="subtle camp-narrow-hint">아래로 내려 특기를 배정하고 출정하세요.</p>' +
      '<div class="camp-grid"><section class="camp-sector"><h3>장수 등용</h3>' +
      '<div class="die-row"><canvas class="die" width="64" height="64" aria-hidden="true"></canvas><div>' +
      (run.rolled ? '<p class="result" data-camp-result="roll">' + run.rolled.face + "면, " + run.recruit + "</p>" :
        button("roll", "18면 주사위 굴리기")) + "</div></div>" +
      '<p class="subtle die-note">무료 1회. 중복 장수가 나오면 특기 후보가 늘어납니다.</p>' +
      '<div class="odds" role="group" aria-label="장수별 등용 확률">' + probabilities + "</div>" +
      (run.rolled?.id === "xiang" ? '<p class="quote">' + stories.xiang[1] + "</p>" : "") +
      '</section><div><section class="camp-sector"><h3>회복 대상</h3>' + recovery +
      '</section><section class="camp-sector"><h3>전투 보상 특기</h3>' + gift + "</section></div></div>" +
      '<div class="camp-footer">' + button("depart", "진군 거점으로 출정", 'class="primary"' + (!run.gift ? " disabled" : "")) +
      (run.gift ? "" : '<p class="subtle">특기를 배정하면 출정할 수 있습니다.</p>') + "</div>";
  }

  function renderDialog(focus = "") {
    let title;
    let body;
    if (dialogKind === "camp") {
      title = "야영지 회의";
      body = campScene();
      if (!campVoice) {
        campVoice = true;
        run.party.filter(Pei.active).forEach((u) => { u.face = Math.atan2(154 - u.y, 240 - u.x); });
      }
    } else if (dialogKind === "journal") {
      title = "행군 기록";
      body = run.records.size ? '<ol class="entries">' + [...run.records].map((id) =>
        '<li><span class="record-title">' + stories[id][0] + "</span><br>" + stories[id][1] + "</li>").join("") + "</ol>" :
        "<p>발견한 이야기와 인물을 여기에 기록합니다.</p>";
    } else {
      title = "일시정지";
      body = '<p>전투 시간이 멈췄습니다.</p><div class="choices">' + button("resume", "전투 계속", 'class="primary"') + "</div>";
    }
    dialogContent.innerHTML = '<div class="dialog-top"><h2 id="dialog-title" tabindex="-1">' + title + "</h2>" +
      button("close", "×", 'class="close" aria-label="창 닫기"') + "</div>" + body;
    if (dialogKind === "camp") PeiArt.die($(".die").getContext("2d"), run.rolled?.face);
    if (dialog.open) {
      const target = focus && [...dialog.querySelectorAll("[data-action]")].find((node) => node.dataset.action === focus && !node.disabled);
      const result = focus && dialog.querySelector('[data-camp-result="' + focus + '"]');
      if (result) result.tabIndex = -1;
      (target || result || $("#dialog-title")).focus();
    }
  }

  function updatePhase() {
    if (displayedPhase === run.phase) return;
    displayedPhase = run.phase;
    document.body.dataset.phase = run.phase;
    $("#place").textContent = locations[run.phase][0];
    $("#chapter").textContent = locations[run.phase][1];
    $("#pause").hidden = !combat();
    field.tabIndex = combat() ? 0 : -1;
    const veil = $("#veil");
    veil.replaceChildren();
    if (run.phase === "title") {
      veil.innerHTML = '<div class="cover"><p class="overline">기원전 209년, 진 말</p><h1>초한<span>패현의 깃발</span></h1><p>패현에 진군이 들이닥쳤다. 유방이 되어 성문을 지키고, 흩어진 사람을 모아 진군의 군량고를 확보하라.</p>' +
        button("start", "패현 성문으로") + "</div>";
    } else if (run.phase === "camp") {
      veil.innerHTML = '<div class="cover">' + button("camp", "야영지 회의 열기") + "</div>";
      open("camp");
    } else if (run.phase === "won" || run.phase === "lost") {
      const won = run.phase === "won";
      veil.innerHTML = '<div class="cover"><p class="overline' + (won ? "" : " defeat") + '">' + (won ? "승리" : "패배") + "</p><h2>" +
        (won ? "군량고의 새벽" : "접힌 깃발") + "</h2><p>" + run.death + "</p><p>" +
        figures("전투 " + time(run.elapsed) + ", 진군 " + run.defeated + "명 격퇴, 발견 " + run.records.size + "건") + "</p>" +
        "<p>새 판에는 장수와 특기를 다시 모읍니다. 행군 기록은 이어집니다.</p>" +
        button("start", "새 판 시작") + "</div>";
      releaseInput();
      veil.querySelector("button").focus({ preventScroll: true });
    }
    refresh();
  }

  function objective(label, done = false) {
    return '<p class="objective' + (done ? " done" : "") + '"><span aria-hidden="true">' +
      (done ? "◆" : "◇") + "</span><span>" + figures(label) + "</span></p>";
  }

  function hintLine(label) {
    return '<p class="subtle">' + figures(label) + "</p>";
  }

  function refresh() {
    const goals = $("#goals");
    const brief = $("#brief");
    brief.hidden = !combat();
    if (run.phase === "title") goals.innerHTML = objective("패현 성문을 지켜라") + objective("진군 군량고를 확보하라");
    else if (run.phase === "defense") {
      const pending = run.wounds.filter((w) => w.state === "waiting");
      const saved = run.wounds.filter((w) => w.state === "saved").length;
      goals.innerHTML = objective("성문 " + run.gate + "%, 파상 " + run.wave + "/4") +
        objective("부상자 구조 " + saved + "/3", saved === 3) +
        (pending.length ? hintLine(pending.map((w) => w.name + " " + time(Math.ceil(w.deadline - run.time))).join(" / ")) : "") +
        hintLine(Number.isFinite(run.next) ? "다음 진군 " + time(Math.ceil(run.next - run.time)) : "남은 진군 " + run.foes.filter(Pei.active).length + "명") +
        (run.repairs ? hintLine("보강 자재 " + run.repairs + "개. 적이 물러나면 성문에서 E.") : "");
      brief.innerHTML = figures("성문 " + run.gate + "%, 파상 " + run.wave + "/4, 부상자 구조 " + saved + "/3");
    } else if (run.phase === "camp") goals.innerHTML = objective("성문 방어", true) +
      objective("회복 대상 선택", run.healed) + objective("전투 보상 배정", !!run.gift) + objective("무료 등용", !!run.rolled);
    else if (run.phase === "assault") {
      const garrison = run.foes.filter((u) => Pei.active(u) && Math.hypot(u.x - Pei.points.supply.x, u.y - Pei.points.supply.y) < 51).length;
      goals.innerHTML = objective(run.route ? (run.route === "front" ? "정면 합류 완료" : "측문 개방 완료") : "정면 초소 합류 또는 측문 개방", !!run.route) +
        objective(run.loading ? "군량 수송 " + Math.min(100, Math.floor(run.loading.progress / 1.05)) + "%" : "군량고 개방") +
        (run.route ? hintLine(garrison ? "군량고 주변 진군 " + garrison + "명" :
          run.loading ? "군량고 표시 원 안에서 수레를 지키세요." : "군량고 표식에서 E를 누르세요.") : "");
      brief.innerHTML = figures(run.loading ? "군량 수송 " + Math.min(100, Math.floor(run.loading.progress / 1.05)) + "%" :
        run.route ? "군량고 표식에서 E를 길게 누르세요." : "정면 초소 합류 또는 측문 개방");
    } else goals.innerHTML = objective(run.death, run.phase === "won");
    if (combat()) goals.insertAdjacentHTML("beforeend", hintLine(run.rallyCD > 0 ? "집결 재사용 " + Math.ceil(run.rallyCD) + "초" : "집결 신호 준비됨"));
    $("#slots").innerHTML = run.party.length ? figures(run.party.length + "/4 자리") : "";
    const party = $("#party");
    party.innerHTML = run.party.map((u) => {
      const stats = [["체력", u.hp, u.hp / u.max, "hp"], ["피로", Math.ceil(u.fatigue), u.fatigue / 100, "fatigue"], ["사기", Math.round(u.morale), u.morale / 100, "morale"]];
      return '<div class="unit' + (u.hp <= 0 ? " out" : "") + '" data-unit="' + u.id + '"><canvas class="portrait" width="23" height="30" aria-hidden="true"></canvas>' +
        '<div><div class="unit-head"><strong>' + roster[u.id].name + '</strong><small>' +
        (u.hp <= 0 ? "쓰러짐" : u.trait ? traits[u.trait].name : roster[u.id].role) +
        '</small></div><div class="stats">' + stats.map(([label, value, fill, kind]) =>
          '<span class="stat">' + label + ' <b class="stat-value">' + value + '</b><i aria-hidden="true" class="bar ' + kind +
          '" style="--fill:' + 100 * fill + '%"></i></span>').join("") +
        "</div>" + (combat() && u.hp > 0 && (u.status || u.fatigue > 74 || u.morale < 35) ?
          '<small class="subtle unit-status">' + [u.status, u.fatigue > 74 ? "과로로 공격 약화" : "", u.morale < 35 ? "사기 저하로 공격 약화" : ""].filter(Boolean).join(" / ") +
          "</small>" : "") + "</div></div>";
    }).join("");
    [...party.querySelectorAll("canvas")].forEach((canvas, i) => PeiArt.sprite(canvas.getContext("2d"),
      { ...run.party[i], face: Math.PI / 2, moving: false, hit: 0 }, 11, 28, true));
    $("#log").innerHTML = run.log.map((entry) => "<li><time>" + time(entry.at) + "</time><span>" + entry.text + "</span></li>").join("");
    if (run.log[0] !== announced) {
      announced = run.log[0];
      $("#announcement").textContent = announced?.text || "";
    }
    const target = combat() && Pei.nearby(run);
    const hint = $("#prompt");
    hint.hidden = !target;
    if (target) hint.textContent = "E 길게 누르기  " + target.name + (target.action === "rescue" ? " 구조" : "") +
      (run.rescue ? " " + Math.round(run.rescue.progress * 100) + "%" : "");
  }

  document.addEventListener("click", (event) => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    if (!action) return;
    const [verb, id] = action.split(":");
    if (verb === "start") return start();
    if (verb === "camp") return open("camp");
    if (verb === "close" || verb === "resume") return closeDialog();
    if (run.phase !== "camp") return;
    if (verb === "heal") Pei.heal(run, id);
    if (verb === "roll") Pei.roll(run);
    if (verb === "trait") campTrait = id;
    if (verb === "give") Pei.give(run, id, campTrait);
    if (verb === "depart" && run.gift && Pei.depart(run)) {
      closeDialog(false);
      updatePhase();
      pointer = null;
      field.focus({ preventScroll: true });
      return;
    }
    renderDialog(verb === "trait" ? action : verb);
  });

  $("#journal").addEventListener("click", () => open("journal"));
  $("#pause").addEventListener("click", () => open("pause"));
  dialog.addEventListener("click", (event) => { if (event.target === dialog) closeDialog(); });
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeDialog();
  });

  const inputKeys = new Set(["KeyW", "KeyA", "KeyS", "KeyD", "KeyQ", "KeyE"]);
  window.addEventListener("keydown", (event) => {
    if (dialog.open) return;
    if (event.code === "Escape" && combat() && !event.repeat) {
      event.preventDefault();
      open("pause");
      return;
    }
    if (event.code === "Space" && combat() && document.activeElement === field) {
      event.preventDefault();
      keys.add(event.code);
      keyAttack = true;
      suspended = false;
      return;
    }
    if (!combat() || !inputKeys.has(event.code)) return;
    event.preventDefault();
    keys.add(event.code);
    suspended = false;
    if (event.code === "KeyQ" && !event.repeat) command = true;
  });
  window.addEventListener("keyup", (event) => { keys.delete(event.code); });
  window.addEventListener("blur", releaseInput);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && combat()) {
      suspended = true;
      releaseInput();
    }
  });

  function aim(event) {
    const rect = field.getBoundingClientRect();
    pointer = { x: (event.clientX - rect.left) / rect.width * width, y: (event.clientY - rect.top) / rect.height * height };
    if (combat()) field.classList.add("aiming");
  }

  field.addEventListener("pointermove", aim);
  field.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || !combat() || dialog.open) return;
    field.focus({ preventScroll: true });
    aim(event);
    attacking = true;
    attackPressed = true;
    suspended = false;
    field.setPointerCapture(event.pointerId);
  });
  field.addEventListener("lostpointercapture", () => { attacking = false; });
  window.addEventListener("pointerup", (event) => { if (event.button === 0) attacking = false; });
  field.addEventListener("pointercancel", () => { attacking = false; });
  field.addEventListener("pointerleave", () => {
    if (!attacking) pointer = null;
    field.classList.remove("aiming");
  });

  function frame(now) {
    const dt = Math.max(0, Math.min(0.045, (now - (lastFrame ?? now)) / 1000));
    lastFrame = now;
    if (combat() && !dialog.open && !suspended) {
      const keyboardAttack = document.activeElement === field && (keys.has("Space") || keyAttack);
      Pei.tick(run, dt, {
        x: Number(keys.has("KeyD")) - Number(keys.has("KeyA")),
        y: Number(keys.has("KeyS")) - Number(keys.has("KeyW")),
        aim: keyboardAttack && !attacking && !attackPressed ? Pei.aimTarget(run) : pointer,
        attack: attacking || attackPressed || keyboardAttack, rally: command, hold: keys.has("KeyE"),
      });
      command = false;
      attackPressed = false;
      keyAttack = false;
    }
    updatePhase();
    if (displayedRecords !== run.records.size) {
      displayedRecords = run.records.size;
      save();
    }
    if (now > uiTime) {
      refresh();
      uiTime = now + 120;
    }
    if (!dialog.open && !suspended) ambient = now / 1000;
    PeiArt.draw(ctx, run, ambient, pointer, reducedMotion.matches);
    requestAnimationFrame(frame);
  }

  updatePhase();
  requestAnimationFrame(frame);
})();
