extends RefCounted

const SIZE = Vector2(640, 384)
const GATE = Vector2(320, 306)
const STAIR = Vector2(533, 306)
const PARAPET = Vector2(533, 280)
const FRONT = Vector2(320, 172)
const SIDE = Vector2(546, 146)
const SUPPLY = Vector2(340, 57)
const ROSTER = {
	"liu": ["유방", "검", 130, 118, "지휘"],
	"fan": ["번쾌", "방패·도끼", 152, 83, "전열 호위"],
	"xiao": ["소하", "약낭", 86, 88, "후열 응급 처치"],
	"xiang": ["항우", "장병기", 148, 102, "돌파"],
	"zhou": ["주발", "방패·도끼", 116, 86, "전열 유지"],
	"cao": ["조참", "활", 96, 92, "원거리 엄호"],
	"bow": ["성벽 궁수", "활", 92, 65, "성벽 엄호"],
	"qin": ["진군 보병", "검", 45, 55, ""],
	"pike": ["진군 창병", "장병기", 64, 45, ""],
	"captain": ["진군 대장", "방패·도끼", 105, 42, ""],
}
const WEAPONS = {
	"검": [47.0, 30, 0.16, 0.13, 0.29],
	"방패·도끼": [34.0, 34, 0.25, 0.16, 0.42],
	"장병기": [72.0, 36, 0.31, 0.18, 0.44],
	"활": [173.0, 24, 0.29, 0.1, 0.43],
	"약낭": [71.0, 15, 0.28, 0.11, 0.68],
}
const WAVE_AT = [5.0, 34.0, 65.0, 100.0]
const DEFENSE_GROUPS = [
	["qin", "qin", "pike"], ["qin", "qin", "pike", "qin"],
	["pike", "qin", "pike", "qin", "qin"], ["captain", "qin", "pike", "qin", "pike", "qin"],
]
const DRAFT = ["fan", "xiao", "zhou", "cao", "xiang"]
const OPTIONS = {
	"breach": [4, 4, 3, 3, 4],
	"steady": [6, 5, 3, 3, 1],
	"cover": [4, 4, 3, 7, 0],
}
const PERKS = {
	"power": ["예봉", "공격·회복량 +20%"],
	"guard": ["철벽", "받는 피해 20% 감소"],
	"focus": ["고른 숨", "피로 회복 +5/초"],
	"reach": ["장거리", "사거리 +20%"],
}
const STORY = {
	"intro": "기원전 209년. 진나라의 징발이 이어지자 각지에서 봉기가 일어났다. 패현의 유방은 성문 앞에 사람들을 모았다.",
	"rescue": "패현의 들것. 다친 주민들은 소하와 함께 성 안으로 들어갔다.",
	"xiang": "대체 역사. 항우는 회계에서 군을 일으키기 전 패현의 깃발 아래에 섰다.",
	"front": "정면의 나팔. 지원군이 진군의 시선을 돌렸다.",
	"side": "도랑의 빗장. 패현군이 측문을 열고 안으로 들어갔다.",
	"won": "군량고의 새벽. 패현에 보낼 군량을 확보했다.",
	"lost": "접힌 깃발. 살아남은 이들이 철수했다.",
}

var phase = "intro"
var team = []
var foes = []
var effects = []
var arrows = []
var logs = []
var journal = []
var wounds = []
var level_queue = []
var time = 0.0
var elapsed = 0.0
var wave = 0
var gate = 100
var repairs = 0
var rally_cd = 0.0
var rally_left = 0.0
var route = ""
var draft_plan = "steady"
var rolled = {}
var healed = ""
var bonus = ""
var pending_bonus = ""
var interaction = {}
var hold_consumed = false
var outcome = ""
var next_patrol = 0.0
var loading = -1.0
var loading_group = 0
var wins = 0
var strike_id = 0
var last_input = ""
var sound_events = []
var intro_card = 0

func setup(discovered: Array = []) -> void:
	journal = discovered.duplicate()
	team = [actor("liu", Vector2(320, 264)), actor("fan", Vector2(350, 269)), actor("bow", PARAPET)]
	team[2].elevated = true
	observe("intro")

static func actor(id: String, at: Vector2) -> Dictionary:
	return {"id":id, "p":at, "hp":ROSTER[id][2], "max_hp":ROSTER[id][2], "fatigue":0.0,
		"morale":75.0, "face":Vector2.UP, "walk":0.0, "moving":false, "weapon":ROSTER[id][1],
		"elevated":false, "attack":{}, "hit":0.0, "level":1, "xp":0, "skills":[],
		"status":"대기", "bubble":"", "speech":0.0, "speech_cd":0.0, "is_enemy":id in ["qin","pike","captain"]}

func observe(id: String) -> void:
	if id not in journal:
		journal.append(id)

func note(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 6:
		logs.pop_back()

func begin() -> void:
	phase = "defense"
	time = 0.0
	wounds = [
		{"p":Vector2(177,227), "name":"문지기", "arrive":0.0, "end":56.0, "state":"waiting"},
		{"p":Vector2(477,207), "name":"짐꾼", "arrive":22.0, "end":83.0, "state":"pending"},
		{"p":Vector2(317,111), "name":"전령", "arrive":53.0, "end":108.0, "state":"pending"},
	]
	note("북문 밖 넓은 들판에서 진군을 막으세요.")

func blockers() -> Array:
	if phase == "defense":
		return [Rect2(0, 284, 263, 23), Rect2(377, 284, 263, 23), Rect2(94,119,39,18), Rect2(482,98,33,18)]
	if phase != "assault":
		return []
	var result = [Rect2(0,112,274,18), Rect2(365,112,141,18), Rect2(585,112,55,18), Rect2(138,244,42,18)]
	if route != "front":
		result.append(Rect2(274,112,91,18))
	if route != "side":
		result.append(Rect2(506,112,79,18))
	return result

func blocked(p: Vector2) -> bool:
	for box in blockers():
		if box.grow(6).has_point(p):
			return true
	return false

func line_clear(a: Vector2, b: Vector2) -> bool:
	for box in blockers():
		for f in [0.2, 0.4, 0.6, 0.8]:
			if box.has_point(a.lerp(b, f)):
				return false
	return true

func walk(u: Dictionary, change: Vector2) -> void:
	if change.is_zero_approx() or u.elevated:
		return
	var original: Vector2 = u.p
	var next = (u.p + change).clamp(Vector2(12, 12), SIZE - Vector2(12, 13))
	if not blocked(Vector2(next.x, u.p.y)):
		u.p.x = next.x
	if not blocked(Vector2(u.p.x, next.y)):
		u.p.y = next.y
	u.moving = original.distance_to(u.p) > 0.06
	if u.moving:
		u.face = change.normalized()
		u.walk += original.distance_to(u.p)

func toward(u: Dictionary, target: Vector2, speed: float, dt: float, stop: float) -> void:
	if u.elevated:
		return
	var p: Vector2 = u.p
	var wall_y = 296.0 if phase == "defense" else 121.0
	var opening = 320.0 if route != "side" else 545.0
	if (p.y - wall_y) * (target.y - wall_y) < 0.0 and (phase == "defense" or not route.is_empty()):
		if absf(p.x - opening) > 17.0:
			target = Vector2(opening, wall_y + (25.0 if p.y > wall_y else -25.0))
		else:
			target = Vector2(opening, wall_y + (-32.0 if p.y > wall_y else 32.0))
		stop = 0.0
	var diff = target - p
	walk(u, diff.normalized() * minf(speed * dt, maxf(0.0, diff.length() - stop)))

func living(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0)

func nearest(p: Vector2, units: Array, radius: float = INF) -> Dictionary:
	var best = {}
	for u in units:
		var range_sq = p.distance_squared_to(u.p)
		if range_sq < radius * radius and u.hp > 0:
			best = u
			radius = sqrt(range_sq)
	return best

func target_at(p: Vector2) -> Dictionary:
	var player = team[0]
	if phase == "defense":
		if player.elevated or p.distance_to(STAIR) < 27:
			return {"id":"stairs", "p":PARAPET if player.elevated else STAIR, "label":"성벽에서 내려가기" if player.elevated else "성벽 오르기", "length":0.65}
		for wound in wounds:
			if wound.state == "waiting" and p.distance_to(wound.p) < 27.0:
				return {"id":"rescue", "p":wound.p, "label":wound.name + " 구조", "length":0.9 if wound.get("aid",false) else 1.4, "wound":wound}
		if repairs and gate < 90 and p.distance_to(GATE) < 31 and nearest(GATE, foes, 66).is_empty():
			return {"id":"repair","p":GATE,"label":"성문 보강","length":1.4}
	elif phase == "assault":
		if route.is_empty():
			if p.distance_to(FRONT) < 32:
				return {"id":"front","p":FRONT,"label":"정면 합류","length":1.9}
			if p.distance_to(SIDE) < 30:
				return {"id":"side","p":SIDE,"label":"측문 열기","length":1.5}
		elif loading < 0.0 and p.distance_to(SUPPLY) < 37:
			return {"id":"supply","p":SUPPLY,"label":"군량고 봉인 해제","length":2.0}
	return {}

func interact(dt: float, hold: bool) -> void:
	var player = team[0]
	var target = target_at(player.p)
	if not hold:
		hold_consumed = false
	if hold_consumed:
		return
	var obstructed = not target.is_empty() and target.id == "supply" and not nearest(SUPPLY, foes, 63).is_empty()
	if not hold or target.is_empty() or player.moving or player.hit > 0.15 or obstructed:
		if not interaction.is_empty():
			effects.append({"p":interaction.p, "life":0.65, "label":"중단", "tone":"notice"})
		interaction = {}
		return
	if interaction.is_empty() or interaction.p != target.p:
		interaction = target
		interaction.progress = 0.0
	player.face = player.p.direction_to(target.p) if player.p != target.p else player.face
	interaction.progress += dt / target.length
	if interaction.progress < 1.0:
		return
	var id = interaction.id
	interaction = {}
	hold_consumed = true
	effects.append({"p":target.p, "life":0.86, "label":"완료", "tone":"notice"})
	sound_events.append("complete")
	match id:
		"stairs":
			player.elevated = not player.elevated
			player.p = Vector2(548, 279) if player.elevated else STAIR + Vector2(0,10)
			player.weapon = "활" if player.elevated else "검"
			player.attack = {}
			note("성벽에서 활로 북쪽을 엄호합니다." if player.elevated else "들판으로 돌아왔습니다.")
		"rescue":
			target.wound.state = "saved"
			observe("rescue")
			repairs += 1
			for u in living(team):
				u.morale = minf(100, u.morale + 8)
				add_xp(u, 11)
			note(target.wound.name + " 구조. 성문 보강 자재 +1, 사기 +8.")
		"repair":
			repairs -= 1
			gate = mini(100, gate + 25)
			note("성문 내구도 +25.")
		"front", "side":
			route = id
			observe(id)
			if route == "front":
				for u in living(team):
					u.morale = minf(100, u.morale + 18)
				for f in living(foes):
					if f.p.y < 112:
						f.hp = maxi(1, f.hp - 20)
				note("지원군 도착. 사기 +18, 북쪽 수비병 약화.")
			else:
				next_patrol += 24.0
				note("측문 개방. 순찰대 도착이 늦어집니다.")
		"supply":
			loading = 0.0
			loading_group = 0
			note("봉인이 열렸습니다. 군량 수레 주변을 지키세요.")

func say(u: Dictionary, phrase: String) -> void:
	if u.speech_cd > 0:
		return
	u.bubble = phrase
	u.speech = 2.6
	u.speech_cd = 14.0
	note(ROSTER[u.id][0] + " “" + phrase + "”")

func add_xp(u: Dictionary, amount: int) -> void:
	if u.is_enemy or u.level >= 5:
		return
	u.xp += amount
	var limit = xp_limit(u)
	while u.xp >= limit and u.level < 5:
		u.xp -= limit
		u.level += 1
		level_queue.append(u)
		note("%s 레벨 %d. 강화 하나를 선택하세요." % [ROSTER[u.id][0], u.level])
		limit = xp_limit(u)

func xp_limit(u: Dictionary) -> int:
	return 55 + (u.level - 1) * 28

func pick_level(perk: String) -> bool:
	if level_queue.is_empty() or not PERKS.has(perk):
		return false
	var u = level_queue.pop_front()
	u.skills.append(perk)
	note(ROSTER[u.id][0] + " 강화: " + PERKS[perk][0])
	return true

func reach(u: Dictionary) -> float:
	var base = WEAPONS[u.weapon][0]
	if u.elevated and u.weapon == "활":
		base *= 1.27
	return base * (1.0 + 0.20 * u.skills.count("reach"))

func start_attack(u: Dictionary, target: Vector2, kind: String = "hit") -> bool:
	if not u.attack.is_empty() or u.hp <= 0:
		return false
	if not u.p.is_equal_approx(target):
		u.face = u.p.direction_to(target)
	var w = WEAPONS[u.weapon]
	u.attack = {"stage":"wind","left":w[2], "target":target, "kind":kind, "dir":u.face}
	u.fatigue = minf(100, u.fatigue + (15 if u.id == "xiang" else 9))
	return true

func tick_attack(u: Dictionary, dt: float) -> void:
	if u.attack.is_empty():
		return
	u.attack.left -= dt
	if u.attack.left > 0.0:
		return
	var w = WEAPONS[u.weapon]
	match u.attack.stage:
		"wind":
			u.attack.stage = "hit"
			u.attack.left = w[3]
			resolve_attack(u)
		"hit":
			u.attack.stage = "recover"
			u.attack.left = w[4]
		_:
			u.attack = {}

func resolve_attack(u: Dictionary) -> void:
	var a = u.attack
	var direction: Vector2 = a.dir
	effects.append({"p":u.p, "life":0.22, "kind":u.weapon, "dir":direction, "range":reach(u)})
	if a.kind == "gate":
		if u.p.distance_to(GATE) < 49 and phase == "defense":
			var damage = 8 if u.id == "captain" else 5
			gate = maxi(0, gate - damage)
			effects.append({"p":GATE, "life":0.74, "label":"성문 −%d" % damage,"tone":"harm"})
			sound_events.append("hit")
		return
	if a.kind == "aid":
		var patient = nearest(u.p, living(team).filter(func(m): return u != m and m.hp < m.max_hp - 9), reach(u))
		if not patient.is_empty():
			var amount = roundi(15 * (1.0 + 0.20 * u.skills.count("power")))
			patient.hp = mini(patient.max_hp, patient.hp + amount)
			effects.append({"p":patient.p, "life":0.8,"label":"+%d" % amount,"tone":"notice"})
			add_xp(u, 13)
			sound_events.append("complete")
		return
	var candidates = living(team if u.is_enemy else foes)
	if u.weapon == "활":
		arrows.append({"p":u.p, "origin":u.p, "dir":direction, "remaining":reach(u),
			"source":u, "candidates":candidates, "over":u.elevated})
		sound_events.append("bow")
		return
	sound_events.append("swing")
	var sweep = 0.53 if u.weapon == "방패·도끼" else (0.9 if u.weapon == "장병기" else 0.64)
	for enemy in candidates:
		var gap: Vector2 = enemy.p - u.p
		if gap.length() > reach(u) or enemy.elevated or not line_clear(u.p, enemy.p):
			continue
		if gap.length() > 4.0 and gap.normalized().dot(direction) < sweep:
			continue
		damage_actor(u, enemy)
		if not enemy.is_enemy or enemy.hp > 0:
			walk(enemy, direction * (9.0 if u.weapon == "방패·도끼" else 5.0))

func damage_actor(u: Dictionary, enemy: Dictionary) -> void:
	var amount = float(WEAPONS[u.weapon][1])
	if u.is_enemy:
		amount *= 0.34 if u.id != "captain" else 0.59
	if u.fatigue > 73:
		amount *= 0.76
	if u.morale < 35:
		amount *= 0.79
	amount *= 1.0 + 0.2 * u.skills.count("power")
	amount *= pow(0.8, enemy.skills.count("guard"))
	if enemy.weapon == "방패·도끼" and (enemy.p.direction_to(u.p)).dot(enemy.face) > 0.3:
		amount *= 0.72
	if not enemy.is_enemy and rally_left > 0:
		amount *= 0.83
	var dealt = maxi(1, roundi(amount))
	enemy.hp = maxi(0, enemy.hp - dealt)
	enemy.hit = 0.24
	enemy.morale = maxf(0, enemy.morale - 4)
	var lane = 0
	while lane < 3 and effects.any(func(fx): return fx.has("label") and fx.p.distance_to(enemy.p + Vector2(0, -lane * 10)) < 13 and fx.life > 0.44):
		lane += 1
	effects.append({"p":enemy.p + Vector2(0, -lane * 10), "life":0.76,"label":"−%d" % dealt,"tone":"harm" if not enemy.is_enemy else "damage"})
	sound_events.append("hit")
	strike_id += 1
	if enemy.hp == 0 and not enemy.is_enemy:
		note(ROSTER[enemy.id][0] + " 쓰러짐.")
		for ally in living(team):
			ally.morale = maxf(0, ally.morale - 12)
	elif enemy.is_enemy:
		add_xp(u, 8 if enemy.hp else 19)
		if enemy.hp == 0:
			u.morale = minf(100, u.morale + 4)

func update_arrows(dt: float) -> void:
	for arrow in arrows:
		var step = minf(arrow.remaining, 380 * dt)
		arrow.p += arrow.dir * step
		arrow.remaining -= step
		if not arrow.over and blocked(arrow.p):
			arrow.remaining = 0
			continue
		var hit = nearest(arrow.p, arrow.candidates, 12)
		if not hit.is_empty() and not hit.elevated:
			damage_actor(arrow.source, hit)
			arrow.remaining = 0
	arrows = arrows.filter(func(arrow): return arrow.remaining > 0.0)


func spawn_group(index: int) -> void:
	var group = DEFENSE_GROUPS[index]
	var lanes = [Vector2(271,25), Vector2(424,18), Vector2(104,20), Vector2(247,14)]
	for i in range(group.size()):
		var at: Vector2 = lanes[index] + Vector2(i * 27, (i % 2) * 13)
		foes.append(actor(group[i], at))
	wave = index + 1
	note("%d/4 파상 도착%s" % [wave, " — 대규모 증원" if wave == 4 else ""])
	sound_events.append("warning" if wave == 4 else "march")

func wave_warning() -> bool:
	return phase == "defense" and wave == 3 and time >= WAVE_AT[3] - 12.0

func next_arrival() -> float:
	return maxf(0, WAVE_AT[wave] - time) if phase == "defense" and wave < WAVE_AT.size() else -1.0

func tick(dt: float, movement: Vector2, aim: Vector2, attack: bool, holding: bool, rally: bool) -> void:
	if phase not in ["defense", "assault"] or not level_queue.is_empty():
		return
	dt = minf(0.05, dt)
	time += dt
	elapsed += dt
	rally_cd = maxf(0, rally_cd - dt)
	rally_left = maxf(0, rally_left - dt)
	for fx in effects:
		fx.life -= dt
	effects = effects.filter(func(f): return f.life > 0)
	if phase == "defense":
		update_defense()
	else:
		update_assault(dt)
	if phase not in ["defense", "assault"]:
		return
	for u in living(team + foes):
		u.moving = false
		u.hit = maxf(0, u.hit - dt)
		u.speech = maxf(0, u.speech - dt)
		u.speech_cd = maxf(0, u.speech_cd - dt)
		var recovery = 8.0 + 5.0 * u.skills.count("focus") + (7.0 if rally_left > 0 and not u.is_enemy else 0.0)
		u.fatigue = maxf(0, u.fatigue - recovery * dt)
		tick_attack(u, dt)
	var player = team[0]
	if player.hp == 0 or gate <= 0:
		finish(false, "유방이 쓰러졌습니다." if player.hp == 0 else "패현 성문이 무너졌습니다.")
		return
	if rally and rally_cd == 0:
		rally_cd = 15.0
		rally_left = 5.0
		for u in living(team):
			u.morale = minf(100, u.morale + 17)
			u.fatigue = maxf(0, u.fatigue - 23)
		note("집결. 사기 +17, 피로 −23.")
		sound_events.append("march")
	if not movement.is_zero_approx():
		var speed = ROSTER.liu[3] * (0.83 if player.fatigue > 73 else 1.0)
		if player.elevated:
			var new_x = clampf(player.p.x + movement.x * speed * dt, 412, 598)
			player.moving = absf(new_x - player.p.x) > 0.05
			player.p.x = new_x
			player.walk += absf(movement.x) * speed * dt
		else:
			walk(player, movement.normalized() * speed * dt)
	if player.attack.is_empty() and player.p.distance_to(aim) > 3:
		player.face = player.p.direction_to(aim)
	if attack and not holding:
		start_attack(player, aim)
	for ally in living(team.slice(1)):
		ally_ai(ally, player, dt)
	for enemy in living(foes):
		enemy_ai(enemy, player, dt)
	update_arrows(dt)
	interact(dt, holding)
	if phase == "defense" and wave == WAVE_AT.size() and living(foes).is_empty():
		enter_camp()

func update_defense() -> void:
	if time >= 6.0 and not team.any(func(u): return u.id == "xiao"):
		team.insert(2, actor("xiao", Vector2(326, 280)))
		note("소하 합류. 후열에서 부상자와 동료를 돌봅니다.")
	if wave < WAVE_AT.size() and time >= WAVE_AT[wave]:
		spawn_group(wave)
	for wound in wounds:
		if wound.state == "pending" and time >= wound.arrive:
			wound.state = "waiting"
			note(wound.name + "의 구조 표식이 나타났습니다.")
		if wound.state == "waiting" and time >= wound.end:
			wound.state = "lost"
			note(wound.name + "을 구조할 시간이 지났습니다.")

func ally_ai(u: Dictionary, player: Dictionary, dt: float) -> void:
	var p: Vector2 = u.p
	var speed: float = ROSTER[u.id][3]
	if u.weapon == "약낭":
		var threat = nearest(p, foes, 37)
		var patient = nearest(p, living(team).filter(func(m): return m != u and m.hp < m.max_hp - 12), 95)
		if u.hp < 25 or not threat.is_empty():
			u.status = "후열로 피신"
			say(u, "유방 곁으로 물러나겠소.")
			var retreat: Vector2 = player.p + Vector2(-24, 31)
			toward(u, retreat, speed, dt, 12)
		elif not patient.is_empty():
			u.status = "후열 회복"
			toward(u, patient.p, speed * 0.8, dt, 30)
			if p.distance_to(patient.p) < reach(u) - 7 and u.fatigue < 66 and start_attack(u, patient.p, "aid"):
				say(u, "상처를 보여 주시오.")
		else:
			u.status = "후열 대기"
			toward(u, player.p + Vector2(-26,32), speed, dt, 15)
			for wound in wounds:
				if phase == "defense" and wound.state == "waiting" and not wound.get("aid",false) and p.distance_to(wound.p) < 34:
					wound.aid = true
					wound.end += 18.0
					add_xp(u, 13)
					say(u, "지혈했소. 구조할 시간을 벌었소.")
		return
	if u.id == "bow" and phase == "defense":
		u.elevated = true
		u.status = "성벽 사격"
		var wall_target = nearest(p, foes, reach(u) - 6)
		if not wall_target.is_empty() and u.fatigue < 75:
			start_attack(u, wall_target.p)
			say(u, "성벽에서 엄호한다!")
		return
	var exhausted = u.fatigue > 80 or (u.status == "피로로 복귀" and u.fatigue > 38)
	var fragile = u.hp < u.max_hp * 0.35
	var bow = u.weapon == "활"
	var charging = u.id == "xiang" and not exhausted
	var leash = 39.0 if fragile else (130.0 if charging or bow else 71.0)
	if rally_left > 0:
		leash = minf(leash, 55.0)
	var enemy = nearest(player.p, foes, leash)
	if exhausted:
		u.status = "피로로 복귀"
		say(u, "숨을 돌리고 다시 나서겠소.")
	elif fragile and not bow:
		u.status = "저체력 호위"
		say(u, "더는 멀리 쫓지 않겠소.")
	else:
		u.status = "원거리 엄호" if bow else ("적 전열 돌파" if charging else "전열 호위")
	if exhausted or enemy.is_empty() or p.distance_to(player.p) > leash + 32:
		var slot = team.find(u)
		toward(u, player.p + Vector2(25 + (slot % 2) * 12, 11 + (slot % 3) * 9), speed, dt, 15)
		return
	if bow:
		if p.distance_to(enemy.p) < 69:
			toward(u, p + enemy.p.direction_to(p) * 90, speed * 0.8, dt, 0)
		elif p.distance_to(enemy.p) > reach(u) - 18 or not line_clear(p, enemy.p):
			toward(u, enemy.p, speed * 0.8, dt, 100)
	else:
		toward(u, enemy.p, speed * (1.2 if charging else 1.0), dt, reach(u) - 9.0)
	if u.p.distance_to(enemy.p) <= reach(u) - 3.0 and line_clear(u.p, enemy.p):
		if start_attack(u, enemy.p) and charging:
			say(u, "내가 저 대열을 가르겠소.")

func enemy_ai(u: Dictionary, player: Dictionary, dt: float) -> void:
	if not u.attack.is_empty():
		return
	var candidates = living(team).filter(func(m): return not m.elevated)
	var enemy = nearest(u.p, candidates, 116)
	var on_gate = phase == "defense" and enemy.is_empty()
	var target: Vector2 = GATE if on_gate else (player.p if enemy.is_empty() else enemy.p)
	if phase == "assault" and route.is_empty() and u.p.y < 109.0:
		return
	var distance_to_target: float = u.p.distance_to(target)
	if distance_to_target > (40.0 if on_gate else reach(u) - 6.0):
		toward(u, target, ROSTER[u.id][3], dt, 38.0 if on_gate else reach(u) - 7.0)
	elif on_gate or line_clear(u.p, target):
		start_attack(u, target, "gate" if on_gate else "hit")
	else:
		toward(u, target, ROSTER[u.id][3], dt, 0.0)

func enter_camp() -> void:
	phase = "camp"
	effects.clear()
	arrows.clear()
	foes.clear()
	interaction = {}
	for u in team:
		u.attack = {}
		u.elevated = false
		if u.id == "liu":
			u.weapon = "검"
	note("패현 성문 방어 완료.")

func saved_wounds() -> int:
	return wounds.filter(func(w): return w.state == "saved").size()

func heal(id: String) -> bool:
	if phase != "camp" or not healed.is_empty():
		return false
	var u = team.filter(func(unit): return unit.id == id)
	if u.is_empty():
		return false
	u = u[0]
	u.hp = mini(u.max_hp, u.hp + 67)
	u.morale = minf(100, u.morale + 18)
	u.fatigue = maxf(0, u.fatigue - 47)
	healed = id
	note(ROSTER[id][0] + " 회복.")
	return true

func draft_weights() -> Array:
	return OPTIONS[draft_plan]

func recruit(random: RandomNumberGenerator) -> bool:
	if phase != "camp" or not rolled.is_empty():
		return false
	var face = random.randi_range(1, 18)
	var total = 0
	for i in range(DRAFT.size()):
		total += draft_weights()[i]
		if face <= total:
			var id = DRAFT[i]
			var duplicate = team.any(func(u): return u.id == id)
			rolled = {"face":face,"id":id,"duplicate":duplicate,"plan":draft_plan}
			if duplicate:
				pending_bonus = "focus"
				note(ROSTER[id][0] + " 중복. 특기 ‘고른 숨’ 후보 추가.")
			else:
				team.append(actor(id, Vector2(290, 300)))
				note(ROSTER[id][0] + " 합류.")
				if id == "xiang":
					observe("xiang")
			return true
	return false

func give_bonus(id: String, perk: String) -> bool:
	if phase != "camp" or not bonus.is_empty() or perk not in ["guard", "power", pending_bonus] or not PERKS.has(perk):
		return false
	for u in team:
		if u.id == id:
			u.skills.append(perk)
			bonus = id
			note(ROSTER[id][0] + " 전투 특기: " + PERKS[perk][0])
			return true
	return false

func depart() -> bool:
	if phase != "camp" or bonus.is_empty():
		return false
	phase = "assault"
	time = 0.0
	next_patrol = 20.0
	for i in range(team.size()):
		team[i].p = Vector2(315 + (i - 1) * 27, 330 - (i % 2) * 12)
		team[i].fatigue *= 0.3
		team[i].morale = maxf(57, team[i].morale)
		team[i].face = Vector2.UP
		team[i].attack = {}
	for pos in [Vector2(221,173), Vector2(371,176), Vector2(430,183)]:
		foes.append(actor("qin", pos))
	foes.append(actor("captain", Vector2(340,63)))
	foes.append(actor("pike", Vector2(390,72)))
	note("정면 초소 또는 동쪽 측문으로 진입하세요.")
	return true

func update_assault(dt: float) -> void:
	if loading < 0.0:
		if time >= next_patrol and living(foes).size() < 7:
			next_patrol += 25.0
			foes.append(actor("qin", Vector2(63,284)))
			foes.append(actor("pike", Vector2(557,252)))
			note("야전 순찰대 도착.")
		return
	var threshold = [0.0, 11.0, 23.0, 36.0]
	if loading_group < threshold.size() and loading >= threshold[loading_group]:
		var from_left = loading_group % 2 == 0
		var origin = Vector2(113 if from_left else 538, 26)
		foes.append(actor("qin", origin))
		foes.append(actor("pike" if loading_group < 3 else "captain", origin + Vector2(26,16)))
		loading_group += 1
		note("진군 증원. 군량고 주변을 정리하세요.")
		sound_events.append("warning")
	if team[0].p.distance_to(SUPPLY) < 96 and nearest(SUPPLY, foes, 59).is_empty():
		loading += dt
	if loading >= 48.0 and living(foes).filter(func(u): return u.p.y < 112).is_empty():
		finish(true, "군량 수레가 패현으로 떠났습니다.")

func finish(victory: bool, reason: String) -> void:
	phase = "won" if victory else "lost"
	outcome = reason
	if victory:
		wins += 1
	observe(phase)
	note(reason)
