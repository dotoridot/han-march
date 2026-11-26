extends RefCounted

const PLAN = preload("res://assets/march.tres")
const Ally = preload("res://ally.gd")
const Strike = preload("res://strike.gd")
const WORLD = Vector2(640,374)
const STEP = 1.0/60.0
const ATTACK_STEPS = {"sword":42,"axe":53,"bow":58,"spear":55,"aid":52}
const DODGE_STEPS = 14
const SAVE_VERSION = 2
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
const ABILITIES = {"command":[10,5.0],"shield":[7,4.8],"cover":[8,5.5],"heal":[6,3.4],"pierce":[7,4.0]}
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
var team: Array = []
var foes: Array = []
var reserves: Array = []
var strikes: Array = []
var traces: Array = []
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
var report = ""
var tactic = ""
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
		var library = AnimationLibrary.new()
		library.add_animation("attack",Strike.clip(ATTACK_STEPS[weapon]))
		clips[weapon] = library

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
	completed.clear()
	rescue_order.clear()
	tactic = ""
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
	supply = clampi(supply+path[3],0,9)
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
	return {"uid":uid,"id":id,"p":pos,"hp":hp,"max_hp":hp,"mp":mp,"max_mp":mp,"fatigue":0.0,"face":Vector2.UP,"move":false,"step":0.0,"hit":0.0,"side":enemy,"weapon":weapon,"attack":{},"cool":{},"decision":0.0,"role":"follow","perks":perks}

func clear_battle() -> void:
	for u in team+foes:
		if not u.attack.is_empty():
			u.attack.node.queue_free()
	team.clear()
	foes.clear()
	strikes.clear()
	traces.clear()
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
		team.append(make_actor(hero_keys[i],start+Vector2((i%3)*29-14 if i else 0,(i/3)*25)))
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

func max_range(u: Dictionary) -> float:
	return HEROES[u.id][5] * (1.32 if has(u,"arch") and u.weapon=="bow" else 1.0) * (0.83 if board_mask.fog and u.weapon=="bow" else 1.0)

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
		user.cool[id] = data[1]
	, CONNECT_ONE_SHOT)
	ability.try_activate(request)
	return true

func refresh_tactic() -> void:
	tactic = ""
	if "han" in hero_keys and "fan" in hero_keys:
		tactic = "shield_cover"
	elif "xiao" in hero_keys and ("cao" in hero_keys or "xiang" in hero_keys):
		tactic = "medicine_advance"

func tactic_name() -> String:
	return {"shield_cover":"방패 엄호","medicine_advance":"약낭 돌파"}.get(tactic,"기본 대열")

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
	var direction: Vector2 = u.p.direction_to(target)
	if direction.is_zero_approx():
		direction = u.face
	direction = strike_direction(direction)
	u.face = direction
	var node = Strike.new()
	node.root_node = NodePath(".")
	node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	node.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	node.add_animation_library("",clips[u.weapon])
	host.add_child(node)
	attack_number += 1
	u.attack = {"node":node,"id":attack_number,"step":0,"frame":0,"dir":direction,"special":special,"target":target,"contact":false,"hit":{}}
	node.play("attack")
	node.advance(0)
	u.fatigue = minf(100,u.fatigue+(14 if u.weapon=="spear" else 10))
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
	var end: int = ATTACK_STEPS[u.weapon]
	if state.step>=end:
		cancel(u)
		return
	state.frame = Strike.frame_at(end,state.step)
	state.node.seek((state.step+0.01)*STEP,true)
	if state.step==Strike.phase_tick(end,3):
		contact(u)

func contact(u: Dictionary) -> void:
	if u.attack.is_empty() or u.hp<=0 or u.attack.contact:
		return
	u.attack.contact = true
	var direction: Vector2 = u.attack.dir
	var power: float = (12 if u.side else 25) + combat_rng.randi_range(-1,1)
	var distance = max_range(u)
	var targets_to_hit = alive(team if u.side else foes)
	if u.weapon == "aid":
		var patient = nearest(u.attack.target,alive(team).filter(func(a): return a!=u and a.hp<a.max_hp-4),28)
		if not patient.is_empty():
			var heal: float = 24 if has(u,"medicine") else 17
			patient.hp = minf(patient.max_hp,patient.hp+heal)
			traces.append({"p":patient.p,"life":0.45,"kind":"heal","dir":Vector2.UP})
			events.append("응급 처치")
		return
	if u.attack.special:
		power *= 1.55
	if has(u,"edge") and u.weapon in ["sword","spear"]:
		power *= 1.25
	if u.fatigue > 76:
		power *= 0.74
	traces.append({"p":u.p,"life":0.18,"kind":u.weapon,"dir":direction,"reach":distance})
	if u.weapon == "bow":
		strikes.append({"origin":u.p,"p":u.p,"dir":direction,"left":distance,"actor":u,"power":power,"attack_id":u.attack.id})
		return
	for target in targets_to_hit:
		var gap: Vector2 = target.p-u.p
		if gap.length() <= distance and (gap.length()<4 or gap.normalized().dot(direction)>=cos(sweep_angle(u))) and line_obstacle(u.p,target.p)==INF and not u.attack.hit.has(target.uid):
			u.attack.hit[target.uid] = true
			hurt(target,power,u)

func hurt(u: Dictionary, power: float, source: Dictionary = {}) -> bool:
	if u.hp<=0 or (u.id=="liu" and dodge_left>0):
		if u.id=="liu" and dodge_left>0:
			events.append("회피 성공")
		return false
	if chapter==3 and u.id in ["captain","fiction"] and gates<2:
		return false
	if has(u,"shield"):
		power *= 0.70
	if u.id=="fan" and u.role=="guard":
		power *= 0.58
		if u.cool.get("shield",0.0)<=0.0 and not source.is_empty() and u.p.distance_to(source.p)<54 and u.attack.is_empty() and use_skill(u,"shield"):
			attack(u,source.p,true)
			events.append("번쾌 방패 반격")
	u.hp = maxf(0,u.hp-power)
	u.hit = 0.17
	traces.append({"p":u.p,"life":0.55,"kind":"damage","value":roundi(power),"dir":Vector2.UP})
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
			hurt(victim,arrow.power,arrow.actor)
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
			supply = mini(9,supply+2)
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
	var use_cover = tactic=="shield_cover" and u.id=="han" and not foe.is_empty()
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
			if u.p.distance_to(foe.p)<max_range(u) and u.attack.is_empty():
				var use = "cover" if u.weapon=="bow" else "pierce"
				var boosted = (u.role=="cover" or (tactic=="medicine_advance" and u.weapon=="spear")) and use_skill(u,use)
				if boosted:
					events.append(tactic_name())
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
	time = step_number*STEP
	combat_started = true
	var player = team[0]
	dodge_recharge = maxi(0,dodge_recharge-1)
	dodge_ticks = maxi(0,dodge_ticks-1)
	for u in alive(team+foes):
		u.move = false
		u.hit = maxf(0,u.hit-dt)
		u.decision -= dt
		u.fatigue = maxf(0,u.fatigue-dt*(20 if has(u,"patience") else 11))
		u.mp = minf(u.max_mp,u.mp+dt*(3.2 if has(u,"reserve") else 2.0))
		for key in u.cool:
			u.cool[key] = maxf(0,u.cool[key]-dt)
	if dodge and dodge_recharge<=0:
		cancel(player)
		dodge_ticks = DODGE_STEPS
		dodge_recharge = 55 if has(player,"wind") else 90
		dodge_dir = movement if not movement.is_zero_approx() else player.face
	if dodge_left>0:
		walk(player,dodge_dir,300.0*dt)
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
		if skill and player.attack.is_empty() and use_skill(player,"command"):
			attack(player,aim,true)
		elif hit:
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
	if not won:
		phase = "lost"
		last_result = "%s에서 행군을 이어가지 못했습니다." % entry().name
		remember("lost")
		return
	completed.append([chapter,selected_route,field_rule])
	last_result = ["삼진 관문을 확보했습니다.","팽성에서 패했지만 들것 두 곳을 수습하고 철수했습니다.","성고에 수레가 도착했습니다.","해하의 돌파를 마쳤습니다."][chapter]
	supply = mini(9,supply+1)
	if chapter==3:
		phase = "ending"
		remember("ending")
		return
	phase = "camp"
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
	var pool = PLAN.perks.duplicate()
	var matching = pool.filter(func(perk): return perk.tag==HEROES[id][2] or hero_keys.any(func(hero): return hero!=id and HEROES[hero][2]==perk.tag))
	var item = matching[rng.randi_range(0,matching.size()-1)]
	pool.erase(item)
	offerings.append(item)
	for i in 2:
		item = pool.pop_at(rng.randi_range(0,pool.size()-1))
		offerings.append(item)

func draft_weights() -> Array:
	var results: Array = ODDS[draft_plan].duplicate()
	if mode=="history":
		results[3] += results[4]
		results[4] = 0
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
		draft_result = "%d면 · %s %s" % [face,HEROES[id][0],"중복이면 보급 +1" if id in hero_keys else "합류 예정"]
		break
	draft_done = true
	return true

func accept_candidate() -> void:
	if draft_candidate.is_empty():
		return
	if draft_candidate in hero_keys:
		supply = mini(9,supply+1)
	else:
		hero_keys.append(draft_candidate)
		names_upgrades[draft_candidate] = []
		if draft_candidate=="xiang":
			remember("fantasy")
	draft_candidate = ""
	refresh_tactic()

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

func advance(perk: String) -> bool:
	if phase!="camp" or not offerings.any(func(option): return option.id==perk):
		return false
	names_upgrades[offered_to].append(perk)
	accept_candidate()
	chapter += 1
	phase = "map"
	selected_route = -1
	return true

func checkpoint() -> Dictionary:
	var status = phase if phase!="battle" else "travel"
	return {"version":SAVE_VERSION,"phase":status,"seed":seed_value,"mode":mode,"chapter":chapter,
		"supply":supply,"route":selected_route,"board_seed":battle_seed,"field":field_rule,
		"heroes":hero_keys.duplicate(),"perks":names_upgrades.duplicate(true),"completed":completed.duplicate(true),
		"streams":[field_rng.state,reward_rng.state,draft_rng.state,combat_rng.state],
		"combat_start":combat_start_state,"rescue_order":rescue_order.duplicate(),
		"reward_nonce":reward_nonce,"draft_plan":draft_plan,"rolled":draft_done,"redrawn":rerolled,
		"draft_candidate":draft_candidate,"draft_result":draft_result,"recipient":offered_to,"result":last_result}

func restore(data: Dictionary) -> bool:
	if data.get("version",0)!=SAVE_VERSION or not data.get("phase","") in ["title","map","travel","camp","lost","ending"]:
		return false
	if not data.get("mode","") in ["history","fiction"] or data.get("chapter",-1)<0 or data.get("chapter",99)>3:
		return false
	if data.streams.size()!=4:
		return false
	new_run(data.seed,data.mode)
	phase = data.phase
	chapter = data.chapter
	supply = data.supply
	selected_route = data.route
	battle_seed = data.board_seed
	field_rule = data.field
	board_mask = {"fog":field_rule=="안개","mud":field_rule=="진흙","ridge":field_rule=="고지"}
	hero_keys = data.heroes
	names_upgrades = data.perks
	completed = data.completed
	rescue_order.assign(data.get("rescue_order",[]))
	reward_nonce = data.reward_nonce
	combat_start_state = data.combat_start
	for i in 4:
		[field_rng,reward_rng,draft_rng,combat_rng][i].state = data.streams[i]
	if phase=="travel":
		combat_rng.state = combat_start_state
	draft_plan = data.draft_plan
	draft_done = data.rolled
	rerolled = data.redrawn
	draft_candidate = data.draft_candidate
	draft_result = data.draft_result
	last_result = data.result
	if phase=="camp":
		offer_for(data.recipient)
	refresh_tactic()
	return true
