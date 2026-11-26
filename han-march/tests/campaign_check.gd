extends SceneTree

const Campaign = preload("res://campaign.gd")
const Pilot = preload("res://tests/pilot.gd")
var checks: int
var failed: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func expect(result: bool, name: String) -> void:
	checks += 1
	if not result:
		failed.append(name)
		push_error(name)

func make() -> Campaign:
	var result = Campaign.new()
	result.mount(root)
	return result

func expedition(seed_value: int, mode: String, routes: Array) -> Campaign:
	var g = make()
	g.new_run(seed_value,mode)
	for i in routes.size():
		expect(g.choose_route(routes[i]),"%s chooses route %d" % [mode,i])
		g.enter_battle()
		var ids = g.foes.map(func(u): return u.id)
		if i==3:
			expect(ids.has("captain")== (mode=="history"),"History captain appears only in history")
			expect(ids.has("fiction")== (mode=="fiction"),"Fiction field has original commander")
			expect(not g.hero_keys.has("xiang") or not ids.has("captain"),"Xiang cannot face himself")
		var frames = Pilot.pilot(g,5000)
		print(mode," chapter ",i," seed ",g.battle_seed," route ",routes[i]," field ",g.field_rule,
			" phase ",g.phase," seconds ",snappedf(frames/60.0,0.01),
			" HP ",g.team[0].hp," foes ",g.alive(g.foes).size()," wagon ",g.wagon.x," rescue ",g.rescued," gates ",g.gates,
			" player ",g.team[0].p)
		expect(g.phase==("camp" if i<3 else "ending"),mode+" resolves chapter "+str(i))
		if g.phase=="camp":
			if mode=="fiction" and i==0: g.change_plan("lance")
			g.roll()
			if mode=="fiction" and i==0:
				expect(g.draft_candidate=="xiang" and not g.hero_keys.has("xiang"),"Fiction seed offers Xiang with lance weighting")
			expect(g.advance(g.offerings[0].id),"Upgrade opens map")
		elif g.phase=="lost": break
	return g

func fixed_run(batch: float, repeats: int, dodge_step: int, pause: bool = false) -> Array:
	var g = make()
	g.new_run(263,"history")
	g.choose_route(0)
	g.enter_battle()
	g.clear_battle()
	g.barrier.clear()
	g.team.append(g.make_actor("liu",Vector2(330,212)))
	g.foes.append(g.make_actor("guard",Vector2(330,193),true))
	g.attack(g.foes[0],g.team[0].p)
	var health: float = g.team[0].hp
	for _i in repeats:
		var before = g.step_number
		var active = before==dodge_step
		if pause and before==12:
			OS.delay_msec(65)
			expect(g.step_number==before,"Pause preserves attack tick")
		g.tick(batch,Vector2.ZERO,Vector2.UP,false,active,false,false)
	var result = [g.step_number,g.team[0].hp,health,g.foes[0].attack.get("frame",-1),g.events.count("회피 성공")]
	g.clear_battle()
	g.host.queue_free()
	return result

func timing_checks() -> void:
	var base = fixed_run(1.0/60,36,20)
	var half = fixed_run(1.0/30,18,20)
	var slow = fixed_run(1.0/15,9,20,true)
	var missed = fixed_run(1.0/15,9,24)
	expect(base==half and half==slow,"60/30/15 render-equivalent batches preserve steps and timely dodge")
	expect(base[1]==base[2] and base[4]==1 and missed[1]<missed[2],"One blocked contact and positive late-dodge damage")
	print("Attack replay 60/30/15 Hz ",base," ",half," ",slow," late ",missed)
	var g = make()
	g.new_run(582,"history")
	g.choose_route(0)
	g.enter_battle()
	g.clear_battle()
	g.barrier.clear()
	var player = g.make_actor("liu",Vector2(250,190))
	var enemy = g.make_actor("guard",Vector2(273,190),true)
	g.team.append(player)
	g.foes.append(enemy)
	g.attack(player,enemy.p)
	var clip = player.attack.id
	for _i in 24: g.step_attack(player)
	var hp: float = enemy.hp
	expect(player.attack.node.painted_pose==player.attack.frame and player.attack.id==clip and hp<enemy.max_hp,"Contact and raster share the exact attack step")
	g.contact(player)
	expect(enemy.hp==hp,"Duplicate callback does not apply damage twice")
	g.clear_battle()
	g.barrier.assign([Rect2(212,160,20,45)])
	var bow = g.make_actor("archer",Vector2(200,181),true)
	g.team.append(g.make_actor("liu",Vector2(247,180)))
	g.foes.append(bow)
	g.attack(bow,g.team[0].p)
	for _i in 31: g.step_attack(bow)
	expect(g.strikes.size()==1,"Bow contact starts a real projectile")
	for _i in 14: g.move_projectiles(Campaign.STEP)
	expect(g.team[0].hp==g.team[0].max_hp and g.strikes.is_empty(),"Wall stops arrow before player")
	g.clear_battle()
	g.barrier.assign([Rect2(201,120,20,78),Rect2(201,227,20,75)])
	var leader = g.make_actor("fan",Vector2(186,211))
	g.team.append(leader)
	var queue = g.make_actor("xiao",Vector2(174,211))
	g.team.append(queue)
	for _i in 60:
		g.toward(leader,Vector2(268,214),1.5,0)
		g.toward(queue,Vector2(268,214),1.5,0)
	expect(leader.p.x>221 and queue.p.x>221 and leader.p.distance_to(queue.p)>7,"Narrow obstacle gap routes queued allies without stacking")
	g.clear_battle()
	g.host.queue_free()

func checkpoint_checks() -> void:
	var g = make()
	g.new_run(9090,"fiction")
	g.choose_route(0)
	g.enter_battle()
	g.finish_battle(true)
	g.change_plan("lance")
	var paired = make()
	var before = g.checkpoint()
	expect(paired.restore(before),"New instance restores Camp with versioned state")
	var particles = RandomNumberGenerator.new()
	particles.seed = g.seed_value
	for _i in 210: particles.randi()
	g.roll()
	paired.roll()
	expect(g.draft_result==paired.draft_result and g.draft_rng.state==paired.draft_rng.state,"Effects RNG cannot change saved roll")
	var visible = g.checkpoint()
	var cfg = ConfigFile.new()
	cfg.set_value("checkpoint","state",visible)
	var path = OS.get_environment("HAN_MARCH_TEST_SAVE")
	if path.is_empty(): path = "user://roundtrip-check.cfg"
	expect(cfg.save(path)==OK,"Checkpoint writes on disk")
	var restored = make()
	cfg = ConfigFile.new()
	expect(cfg.load(path)==OK and restored.restore(cfg.get_value("checkpoint","state",{})),"Checkpoint disk round trip")
	expect(restored.draft_result==g.draft_result and restored.draft_candidate==g.draft_candidate and restored.supply==g.supply and not restored.roll(),"Committed result, cost and advanced RNG are durable")
	g.advance(g.offerings[0].id)
	restored.advance(restored.offerings[0].id)
	expect(restored.hero_keys==g.hero_keys and restored.names_upgrades==g.names_upgrades,"Same final recruit and perk after restart")
	g.choose_route(0)
	restored.choose_route(0)
	expect(restored.battle_seed==g.battle_seed,"Future field RNG continues after reload")
	print("RNG replay candidate ",visible.draft_result," board ",restored.battle_seed)
	for instance in [g,paired,restored]:
		instance.clear_battle()
		instance.host.queue_free()

func tactics_checks() -> void:
	var g = make()
	g.new_run(301,"fiction")
	g.hero_keys.append("han")
	g.choose_route(0)
	g.enter_battle()
	g.clear_battle()
	g.barrier.clear()
	var prince = g.make_actor("liu",Vector2(140,210))
	var archer = g.make_actor("han",Vector2(169,210))
	g.team = [prince,archer]
	g.foes = [g.make_actor("guard",Vector2(262,210),true)]
	g.run_ally(archer,prince,Campaign.STEP)
	expect(archer.role=="cover" and archer.mp==16 and archer.attack.special,"Shield cover switches LimboAI and spends bow MP")
	g.hero_keys.erase("han")
	g.hero_keys.append("cao")
	g.refresh_tactic()
	var lancer = g.make_actor("cao",Vector2(214,210))
	g.team.append(lancer)
	g.run_ally(lancer,prince,Campaign.STEP)
	expect(lancer.role=="fight" and lancer.mp==17 and lancer.attack.special,"Medicine advance boosts actual polearm attack")
	g.clear_battle()
	g.host.queue_free()

func verify() -> void:
	timing_checks()
	checkpoint_checks()
	tactics_checks()
	var classic = expedition(12345,"history",[0,0,1,0])
	var fantasy_seed = 1
	var rng = RandomNumberGenerator.new()
	while true:
		rng.seed = hash([fantasy_seed,"recruit"])
		if rng.randi_range(1,18)>13: break
		fantasy_seed += 1
	var fiction = expedition(fantasy_seed,"fiction",[1,1,0,1])
	print("Fiction fixture seed ",fantasy_seed," heroes ",fiction.hero_keys)
	expect(classic.completed.size()==4 and fiction.completed.size()==4,"Two playable routes reach founding")
	var g = make()
	g.new_run(245,"history")
	g.choose_route(0)
	g.enter_battle()
	var player = g.team[0]
	g.tick(0.02,Vector2.RIGHT,player.p+Vector2.RIGHT*40,false,true,false,false)
	expect(g.dodge_left>0 and g.hurt(player,20)==false and player.hp==player.max_hp,"Timely dodge avoids hit and moves")
	for i in 20: g.tick(0.02,Vector2.ZERO,player.p+Vector2.LEFT*40,false,false,false,false)
	expect(g.hurt(player,20) and player.hp<player.max_hp and g.dodge_cd>0,"Late hit hurts during dodge cooldown")
	var stable = g.battle_seed
	var first = g.field_rule
	g.new_run(245,"history")
	g.choose_route(0)
	expect(g.battle_seed==stable and g.field_rule==first,"Same seed and route reproduce conditions")
	g.new_run(245,"history")
	g.choose_route(1)
	expect(g.battle_seed!=stable and g.supply==2,"Same seed different route changes supply/condition key")
	var seen = {}
	for number in range(10,24):
		g.new_run(number,"history")
		g.choose_route(0)
		seen[g.field_rule]=true
	expect(seen.size()==3,"Different seeds yield fog, mud and ridge")
	g.enter_battle()
	g.team[0].hp = 0
	g.tick(0.02,Vector2.ZERO,Vector2.UP,false,false,false,false)
	expect(g.phase=="lost" and "lost" in g.record,"Defeat records loss")
	g.new_run(520,"fiction")
	expect(g.completed.is_empty() and g.hero_keys.size()==3 and "lost" in g.record,"Restart resets run and preserves archive")
	g.choose_route(0)
	g.enter_battle()
	g.finish_battle(true)
	expect(g.offerings.size()==3,"Three trait offers")
	var variant_offers = {}
	var variant_drafts = {}
	for number in range(10,24):
		g.new_run(number,"fiction")
		g.choose_route(0)
		g.enter_battle()
		g.finish_battle(true)
		variant_offers[str(g.offerings.map(func(item): return item.id))] = true
		g.roll()
		variant_drafts[g.draft_candidate] = true
	expect(variant_offers.size()>3 and variant_drafts.size()>2,"Other seeds vary both offers and recruitment")
	var amounts = g.draft_weights()
	expect(amounts.reduce(func(a,b): return a+b,0)==18,"Weighted die adds to 18")
	g.redraw_reward()
	g.roll()
	expect(not g.redraw_reward(),"Redraw is limited")
	expect(g.hero_keys.size()==3,"Pending draws never add two recruits")
	g.advance(g.offerings[0].id)
	expect(g.hero_keys.size()<=4,"Keeping a draw grants at most one recruit")
	print("Campaign checks ",checks-failed.size(),"/",checks)
	for backend in [g,classic,fiction]:
		backend.clear_battle()
		backend.host.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed.is_empty() else 1)
