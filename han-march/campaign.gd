extends RefCounted

signal arrow_released(projectile: Dictionary)

const PLAN = preload("res://assets/march.tres")
const Ally = preload("res://ally.gd")
const Strike = preload("res://strike.gd")
const WORLD = Vector2(640,374)
const STEP = 1.0/60.0
const ATTACK_STEPS = {"sword":42,"axe":53,"bow":58,"spear":55,"aid":52}
const ENEMY_TIMING = {
	"guard":[30,24,"sword"],"pursuer":[26,25,"spear"],"archer":[34,25,"bow"],"captain":[33,29,"spear"],"fiction":[33,29,"spear"],
}
const ATTACK_POSES = {"sword":[0.0,0.14,0.30,0.52,0.69,0.88],"axe":[0.0,0.20,0.42,0.59,0.78,0.91]}
const DODGE_STEPS = 22
const COUNTER_STEPS = 60
const SAVE_VERSION = 2
const PROMOTION_CAP = 3
const SUPPLY_CAP = 9
const DUPLICATE_SUPPLY = 2
const HEROES = {
	"liu":["유방","검","전위",152,120,55],
	"fan":["번쾌","도끼와 방패","방패",165,88,48],
	"xiao":["소하","약낭","지원",115,95,90],
	"han":["한신","활","원거리",115,99,180],
	"cao":["조참","장병기","기동",130,102,83],
	"xiang":["항우","장병기","전위",170,102,85],
	"guard":["장수","검","전위",48,59,35],
	"pursuer":["추격병","창","기동",46,78,49],
	"archer":["초군 궁수","활","원거리",37,52,132],
	"captain":["항우","장병기","전위",245,76,73],
	"fiction":["초군 창작 지휘관","장병기","전위",225,76,73],
}
const DRAFT = ["fan","xiao","han","cao","xiang"]
const ODDS = {
	"balance":[4,5,5,3,1],
	"shield":[7,4,4,2,1],
	"lance":[3,3,3,4,5],
}
const PROMOTION = {
	"fan":["호위 중 받는 피해 감소 +6%p",0.06],
	"xiao":["응급 처치 회복량 +4",4],
	"han":["지원 사격 피해 +12%",0.12],
	"cao":["돌파 찌르기 사거리 +8",8],
	"xiang":["돌파 찌르기 피해 +18%",0.18],
}
const TACTICS = {
	"shield_cover": ["방패 엄호","한신이 지원 사격 사용"],
	"medicine_advance": ["약낭 돌파","창 장수가 돌파 찌르기 사용"],
	"royal_signal": ["왕의 신호","유방의 기세 베기 피해 +%d%%"],
	"shield_spear": ["방패와 장창","조참의 공격 피해 +%d%%"],
}
const ABILITIES = {"brace":[7,7.0],"rally":[12,8.0],"command":[10,5.0],"shield":[7,4.8],"cover":[8,5.5],"heal":[6,3.4],"pierce":[7,4.0]}
const SKILL_INFO = {
	"command":["기세 베기","강한 검격"],
	"brace":["굳건한 자세","0.9초간 받는 피해 55% 감소"],
	"rally":["숨 고르기","곁의 아군 MP 6 회복, 피로 24 감소"],
	"shield":["방패 반격","호위 중 가까운 공격을 막고 도끼로 반격"],
	"heal":["응급 처치","부상한 동료 곁에서 체력 회복"],
	"cover":["지원 사격","번쾌의 엄호 또는 먼 시위 강화 시 강한 화살"],
	"pierce":["돌파 찌르기","약낭 돌파 또는 예봉 강화 시 강한 찌르기"],
}
var player_skill = "command"
var mode = "history"
var seed_value: int
var field_rng = RandomNumberGenerator.new()
var reward_rng = RandomNumberGenerator.new()
var draft_rng = RandomNumberGenerator.new()
var combat_rng = RandomNumberGenerator.new()
var combat_start_state: int
var reward_nonce: int
var step_carry = 0.0
var step_number = 0
var uid = 0
var attack_number = 0
var barrier: Array[Rect2] = []
var chapter = 0
var phase = "title"
var supply = 3
var selected_route = -1
var battle_seed = 0
var field_rule = ""
var board_mask = {"fog":false,"mud":false,"ridge":false}
var scout_bonus = ""
var hero_keys: Array = []
var names_upgrades: Dictionary = {}
var promotions: Dictionary = {}
var team: Array = []
var foes: Array = []
var reserves: Array = []
var strikes: Array = []
var traces: Array = []
var sound_cue := ""
var sound_priority := 0
var events: Array[String] = []
var record: Array = []
var completed: Array = []
var offerings: Array = []
var offered_to = "liu"
var draft_plan = "balance"
var draft_done = false
var rerolled = false
var draft_result = ""
var draft_candidate = ""
var orders_pool = false
var ration_hero = ""
var last_stand = false
var counter_until = 0
var counter_earned = false
var report = ""
var tactics = {"lead":"","support":"","bonus":0}
var time = 0.0
var hold = 0.0
var hold_target = ""
var dodge_ticks = 0
var dodge_recharge = 0
var dodge_left: float:
	get: return dodge_ticks*STEP
var dodge_cd: float:
	get: return dodge_recharge*STEP
var dodge_dir = Vector2.ZERO
var wagon = Vector2.ZERO
var wagon_hp = 100.0
var rescued = 0
var rescue_order: Array[String] = []
var training_ticks = 0
var training_at = Vector2.ZERO
var gates = 0
var patrol = 0
var defeated = 0
var targets: Array = []
var protection = 0
var flagged = false
var host: Node
var bt: BTInstance
var board: Blackboard
var ability_box: AbilityContainer
var ability_set: Dictionary = {}
var clips: Dictionary = {}
var last_result = ""
var combat_started = false

func mount(owner: Node) -> void:
	host = Node.new()
	owner.add_child(host)
	var attributes = GameplayAttributeMap.new()
	attributes.name = "Attributes"
	host.add_child(attributes)
	ability_box = AbilityContainer.new()
	ability_box.gameplay_attribute_map_path = NodePath("../Attributes")
	host.add_child(ability_box)
	for key in ABILITIES:
		var entry = Ability.new()
		entry.tags_activation_required.assign(["mp","ready"])
		ability_box.grant(entry)
		ability_set[key] = entry
	var tree = BehaviorTree.new()
	var root = BTSelector.new()
	for name in ["rest","heal","guard","cover","fight","follow"]:
		var action = Ally.new()
		action.order = name
		root.add_child(action)
	tree.set_root_task(root)
	board = Blackboard.new()
	bt = tree.instantiate(host,board,host,host)
	for weapon in ATTACK_STEPS:
		var profile: Array = ATTACK_POSES.get(weapon,Strike.BOUNDARIES)
		var duration: int = ATTACK_STEPS[weapon]
		var impact = ceili(duration*profile[3])
		build_attack_clip(weapon,duration,impact,profile,weapon)
	for id in ENEMY_TIMING:
		for chapter_index in [0,1]:
			var impact: int = ENEMY_TIMING[id][0]+(4 if chapter_index==0 else 0)
			build_attack_clip(id+str(chapter_index),impact+ENEMY_TIMING[id][1],impact,Strike.BOUNDARIES,ENEMY_TIMING[id][2])

func build_attack_clip(key: String, duration: int, impact: int, profile: Array, weapon: String) -> void:
	var ticks = [0,ceili(impact*profile[1]/profile[3]),ceili(impact*profile[2]/profile[3]),impact,
		impact+ceili((duration-impact)*(profile[4]-profile[3])/(1.0-profile[3])),
		impact+ceili((duration-impact)*(profile[5]-profile[3])/(1.0-profile[3]))]
	var library = AnimationLibrary.new()
	library.add_animation("attack",Strike.clip(duration,ticks,weapon))
	clips[key] = [library,duration,impact,ticks]

func new_run(number: int, chosen: String) -> void:
	clear_battle()
	seed_value = number
	for entry in [[field_rng,"field"],[reward_rng,"reward"],[draft_rng,"recruit"],[combat_rng,"combat"]]:
		entry[0].seed = hash([seed_value,entry[1]])
	mode = chosen
	chapter = 0
	supply = 3
	selected_route = -1
	hero_keys = ["liu","fan","xiao"]
	names_upgrades = {"liu":[],"fan":[],"xiao":[]}
	promotions.clear()
	orders_pool = false
	ration_hero = ""
	draft_plan = "balance"
	draft_done = false
	rerolled = false
	draft_result = ""
	draft_candidate = ""
	completed.clear()
	rescue_order.clear()
	refresh_tactic()
	player_skill = "command"
	report = ""
	phase = "map"
	remember("opening")

func remember(id: String) -> void:
	if id not in record:
		record.append(id)

func entry() -> Dictionary:
	return PLAN.chapters[mini(chapter,PLAN.chapters.size()-1)]

func route_details(index: int, ticket: int) -> Dictionary:
	var seed_for_field = hash([ticket,chapter,index])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_for_field
	var weather: String = ["안개","진흙","고지"][rng.randi_range(0,2)]
	return {"seed":seed_for_field,"weather":weather,
		"opponents":maxi(3,entry().enemies+entry().routes[index][4])+(1 if chapter==3 else 0)}

func preview_route(index: int) -> Dictionary:
	var peek = RandomNumberGenerator.new()
	peek.seed = field_rng.seed
	peek.state = field_rng.state
	return route_details(index,peek.randi())

func choose_route(index: int) -> bool:
	if phase != "map" or index < 0 or index >= entry().routes.size():
		return false
	var path: Array = entry().routes[index]
	if supply + path[3] < 0:
		return false
	selected_route = index
	supply = clampi(supply+path[3],0,SUPPLY_CAP)
	var proposed = route_details(index,field_rng.randi())
	battle_seed = proposed.seed
	combat_start_state = combat_rng.state
	field_rule = proposed.weather
	board_mask = {"fog":field_rule=="안개","mud":field_rule=="진흙","ridge":field_rule=="고지"}
	phase = "travel"
	return true

func make_actor(id: String, pos: Vector2, enemy := false) -> Dictionary:
	var info: Array = HEROES[id]
	var perks: Array = names_upgrades.get(id,[])
	var hp: float = info[3] + perks.count("vigor")*30
	var mp: float = 24.0 + perks.count("reserve")*8
	var weapon = {"방패":"axe","지원":"aid","원거리":"bow","기동":"spear"}.get(info[2],"sword")
	if id in ["xiang","captain","fiction"]:
		weapon = "spear"
	uid += 1
	return {"uid":uid,"id":id,"p":pos,"hp":hp,"max_hp":hp,"mp":mp,"max_mp":mp,"fatigue":0.0,"face":Vector2.UP,"move":false,"step":0.0,"hit":0.0,"side":enemy,"weapon":weapon,"attack":{},"cool":{},"brace_time":0.0,"recoil":Vector2.ZERO,"decision":0.0,"role":"follow","perks":perks,"promotion":0 if enemy else promotion_level(id)}

func clear_battle() -> void:
	for u in team+foes:
		if not u.attack.is_empty():
			u.attack.node.queue_free()
	team.clear()
	foes.clear()
	strikes.clear()
	traces.clear()
	sound_cue = ""
	sound_priority = 0
	reserves.clear()
	events.clear()

func enter_battle() -> void:
	if phase != "travel":
		return
	clear_battle()
	remember(entry().id)
	phase = "battle"
	time = 0
	defeated = 0
	patrol = 0
	rescued = 0
	training_ticks = 0
	scout_bonus = ""
	if chapter==1:
		rescue_order.clear()
	gates = 0
	hold = 0.0
	hold_target = ""
	dodge_recharge = 0
	dodge_ticks = 0
	counter_until = 0
	counter_earned = false
	last_stand = supply==0 and "last_stand" in names_upgrades.get("liu",[])
	step_carry = 0.0
	step_number = 0
	protection = 0
	flagged = false
	combat_started = false
	wagon = Vector2(112,249)
	wagon_hp = 100
	var rng = RandomNumberGenerator.new()
	rng.seed = battle_seed
	barrier.assign([
		[Rect2(25,64,198,21),Rect2(421,64,194,21),Rect2(230,168,47,17),Rect2(365,168,48,17)],
		[Rect2(2,120,50,127),Rect2(205,84,62,29),Rect2(413,224,41,19)],
		[Rect2(18,178,53,33),Rect2(548,174,67,31),Rect2(252,162,45,28)],
		[Rect2(36,88,76,16),Rect2(212,88,208,16),Rect2(548,88,54,16),Rect2(278,190,36,16)],
	][chapter])
	var start = Vector2(310,281) if chapter != 2 else Vector2(111,279)
	for i in hero_keys.size():
		var ally = make_actor(hero_keys[i],start+Vector2((i%3)*29-14 if i else 0,(i/3)*25))
		if ally.id==ration_hero:
			ally.max_mp += 4
			ally.mp = ally.max_mp
			ally["ration_credit"] = 10
		team.append(ally)
	var offset = -30 if selected_route == 0 else 27
	targets = [
		[["flag",Vector2(320+offset,77),"관문 점령"]],
		[["wounded_a",Vector2(139+offset,131),"척후병 구조"],["wounded_b",Vector2(481+offset,173),"수송병 구조"],["exit",Vector2(324,324),"나루 철수"]],
		[],
		[["gate_a",Vector2(156+offset,132),"서쪽 방책"],["gate_b",Vector2(485+offset,117),"동쪽 방책"]],
	][chapter]
	if chapter==0:
		var event = {
			"안개":["beacon",Vector2(132,238),"봉화 켜기"],
			"진흙":["cache",Vector2(475,260),"수레에서 보급 건지기"],
			"고지":["watch",Vector2(496,137),"고지 파발 만나기"],
		}
		targets.append(event[field_rule])
	var count: int = entry().enemies + entry().routes[selected_route][4]
	for i in maxi(3,count):
		var origin = Vector2(rng.randf_range(87,553),rng.randf_range(64,157))
		var kind = ["guard","pursuer","archer"][rng.randi_range(0,2)]
		while blocked(origin): origin.y += 18
		if chapter == 2 and i >= 2:
			reserves.append([kind,origin])
		else:
			foes.append(make_actor(kind,origin,true))
	if chapter == 3:
		foes.append(make_actor("captain" if mode=="history" else "fiction",Vector2(329,56),true))
	refresh_tactic()

func alive(units: Array) -> Array:
	return units.filter(func(u): return u.hp>0)

func nearest(pos: Vector2, units: Array, max_range := INF) -> Dictionary:
	var best = {}
	for u in units:
		var distance: float = pos.distance_to(u.p)
		if distance < max_range and u.hp > 0:
			best = u
			max_range = distance
	return best

func has(u: Dictionary, id: String) -> bool:
	return id in u.perks

func max_range(u: Dictionary, special := false) -> float:
	var reach: float = HEROES[u.id][5] * (1.32 if has(u,"arch") and u.weapon=="bow" else 1.0) * (0.83 if board_mask.fog and u.weapon=="bow" else 1.0)
	if special and u.id=="cao":
		reach += PROMOTION.cao[1]*u.promotion
	return reach

func use_skill(user: Dictionary, id: String) -> bool:
	var data: Array = ABILITIES[id]
	var ability: Ability = ability_set[id]
	var request = ActivationEvent.new(ability_box)
	if user.mp >= data[0]:
		request.tags.append("mp")
	if user.cool.get(id,0.0) <= 0.0:
		request.tags.append("ready")
	if not ability.can_activate(request):
		return false
	ability.activated.connect(func(_resource,_event):
		user.mp -= data[0]
		user.cool[id] = data[1]*(0.75 if last_stand and not user.side else 1.0)
	, CONNECT_ONE_SHOT)
	ability.try_activate(request)
	return true

func player_skills() -> Array[String]:
	var skills: Array[String] = ["command"]
	var perks = names_upgrades.get("liu",[])
	if "shield" in perks: skills.append("brace")
	if "reserve" in perks: skills.append("rally")
	return skills

func cycle_skill() -> void:
	var options = player_skills()
	player_skill = options[posmod(options.find(player_skill)+1,options.size())]

func activate_player_skill(player: Dictionary, aim: Vector2) -> bool:
	if player_skill not in player_skills() or not player.attack.is_empty() or not use_skill(player,player_skill):
		return false
	match player_skill:
		"brace":
			player.brace_time = 0.9
			traces.append({"kind":"guard","p":player.p,"life":0.9,"dir":player.face})
			events.append("굳건한 자세")
		"rally":
			for ally in alive(team):
				if ally!=player and player.p.distance_to(ally.p)<=90:
					ally.fatigue = maxf(0,ally.fatigue-24)
					ally.mp = minf(ally.max_mp,ally.mp+6)
					traces.append({"kind":"rally","p":ally.p,"life":0.45,"dir":Vector2.UP})
			events.append("숨 고르기")
		_:
			attack(player,aim,true)
	return true

func resolve_tactics(heroes: Array, ranks: Dictionary) -> Dictionary:
	var lead := ""
	if "han" in heroes and "fan" in heroes:
		lead = "shield_cover"
	elif "xiao" in heroes and ("cao" in heroes or "xiang" in heroes):
		lead = "medicine_advance"
	var support := ""
	var bonus := 0
	var han_rank: int = ranks.get("han",0)
	if "liu" in heroes and "han" in heroes and han_rank>0:
		support = "royal_signal"
		bonus = 25+10*(han_rank-1)
	elif "fan" in heroes and "cao" in heroes:
		support = "shield_spear"
		bonus = 20+10*int(ranks.get("cao",0))
	return {"lead":lead,"support":support,"bonus":bonus}

func refresh_tactic() -> void:
	tactics = resolve_tactics(hero_keys,promotions)

func tactic_name() -> String:
	var names: Array[String] = []
	for id in [tactics.lead,tactics.support]:
		if not id.is_empty(): names.append(TACTICS[id][0])
	return "기본 대열" if names.is_empty() else " + ".join(names)

func tactic_effects(state: Dictionary) -> String:
	var effects: Array[String] = []
	if not state.lead.is_empty():
		effects.append("%s (%s)" % [TACTICS[state.lead][0],TACTICS[state.lead][1]])
	if not state.support.is_empty():
		effects.append("%s (%s)" % [TACTICS[state.support][0],TACTICS[state.support][1] % state.bonus])
	return "기본 대열" if effects.is_empty() else " + ".join(effects)

func walk(u: Dictionary, dir: Vector2, amount: float) -> void:
	if dir.is_zero_approx():
		return
	var proposed: Vector2 = (u.p+dir*amount).clamp(Vector2(21,32),WORLD-Vector2(20,22))
	var horizontal = Vector2(proposed.x,u.p.y)
	var vertical = Vector2(u.p.x,proposed.y)
	if not blocked(proposed,u) or dodge_ticks>0 and u.id=="liu" and not blocked(proposed):
		u.p = proposed
	elif not blocked(horizontal,u):
		u.p = horizontal
	elif not blocked(vertical,u):
		u.p = vertical
	else:
		return
	u.move = true
	u.step += amount
	if u.attack.is_empty():
		u.face = dir

func blocked(p: Vector2, actor: Dictionary = {}) -> bool:
	for wall in barrier:
		if wall.grow(5).has_point(p):
			return true
	if actor.is_empty() or actor.id=="liu":
		return false
	for peer in (foes if actor.side else team):
		if peer.uid!=actor.uid and peer.hp>0 and p.distance_squared_to(peer.p)<120.0 and p.distance_squared_to(peer.p)<actor.p.distance_squared_to(peer.p):
			return true
	return false

func line_obstacle(a: Vector2, b: Vector2) -> float:
	var nearest_progress = INF
	var span = a.distance_squared_to(b)
	if span<0.001: return nearest_progress
	for wall in barrier:
		if wall.has_point(a):
			continue
		if not wall.intersects(Rect2(a, b-a).abs().grow(1)):
			continue
		var corners = [wall.position,Vector2(wall.end.x,wall.position.y),wall.end,Vector2(wall.position.x,wall.end.y)]
		for i in 4:
			var point = Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])
			if point!=null:
				nearest_progress = minf(nearest_progress,a.distance_squared_to(point)/span)
	return nearest_progress

func toward(u: Dictionary, pos: Vector2, amount: float, stop: float) -> void:
	var gap: Vector2 = pos-u.p
	var direction = gap.normalized()
	if gap.length()<=stop:
		return
	if blocked(u.p+direction*12,u):
		for offset in [0.67,-0.67,1.30,-1.30]:
			var alternative = direction.rotated(offset)
			if not blocked(u.p+alternative*12,u):
				direction = alternative
				break
	walk(u,direction,minf(amount,maxf(0.0,gap.length()-stop)))

func strike_direction(direction: Vector2) -> Vector2:
	var octant = roundf(direction.angle()/(PI/4))
	return Vector2.from_angle(octant*(PI/4))

func sweep_angle(u: Dictionary) -> float:
	return acos(0.40 if u.weapon=="axe" else 0.67)

func attack(u: Dictionary, target: Vector2, special := false) -> bool:
	if u.hp<=0 or not u.attack.is_empty():
		return false
	if not special and not u.side and u.id=="liu" and u.weapon=="sword" and step_number<=counter_until and counter_until>0:
		special = true
		counter_until = 0
		events.append("기습 반격")
	var direction: Vector2 = u.p.direction_to(target)
	if direction.is_zero_approx():
		direction = u.face
	direction = strike_direction(direction)
	u.face = direction
	var node = Strike.new()
	node.root_node = NodePath(".")
	node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	node.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var clip: Array = clips[u.id+str(mini(chapter,1)) if u.side else u.weapon]
	node.add_animation_library("",clip[0])
	host.add_child(node)
	attack_number += 1
	u.attack = {"node":node,"id":attack_number,"step":0,"frame":0,"duration":clip[1],"impact":clip[2],"poses":clip[3],"dir":direction,"special":special,"target":target,"contact":false,"hit":{}}
	node.play("attack")
	node.advance(0)
	var strain = (14 if u.weapon=="spear" else 10)-u.get("ration_credit",0)
	u.erase("ration_credit")
	u.fatigue = minf(100,u.fatigue+strain)
	return true

func cancel(u: Dictionary) -> void:
	if not u.attack.is_empty():
		u.attack.node.queue_free()
		u.attack = {}

func step_attack(u: Dictionary) -> void:
	var state: Dictionary = u.attack
	if state.is_empty():
		return
	state.step += 1
	var end: int = state.duration
	if state.step>=end:
		cancel(u)
		return
	state.frame = Strike.frame_at(state.poses,state.step)
	state.node.seek((state.step+0.01)*STEP,true)
	if state.step==state.impact:
		contact(u)

func contact(u: Dictionary) -> void:
	if u.attack.is_empty() or u.hp<=0 or u.attack.contact:
		return
	u.attack.contact = true
	var direction: Vector2 = u.attack.dir
	var power: float = (12 if u.side else 25) + combat_rng.randi_range(-1,1)
	var distance = max_range(u,u.attack.special)
	var targets_to_hit = alive(team if u.side else foes)
	if u.weapon == "aid":
		var patient = nearest(u.attack.target,alive(team).filter(func(a): return a!=u and a.hp<a.max_hp-4),28)
		if not patient.is_empty():
			var heal: float = (24 if has(u,"medicine") else 17) + PROMOTION.xiao[1]*u.promotion
			patient.hp = minf(patient.max_hp,patient.hp+heal)
			traces.append({"p":patient.p,"life":0.45,"kind":"heal","dir":Vector2.UP})
			events.append("응급 처치")
		return
	if u.attack.special:
		power *= 1.55
		if u.id in ["han","xiang"]:
			power *= 1.0+PROMOTION[u.id][1]*u.promotion
	var supported: bool = (tactics.support=="royal_signal" and u.id=="liu" and u.attack.special) or (tactics.support=="shield_spear" and u.id=="cao")
	if supported:
		power *= 1.0+tactics.bonus/100.0
	if has(u,"edge") and u.weapon in ["sword","spear"]:
		power *= 1.25
	if last_stand and not u.side:
		power *= 1.30
	if u.fatigue > 76:
		power *= 0.74
	traces.append({"p":u.p,"life":0.18,"kind":u.weapon,"dir":direction,"reach":distance,
		"attack_id":u.attack.id,"tick":step_number,"special":u.attack.special})
	if u.weapon == "bow":
		var projectile = {"origin":u.p,"p":u.p,"dir":direction,"left":distance,"actor":u,"power":power,"attack_id":u.attack.id}
		strikes.append(projectile)
		arrow_released.emit(projectile)
		queue_cue("loose",1)
		return
	var touched := false
	var landed := false
	for target in targets_to_hit:
		var gap: Vector2 = target.p-u.p
		if gap.length() <= distance and (gap.length()<4 or gap.normalized().dot(direction)>=cos(sweep_angle(u))) and not u.attack.hit.has(target.uid):
			var barrier_at = line_obstacle(u.p,target.p)
			if barrier_at<INF:
				if not touched:
					contact_feedback("block",u.weapon,u.p.lerp(target.p,sqrt(barrier_at)),direction,u.attack.id)
				touched = true
				continue
			u.attack.hit[target.uid] = true
			touched = true
			if hurt(target,power,u,u.attack.id,direction):
				landed = true
	if supported and landed:
		events.append(TACTICS[tactics.support][0])
	if not touched:
		var wall = line_obstacle(u.p,u.p+direction*distance)
		var point: Vector2 = u.p+direction*distance*(sqrt(wall) if wall<INF else 0.7)
		contact_feedback("block" if wall<INF else "miss",u.weapon,point,direction,u.attack.id)

func queue_cue(which: String, priority: int) -> void:
	if priority>sound_priority:
		sound_priority = priority
		sound_cue = which

func contact_feedback(outcome: String, weapon: String, at: Vector2, direction: Vector2, attack_id: int) -> void:
	traces.append({"kind":outcome,"weapon":weapon,"p":at,"dir":direction,"attack_id":attack_id,"tick":step_number,
		"life":0.19 if outcome=="miss" else 0.30})
	match outcome:
		"block": queue_cue("block",5)
		"impact": queue_cue(weapon+"_impact",4)
		"evade": queue_cue("dodge",3)
		"miss": queue_cue("whiff",1)

func hurt(u: Dictionary, power: float, source: Dictionary = {}, attack_id := -1, direction := Vector2.ZERO) -> bool:
	var weapon: String = source.get("weapon","sword")
	if u.hp<=0:
		return false
	if u.id=="liu" and dodge_left>0:
		if attack_id>=0 and source.get("side",false) and not counter_earned and "ambush_counter" in u.perks:
			counter_until = step_number+COUNTER_STEPS
			counter_earned = true
		events.append("회피 성공")
		contact_feedback("evade",weapon,u.p,direction,attack_id)
		return false
	if chapter==3 and u.id in ["captain","fiction"] and gates<2:
		contact_feedback("block",weapon,u.p,direction,attack_id)
		return false
	if has(u,"shield"):
		power *= 0.70
	if u.brace_time>0:
		power *= 0.45
	if u.id=="fan" and u.role=="guard":
		power *= 0.58-PROMOTION.fan[1]*u.promotion
		if u.cool.get("shield",0.0)<=0.0 and not source.is_empty() and u.p.distance_to(source.p)<54 and u.attack.is_empty() and use_skill(u,"shield"):
			attack(u,source.p,true)
			events.append("번쾌 방패 반격")
	var guarded = u.brace_time>0 or (u.id=="fan" and u.role=="guard")
	var impulse: Vector2 = direction if not direction.is_zero_approx() else (source.p.direction_to(u.p) if not source.is_empty() else -u.face)
	var inflicted = minf(u.hp,power)
	u.hp -= inflicted
	u.hit = 0.12 if guarded else 0.17
	u.recoil = impulse*(1.7 if guarded else (4.6 if weapon=="axe" else 3.1))
	contact_feedback("block" if guarded else "impact",weapon,u.p,impulse,attack_id)
	traces.append({"p":u.p,"life":0.55,"kind":"damage","value":roundi(inflicted),"dir":Vector2.UP,"tick":step_number})
	if u.hp==0:
		cancel(u)
		if u.side:
			defeated += 1
			if u.id in ["captain","fiction"]:
				flagged = true
	return true

func move_projectiles(dt: float) -> void:
	for arrow in strikes:
		var step = minf(arrow.left,330.0*dt)
		var after: Vector2 = arrow.p+arrow.dir*step
		var blocked_at = line_obstacle(arrow.p,after)
		var victim = {}
		var hit_at = blocked_at
		var length_squared = arrow.p.distance_squared_to(after)
		for u in (team if arrow.actor.side else foes):
			if u.hp<=0: continue
			var contact_point = Geometry2D.get_closest_point_to_segment(u.p,arrow.p,after)
			var when = arrow.p.distance_squared_to(contact_point)/maxf(0.001,length_squared)
			if when<hit_at and contact_point.distance_squared_to(u.p)<169.0:
				hit_at = when
				victim = u
		if not victim.is_empty():
			hurt(victim,arrow.power,arrow.actor,arrow.attack_id,arrow.dir)
		elif blocked_at<INF:
			contact_feedback("block","bow",arrow.p.lerp(after,sqrt(blocked_at)),arrow.dir,arrow.attack_id)
		elif arrow.left<=step:
			contact_feedback("miss","bow",after,arrow.dir,arrow.attack_id)
		if hit_at<INF:
			arrow.left = 0
		arrow.left -= step
		arrow.p = after
	strikes = strikes.filter(func(a): return a.left>0.0)

func interact(player: Dictionary, dt: float, pressed: bool) -> void:
	var target = nearby(player.p)
	if not pressed or target.is_empty() or player.move:
		hold = 0
		hold_target = ""
		return
	if hold_target != target[0]:
		hold = 0
		hold_target = target[0]
	hold += dt
	if hold < 0.68:
		return
	targets.erase(target)
	hold = 0
	hold_target = ""
	match target[0]:
		"beacon":
			board_mask.fog = false
			scout_bonus = "봉화를 밝혀 활 사거리를 되찾았습니다."
			events.append(scout_bonus)
		"cache":
			supply = mini(SUPPLY_CAP,supply+2)
			scout_bonus = "수레에서 보급 2를 건졌습니다."
			events.append(scout_bonus)
		"watch":
			for ally in alive(team):
				ally.fatigue = maxf(0,ally.fatigue-32)
				ally.mp = minf(ally.max_mp,ally.mp+10)
			scout_bonus = "고지 파발의 엄호로 피로가 줄고 MP가 회복됐습니다."
			events.append(scout_bonus)
		"flag","exit": finish_battle(true)
		"wounded_a","wounded_b":
			rescued += 1
			rescue_order.append(target[0])
			if rescued==1:
				remember("pengcheng_scout" if target[0]=="wounded_a" else "pengcheng_supply")
			events.append("들것 구출 %d/2" % rescued)
		"gate_a","gate_b":
			gates += 1
			events.append("방책 개방 %d/2" % gates)

func nearby(pos: Vector2) -> Array:
	for target in targets:
		if pos.distance_to(target[1])>29:
			continue
		if target[0]=="exit" and rescued<2:
			continue
		if target[0]=="flag" and not nearest(target[1],foes,80).is_empty():
			continue
		return target
	return []

func run_ally(u: Dictionary, player: Dictionary, dt: float) -> void:
	var foe = nearest(u.p,foes,198)
	var needy = nearest(u.p,alive(team).filter(func(a): return a!=u and a.max_hp-a.hp>16),135)
	var vulnerable = u.hp<u.max_hp*0.28 or u.fatigue>83
	var guard_lead = nearest(player.p,foes,105)
	var use_cover = u.id=="han" and (tactics.lead=="shield_cover" or has(u,"arch") or u.promotion>0) and not foe.is_empty()
	if u.decision<=0:
		board.set_var("options",{"rest":vulnerable,"heal":u.id=="xiao" and not needy.is_empty(),"guard":u.id=="fan" and not guard_lead.is_empty(),"cover":use_cover,"fight":u.id!="xiao" and not foe.is_empty(),"follow":true})
		bt.update(dt)
		u.role = board.get_var("decision","follow")
		u.decision = 0.22
	var speed: float = HEROES[u.id][4]*dt
	var behind: Vector2 = player.p-player.face*24
	match str(u.role):
		"rest":
			toward(u,behind,speed,17)
		"heal":
			if needy.is_empty():
				return
			toward(u,needy.p,speed,42)
			if u.p.distance_to(needy.p)<84 and u.attack.is_empty() and use_skill(u,"heal"):
				attack(u,needy.p)
		"guard":
			if guard_lead.is_empty(): return
			toward(u,player.p.lerp(guard_lead.p,0.60),speed,8)
			if u.p.distance_to(guard_lead.p)<max_range(u):
				attack(u,guard_lead.p)
		"fight","cover":
			if foe.is_empty(): return
			if u.weapon=="bow" and u.p.distance_to(foe.p)<63:
				walk(u,foe.p.direction_to(u.p),speed)
			elif u.p.distance_to(player.p)>172:
				toward(u,player.p,speed,50)
			else:
				toward(u,foe.p,speed,max_range(u)-12)
			var attack_range = max_range(u)
			if u.p.distance_to(foe.p)>=max_range(u,true) or not u.attack.is_empty(): return
			var use = "cover" if u.weapon=="bow" else "pierce"
			var boosted = (u.role=="cover" or (u.weapon=="spear" and (tactics.lead=="medicine_advance" or has(u,"edge") or u.promotion>0))) and use_skill(u,use)
			if boosted:
				var combined = (use=="cover" and tactics.lead=="shield_cover") or (use=="pierce" and tactics.lead=="medicine_advance")
				events.append(TACTICS[tactics.lead][0] if combined else SKILL_INFO[use][0])
			if boosted or u.p.distance_to(foe.p)<attack_range:
				attack(u,foe.p,boosted)
		_:
			toward(u,behind+Vector2(24*(team.find(u)-1),15),speed,19)

func run_enemy(u: Dictionary, dt: float) -> void:
	if not u.attack.is_empty():
		return
	var player = team[0]
	var close = nearest(u.p,team,153)
	var target: Vector2 = wagon if chapter==2 and (close.is_empty() or u.id=="pursuer") else (player.p if close.is_empty() else close.p)
	var amount: float = HEROES[u.id][4]*dt*(0.88 if board_mask.ridge and u.p.y>120 else 1.0)
	if chapter==2 and target==wagon and u.p.distance_to(wagon)<24:
		wagon_hp -= 5.5*dt
		return
	toward(u,target,amount,max_range(u)-6)
	if u.p.distance_to(target)<max_range(u) and target!=wagon and line_obstacle(u.p,target)==INF:
		# Local melee attacks enter the warning phase a few ticks apart.
		if u.weapon!="bow" and foes.any(func(other):
			return other!=u and other.hp>0 and other.weapon!="bow" and not other.attack.is_empty() and other.attack.step<10 and other.attack.target.distance_to(target)<52.0):
			return
		attack(u,target)

func tick(elapsed: float, movement: Vector2, aim: Vector2, hit: bool, dodge: bool, use: bool, skill: bool) -> void:
	if phase!="battle":
		return
	step_carry += elapsed
	while step_carry+0.000001>=STEP and phase=="battle":
		step_carry = maxf(0,step_carry-STEP)
		step(movement,aim,hit,dodge,use,skill)
		dodge = false
		skill = false

func step(movement: Vector2, aim: Vector2, hit: bool, dodge: bool, use: bool, skill: bool) -> void:
	var dt = STEP
	step_number += 1
	sound_cue = ""
	sound_priority = 0
	time = step_number*STEP
	combat_started = true
	var player = team[0]
	dodge_recharge = maxi(0,dodge_recharge-1)
	dodge_ticks = maxi(0,dodge_ticks-1)
	for u in alive(team+foes):
		u.move = false
		u.hit = maxf(0,u.hit-dt)
		u.brace_time = maxf(0,u.brace_time-dt)
		u.decision -= dt
		u.fatigue = maxf(0,u.fatigue-dt*(20 if has(u,"patience") else 11))
		u.mp = minf(u.max_mp,u.mp+dt*(3.2 if has(u,"reserve") else 2.0))
		for key in u.cool:
			u.cool[key] = maxf(0,u.cool[key]-dt)
	if dodge and dodge_recharge<=0:
		cancel(player)
		dodge_ticks = DODGE_STEPS
		counter_earned = false
		dodge_recharge = 50 if has(player,"wind") else 74
		dodge_dir = movement if not movement.is_zero_approx() else player.face
	if dodge_left>0:
		walk(player,dodge_dir,(325.0 if dodge_ticks>DODGE_STEPS-10 else 92.0)*dt)
	elif not movement.is_zero_approx():
		var slow = 0.73 if board_mask.mud and player.p.y>195 else 1.0
		walk(player,movement,120.0*dt*slow)
	if player.attack.is_empty() and player.p.distance_to(aim)>2 and dodge_left<=0:
		player.face = player.p.direction_to(aim)
	if training_ticks>0:
		training_ticks -= 1
		if training_ticks==0 or dodge_ticks>0:
			remember("dodge_lesson")
		return
	if dodge_left<=0 and not use:
		var used_skill = skill and activate_player_skill(player,aim)
		if hit and not used_skill:
			attack(player,aim)
	for u in alive(team.slice(1)):
		run_ally(u,player,dt)
	for u in alive(foes):
		run_enemy(u,dt)
	for u in alive(team+foes):
		step_attack(u)
	move_projectiles(dt)
	for trace in traces:
		trace.life -= dt
	traces = traces.filter(func(t): return t.life>0.0)
	if chapter==1 and time>14.0+patrol*11 and patrol<4:
		patrol += 1
		foes.append(make_actor("pursuer",Vector2(65+patrol*105,40),true))
	if chapter==2:
		if player.p.distance_to(wagon)<106 and nearest(wagon,foes,40).is_empty():
			wagon.x = minf(556,wagon.x+dt*28)
		if not reserves.is_empty() and wagon.x>170+patrol*88:
			patrol += 1
			var unit = reserves.pop_front()
			foes.append(make_actor(unit[0],Vector2(wagon.x+52,unit[1].y+47),true))
	if player.hp<=0 or wagon_hp<=0:
		finish_battle(false)
		return
	interact(player,dt,use)
	if (chapter==2 and wagon.x>=556) or (chapter==3 and flagged):
		finish_battle(true)

func finish_battle(won: bool) -> void:
	if phase!="battle":
		return
	ration_hero = ""
	if not won:
		phase = "lost"
		last_result = "%s에서 행군을 이어가지 못했습니다." % entry().name
		remember("lost")
		return
	completed.append([chapter,selected_route,field_rule])
	last_result = ["삼진 관문을 확보했습니다.","팽성에서 패했지만 들것 두 곳을 수습하고 철수했습니다.","성고에 수레가 도착했습니다.","해하의 돌파를 마쳤습니다."][chapter]
	supply = mini(SUPPLY_CAP,supply+1)
	if chapter==3:
		phase = "ending"
		remember("ending")
		return
	phase = "camp"
	orders_pool = true
	draft_plan = "balance"
	draft_done = false
	rerolled = false
	draft_result = ""
	draft_candidate = ""
	offered_to = "liu"
	reward_nonce = reward_rng.randi()
	offer_for(offered_to)

func offer_for(id: String) -> void:
	offered_to = id
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([reward_nonce,chapter,id,selected_route,hero_keys])
	offerings.clear()
	var pool = PLAN.perks.filter(func(perk): return perk.tag!="군령")
	var matching = pool.filter(func(perk): return perk.tag==HEROES[id][2] or hero_keys.any(func(hero): return hero!=id and HEROES[hero][2]==perk.tag))
	var item = matching[rng.randi_range(0,matching.size()-1)]
	pool.erase(item)
	offerings.append(item)
	for i in 2:
		item = pool.pop_at(rng.randi_range(0,pool.size()-1))
		offerings.append(item)
	# Preserve the ordinary choices for seeds that do not draw an order.
	if orders_pool:
		var orders = PLAN.perks.filter(func(perk): return perk.tag=="군령" and perk.id not in names_upgrades["liu"])
		var index = rng.randi_range(0,pool.size()+orders.size()-1)-pool.size()
		if index>=0:
			offerings[rng.randi_range(1,2)] = orders[index]

func promotion_level(id: String) -> int:
	return promotions.get(id,0)

func duplicate_supply_gain(roll_cost := 0) -> int:
	return clampi(SUPPLY_CAP-(supply-roll_cost),0,DUPLICATE_SUPPLY)

func first_free_recruit() -> bool:
	return chapter==0 and draft_plan=="balance" and DRAFT.any(func(id):
		return id not in hero_keys and (id!="xiang" or mode=="fiction"))

func draft_weights() -> Array:
	var results: Array = ODDS[draft_plan].duplicate()
	if mode=="history":
		results[3] += results[4]
		results[4] = 0
	if first_free_recruit():
		var eligible: Array[int] = []
		var removed := 0
		for i in results.size():
			if results[i]==0: continue
			if DRAFT[i] in hero_keys:
				removed += results[i]
				results[i] = 0
			else:
				eligible.append(i)
		@warning_ignore("integer_division")
		var share = removed/eligible.size()
		for i in eligible.size():
			results[eligible[i]] += share + (1 if i<removed%eligible.size() else 0)
	return results

func change_plan(id: String) -> bool:
	if phase!="camp" or draft_done or not ODDS.has(id):
		return false
	if id!="balance" and supply<=0:
		return false
	draft_plan = id
	return true

func roll() -> bool:
	if phase!="camp" or draft_done:
		return false
	if draft_plan!="balance":
		if supply<=0: return false
		supply -= 1
	var face = draft_rng.randi_range(1,18)
	var remaining = face
	var weights = draft_weights()
	for i in weights.size():
		remaining -= weights[i]
		if remaining>0: continue
		var id = DRAFT[i]
		draft_candidate = id
		draft_result = "%d면 · %s" % [face,HEROES[id][0]]
		break
	draft_done = true
	return true

func golden_refund() -> bool:
	return "golden_eye" in names_upgrades.get("liu",[]) and not draft_candidate.is_empty() and (rerolled or draft_plan!="balance") and draft_result.get_slice("면",0).to_int() in [17,18]

func project_candidate(candidate: String, resolution: String) -> Dictionary:
	var heroes := hero_keys.duplicate()
	var ranks := promotions.duplicate()
	var gain := 0
	if candidate!="" and (candidate not in DRAFT or (candidate=="xiang" and mode!="fiction")):
		return {}
	if candidate in heroes:
		if resolution=="promote" and promotion_level(candidate)<PROMOTION_CAP:
			ranks[candidate] = promotion_level(candidate)+1
		elif resolution=="supply":
			gain = duplicate_supply_gain()
		else:
			return {}
	elif not resolution.is_empty():
		return {}
	elif not candidate.is_empty():
		heroes.append(candidate)
	return {"heroes":heroes,"promotions":ranks,"gain":gain,"tactics":resolve_tactics(heroes,ranks)}

func accept_candidate(projected: Dictionary) -> void:
	if not draft_candidate.is_empty() and draft_candidate not in hero_keys:
		names_upgrades[draft_candidate] = []
		if draft_candidate=="xiang": remember("fantasy")
	hero_keys = projected.heroes
	promotions = projected.promotions
	supply += projected.gain
	tactics = projected.tactics
	draft_candidate = ""

func redraw_reward() -> bool:
	if not draft_done or rerolled or phase!="camp" or supply<2:
		return false
	supply -= 2
	rerolled = true
	draft_done = false
	draft_plan = "balance"
	draft_result = ""
	draft_candidate = ""
	return true

func advance(perk: String, resolution := "") -> bool:
	var option_index = offerings.find_custom(func(option): return option.id==perk)
	if phase!="camp" or option_index<0:
		return false
	var projected := project_candidate(draft_candidate,resolution)
	if projected.is_empty():
		return false
	var refund = golden_refund()
	var recipient = "liu" if offerings[option_index].tag=="군령" else offered_to
	names_upgrades[recipient].append(perk)
	if resolution=="promote" and "ration_cycle" in names_upgrades["liu"]:
		ration_hero = draft_candidate
	accept_candidate(projected)
	if refund:
		supply = mini(SUPPLY_CAP,supply+1)
	chapter += 1
	phase = "map"
	selected_route = -1
	return true

func checkpoint() -> Dictionary:
	var status = phase if phase!="battle" else "travel"
	return {"version":SAVE_VERSION,"phase":status,"seed":seed_value,"mode":mode,"chapter":chapter,
		"supply":supply,"route":selected_route,"board_seed":battle_seed,"field":field_rule,
		"heroes":hero_keys.duplicate(),"perks":names_upgrades.duplicate(true),"promotions":promotions.duplicate(),"completed":completed.duplicate(true),
		"streams":[field_rng.state,reward_rng.state,draft_rng.state,combat_rng.state],
		"combat_start":combat_start_state,"rescue_order":rescue_order.duplicate(),
		"reward_nonce":reward_nonce,"draft_plan":draft_plan,"rolled":draft_done,"redrawn":rerolled,
		"draft_candidate":draft_candidate,"draft_result":draft_result,"recipient":offered_to,"result":last_result,"player_skill":player_skill,
		"orders_pool":orders_pool,"ration_hero":ration_hero}

func restore(data: Dictionary) -> bool:
	if data.get("version",0)!=SAVE_VERSION or not data.get("phase","") in ["title","map","travel","camp","lost","ending"]:
		return false
	if not data.get("mode","") in ["history","fiction"] or data.get("chapter",-1)<0 or data.get("chapter",99)>3:
		return false
	if not data.has_all(["seed","supply","route","board_seed","field","heroes","perks","completed","reward_nonce","combat_start"]):
		return false
	if not data.get("streams") is Array or data.streams.size()!=4:
		return false
	new_run(data.seed,data.mode)
	phase = data.phase
	chapter = data.chapter
	supply = clampi(data.supply,0,SUPPLY_CAP)
	selected_route = data.route
	battle_seed = data.board_seed
	field_rule = data.field
	board_mask = {"fog":field_rule=="안개","mud":field_rule=="진흙","ridge":field_rule=="고지"}
	hero_keys = data.heroes.duplicate()
	names_upgrades = data.perks.duplicate(true)
	var saved_promotions = data.get("promotions",{})
	if saved_promotions is Dictionary:
		for id in DRAFT:
			var level = saved_promotions.get(id,0)
			if id in hero_keys and level is int and level>0:
				promotions[id] = mini(level,PROMOTION_CAP)
	player_skill = data.get("player_skill","command")
	if player_skill not in player_skills(): player_skill = "command"
	completed = data.completed.duplicate(true)
	rescue_order.assign(data.get("rescue_order",[]))
	reward_nonce = data.reward_nonce
	combat_start_state = data.combat_start
	for i in 4:
		[field_rng,reward_rng,draft_rng,combat_rng][i].state = data.streams[i]
	if phase=="travel":
		combat_rng.state = combat_start_state
	var plan = data.get("draft_plan","balance")
	draft_plan = plan if ODDS.has(plan) else "balance"
	rerolled = data.get("redrawn",false)==true
	var candidate = data.get("draft_candidate","")
	var result = data.get("draft_result","")
	draft_result = result if result is String else ""
	draft_done = data.get("rolled",false)==true or not draft_result.is_empty() or candidate!=""
	orders_pool = data.get("orders_pool",false)==true
	var saved_ration = data.get("ration_hero","")
	if phase in ["map","travel"] and saved_ration in DRAFT and saved_ration in hero_keys and promotion_level(saved_ration)>0 and "ration_cycle" in names_upgrades.get("liu",[]):
		ration_hero = saved_ration
	if phase=="camp":
		var face_text = draft_result.get_slice("면",0)
		if "면" in draft_result and face_text.is_valid_int() and face_text.to_int() in range(1,19) and candidate in DRAFT and (candidate!="xiang" or mode=="fiction"):
			if draft_result.contains(HEROES[candidate][0]):
				draft_candidate = candidate
		var recipient = data.get("recipient","liu")
		offer_for(recipient if recipient in hero_keys else "liu")
	last_result = data.get("result","")
	refresh_tactic()
	return true
