extends SceneTree

const Run = preload("res://run.gd")
var checks = 0
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func want(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		push_error(message)

func fresh() -> RefCounted:
	var game = Run.new()
	game.setup()
	game.begin()
	return game

func act(game, sec: float, held: bool = false) -> void:
	for j in range(roundi(sec/0.02)):
		var p: Vector2 = game.team[0].p
		game.tick(0.02,Vector2.ZERO,p+Vector2.UP*30,false,held,false)
		while not game.level_queue.is_empty():
			game.pick_level("power")

func test_geometry_holds() -> void:
	var g = fresh()
	var u = g.team[0]
	want(Run.GATE.y > Run.SIZE.y * 0.74, "South gate occupied only the last quarter")
	var p: Vector2 = u.p
	g.walk(u,Vector2(-160,-60))
	want(u.p.x < p.x-100 and u.p.y < p.y-40,"Open northern flanking lane")
	u.p = g.wounds[0].p
	act(g,0.42,true)
	want(g.interaction.progress > 0.2 and g.interaction.progress < 0.5,"E hold advances at target")
	act(g,0.02,false)
	want(g.interaction.is_empty() and g.wounds[0].state=="waiting","Release cancels partial work")
	want(g.effects.any(func(e): return e.get("label")=="중단"),"Cancellation feeds renderer")
	act(g,1.46,true)
	want(g.saved_wounds()==1 and g.repairs==1,"New hold starts over and completes rescue")
	want(g.effects.any(func(e): return e.get("label")=="완료"),"Completion feeds renderer")
	act(g,0.02,false)
	u.p = Run.STAIR
	act(g,1.6,true)
	want(u.elevated and u.weapon=="활","Stair hold climbs and stays latched")
	want(is_equal_approx(g.reach(u),Run.WEAPONS["활"][0]*1.27),"Wall increases range by 27%")
	act(g,0.02,false)
	act(g,0.7,true)
	want(not u.elevated and u.weapon=="검","Second E descends and restores sword")
	g.time = 91.0
	g.wave = 3
	want(g.wave_warning() and is_equal_approx(g.next_arrival(),9),"Threat warning and next wave timer")
	g.spawn_group(3)
	want(g.wave==4 and g.foes.size()==6,"The large final wave has six live attackers")

func test_weapons() -> void:
	var g = fresh()
	var p = g.team[0]
	p.p = Vector2(250,160)
	for name in ["검","방패·도끼","장병기","활","약낭"]:
		p.weapon = name
		p.attack = {}
		var stats = Run.WEAPONS[name]
		var target = Run.actor("qin",p.p+Vector2(22,0))
		g.foes = [target]
		var patient = g.team[1]
		patient.p = p.p + Vector2(23,2)
		patient.hp = 50
		var old_hp: int = target.hp
		want(g.start_attack(p,target.p,"aid" if name=="약낭" else "hit"),name+" starts")
		want(p.attack.stage=="wind" and target.hp==old_hp,name+" winds up before hit")
		g.tick_attack(p,stats[2]+0.001)
		want(p.attack.stage=="hit",name+" enters impact stage")
		if name=="활":
			want(g.arrows.size()==1 and target.hp==old_hp,"Arrow uses projectile travel")
			g.update_arrows(0.045)
		if name=="약낭":
			want(patient.hp>50,name+" supports rather than damages")
		else:
			want(target.hp<old_hp and target.hit>0,name+" changes health and hit feedback")
			want(g.effects.any(func(f): return f.has("label") and f.p.distance_to(target.p)<22),name+" supplies impact-local numbers")
		g.tick_attack(p,stats[3]+0.001)
		want(p.attack.stage=="recover" and not g.start_attack(p,target.p),name+" cannot skip recovery")
		g.tick_attack(p,stats[4]+0.001)
		want(p.attack.is_empty(),name+" recovers")
		g.effects.clear()
		g.arrows.clear()
	want(g.sound_events.has("hit") and g.sound_events.has("bow") and g.sound_events.has("complete"),"Distinct sound intents trigger")

func test_growth_and_roles() -> void:
	var g = fresh()
	act(g,6.03)
	var p = g.team[0]
	var fan = g.team[1]
	var xiao = g.team[2]
	var bow = g.team[3]
	for u in g.team:
		var h = u.hp
		g.add_xp(u,55)
		want(u.level==2 and u.skills.is_empty(),u.id+" needs a choice")
		want(g.pick_level("reach"),u.id+" receives a real upgrade")
		want(u.skills.has("reach") and g.reach(u)>Run.WEAPONS[u.weapon][0]*1.18 and u.hp==h,u.id+" upgraded range applies")
	fan.p = p.p+Vector2(28,0)
	var f = Run.actor("qin",p.p+Vector2(57,0))
	g.foes = [f]
	g.ally_ai(fan,p,0.02)
	want(fan.status=="전열 호위","Fan targets the front line when healthy")
	fan.hp = 28
	g.ally_ai(fan,p,0.02)
	want(fan.status=="저체력 호위","Fan reduces pursuit when low")
	var msg = fan.bubble
	g.say(fan,"다른 말")
	want(fan.speech>0 and fan.bubble==msg and fan.speech_cd>10,"One situational bubble per cooldown")
	xiao.p = p.p+Vector2(-24,15)
	g.ally_ai(xiao,p,0.02)
	want(xiao.status=="후열 회복","Xiao reacts to a wounded ally")
	xiao.hp = 20
	g.ally_ai(xiao,p,0.02)
	want(xiao.status=="후열로 피신","Xiao retreats under low health")
	f.p = bow.p + Vector2(0,-148)
	g.ally_ai(bow,p,0.02)
	want(bow.elevated and bow.attack.stage=="wind","Elevated bow uses long range against attackers")

func test_draft() -> void:
	var g = fresh()
	g.enter_camp()
	for id in Run.OPTIONS:
		g.draft_plan = id
		var total = 0
		for n in g.draft_weights():
			total += n
		want(total==18,"Weights remain eighteen: "+id)
	want(Run.OPTIONS.breach[4]>Run.OPTIONS.steady[4] and Run.OPTIONS.breach[0]<Run.OPTIONS.steady[0],"Breach trades regulars for Xiang")
	want(Run.OPTIONS.cover[3]>Run.OPTIONS.steady[3] and Run.OPTIONS.cover[4]==0,"Cover trades Xiang for Cao")
	var r = RandomNumberGenerator.new()
	r.seed = 45
	want(g.recruit(r) and not g.recruit(r),"Free dice works only once")
	want(g.heal("fan") and not g.heal("liu"),"Camp healing chooses one")
	want(g.give_bonus("fan","guard") and g.team[1].skills.has("guard"),"Camp skill affects selected actor")
	want(g.depart(),"Camp → next battlefield")

func sim(game, style_name: String, limit: float) -> Dictionary:
	for j in range(int(limit*50)):
		if game.phase not in ["defense","assault"]:
			return {"phase":game.phase,"time":game.elapsed,"health":game.team[0].hp}
		while not game.level_queue.is_empty():
			game.pick_level("guard" if game.level_queue[0].id=="liu" else "power")
		var p: Vector2 = game.team[0].p
		var target = p
		var threat = game.nearest(p,game.foes,360.0)
		var aim = p+Vector2.UP
		var attack = false
		var hold = false
		var desired = {}
		if game.phase == "defense":
			for w in game.wounds:
				if w.state=="waiting" and (threat.is_empty() or p.distance_to(threat.p)>99):
					desired = w
					break
			if not desired.is_empty():
				target = desired.p
				hold = p.distance_to(target)<21
			elif not threat.is_empty():
				target = threat.p if p.distance_to(threat.p)>34 else p
			else:
				target = Vector2(320,202)
		elif game.route.is_empty():
			target = Run.FRONT if style_name=="front" else Run.SIDE
			if not threat.is_empty() and p.distance_to(threat.p)<72 and p.distance_to(target)>22:
				target = threat.p if p.distance_to(threat.p)>35 else p
			hold = p.distance_to(Run.FRONT if style_name=="front" else Run.SIDE)<20
		elif p.y >= 122 or (p.y>101 and absf(p.x-(320.0 if style_name=="front" else 546.0))<34):
			var x = 320.0 if style_name=="front" else 546.0
			target = Vector2(x,146 if absf(p.x-x)>12 else 95)
		else:
			threat = game.nearest(p,game.living(game.foes).filter(func(f): return f.p.y<107),585)
			if not threat.is_empty() and (p.distance_to(threat.p)<118 or j%1000>795):
				target = threat.p if p.distance_to(threat.p)>34 else p
			else:
				target = Run.SUPPLY
			hold = game.loading<0 and p.distance_to(Run.SUPPLY)<28 and game.nearest(Run.SUPPLY,game.foes,62).is_empty()
			if game.loading>=0 and threat.is_empty() and p.distance_to(Run.SUPPLY)<45:
				target = p
		if not threat.is_empty():
			aim = threat.p
			attack = p.distance_to(aim)<55
		var change = Vector2.ZERO if hold or p.distance_to(target)<6 else p.direction_to(target)
		if game.phase=="defense" and not hold and game.blocked(p+change*12):
			var detour = Vector2(p.x + (-42 if p.x<320 else 42),p.y-8)
			change = p.direction_to(detour)
		game.tick(0.02,change,aim,attack,hold,not threat.is_empty() and p.distance_to(threat.p)<65 and game.rally_cd==0)
	return {"phase":game.phase,"time":game.elapsed,"player":game.team[0].p,"health":game.team[0].hp,
		"loading":game.loading,"foes":game.living(game.foes).map(func(e): return e.p),"gate":game.gate}

func test_full_paths() -> void:
	for route in ["front","side"]:
		var g = fresh()
		var end = sim(g,route,190)
		print("DEFENSE ",route," ",end," rescued=",g.saved_wounds())
		want(g.phase=="camp",route+" full defense reaches camp")
		if g.phase!="camp":
			continue
		g.draft_plan = "cover" if route=="front" else "breach"
		var r = RandomNumberGenerator.new()
		for seed_hint in range(1,200):
			r.seed = seed_hint
			if (r.randi_range(1,18)>14) == (route=="side"):
				r.seed = seed_hint
				break
		g.recruit(r)
		want(g.team.any(func(u): return u.id=="xiang")== (route=="side"),"Both with and without Xiang")
		g.heal("liu")
		g.give_bonus("fan","guard")
		g.depart()
		end = sim(g,route,160)
		print("ASSAULT ",route," ",end," actual=",g.route," recruit=",g.rolled," levels=",g.team.map(func(u): return [u.id,u.level]))
		want(g.phase=="won" and g.route==route,route+" full assault wins")
	var loss = fresh()
	loss.team[0].p = Vector2(312,364)
	act(loss,155.0)
	want(loss.phase=="lost" and loss.journal.has("lost"),"Undefended run actually loses")
	var reset = Run.new()
	reset.setup(loss.journal)
	want(reset.journal.has("lost") and reset.rolled.is_empty() and reset.team.all(func(u): return u.skills.is_empty()),"Loss resets run but archive survives")

func modal_checks() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.begin()
	for kind in ["pause","journal"]:
		app.rebuild_overlay(kind)
		await process_frame
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = app.sheet.get_global_rect().get_center()
		app._input(click)
		want(app.view==kind,"Inside click keeps "+kind+" open")
		click.position = Vector2.ZERO
		app._input(click)
		want(app.view.is_empty(),"Outside click closes "+kind)
	app.queue_free()
	await process_frame

func verify() -> void:
	await modal_checks()
	test_geometry_holds()
	test_weapons()
	test_growth_and_roles()
	test_draft()
	test_full_paths()
	print("Native rules ",checks-errors.size(),"/",checks)
	quit(0 if errors.is_empty() else 1)
