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
			expect(g.advance(g.offerings[0].id,"supply" if g.draft_candidate in g.hero_keys else ""),"Upgrade opens map")
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
	var base = fixed_run(1.0/60,44,32)
	var half = fixed_run(1.0/30,22,32)
	var slow = fixed_run(1.0/15,11,32,true)
	var missed = fixed_run(1.0/15,11,36)
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
	for _i in bow.attack.impact: g.step_attack(bow)
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

func departure_checks() -> void:
	var profile = OS.get_environment("HAN_MARCH_PROFILE")
	if profile.is_empty():
		return
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.store_path = profile.path_join("departure-check.cfg")
	app.motion_reduced = false
	app.run_seed.text = "12345"
	app.start_historical()
	var store: String = app.store_path
	var before: Dictionary = app.game.checkpoint()
	var disk = FileAccess.get_file_as_string(store)
	expect(not disk.is_empty(),"Departure fixture has a committed map")
	app.store_path = profile.path_join("missing-directory/campaign.cfg")
	app.choose_route(0)
	expect(app.game.checkpoint()==before and app.modal_active and app.save_error,"Failed departure keeps map, supply and random streams and reports error")
	expect(FileAccess.get_file_as_string(store)==disk,"Failed departure preserves the existing checkpoint")
	app.store_path = store
	app.close_modal()
	app.choose_route(0)
	var cfg = ConfigFile.new()
	var code = cfg.load(store)
	expect(code==OK and app.game.phase=="travel" and not app.save_error and cfg.get_value("checkpoint","state",{})==app.game.checkpoint(),"Retry saves the selected route before travel")
	app.close_modal()
	app.game.clear_battle()
	app.queue_free()
	await process_frame

func battle_resume_checks() -> void:
	var test_profile = OS.get_environment("HAN_MARCH_PROFILE")
	if test_profile.is_empty():
		return
	var profile = test_profile.path_join("battle-resume")
	var folder_error = DirAccess.make_dir_recursive_absolute(profile)
	expect(folder_error==OK,"Battle resume creates its own test profile")
	if folder_error!=OK:
		return
	OS.set_environment("HAN_MARCH_PROFILE",profile)
	var scene = load("res://main.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.motion_reduced = false
	app.run_seed.text = "12345"
	app.start_historical()
	app.choose_route(0)
	var departure: Dictionary = app.checkpoint_data.duplicate(true)
	app.complete_travel()
	var game = app.game
	var cache = game.targets.filter(func(target): return target[0]=="cache")
	expect(cache.size()==1 and game.board_mask.mud,"Legacy departure seed creates the mud supply cart")
	if cache.size()==1:
		game.team[0].p = cache[0][1]
		game.interact(game.team[0],0.7,true)
		expect(game.supply==departure.supply+2,"Cart interaction awards two supplies in battle")
		app.toggle_motion()
		expect(app.checkpoint_data==departure,"Saving options keeps the departure checkpoint unchanged")
	game.clear_battle()
	app.queue_free()
	await process_frame

	app = scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.continue_run()
	game = app.game
	expect(app.motion_reduced and game.phase=="travel" and game.supply==departure.supply,"Loading an existing versioned checkpoint restores departure supply and saved option")
	app.complete_travel()
	cache = game.targets.filter(func(target): return target[0]=="cache")
	expect(cache.size()==1,"Resumed battle recreates the unclaimed cart")
	if cache.size()==1:
		game.team[0].p = cache[0][1]
		game.interact(game.team[0],0.7,true)
		expect(game.supply==departure.supply+2,"Resumed battle cannot accumulate the cart award twice")
	game.clear_battle()
	app.queue_free()
	await process_frame
	OS.set_environment("HAN_MARCH_PROFILE",test_profile)

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
	var restored = make()
	if path.is_empty():
		var profile = OS.get_environment("HAN_MARCH_PROFILE")
		if not profile.is_empty():
			path = profile.path_join("roundtrip-check.cfg")
	if path.is_empty():
		expect(restored.restore(visible),"Checkpoint restores in memory without a profile")
	else:
		expect(cfg.save(path)==OK,"Checkpoint writes in the test profile")
		cfg = ConfigFile.new()
		expect(cfg.load(path)==OK and restored.restore(cfg.get_value("checkpoint","state",{})),"Checkpoint disk round trip")
	expect(restored.draft_result==g.draft_result and restored.draft_candidate==g.draft_candidate and restored.supply==g.supply and not restored.roll(),"Committed result, cost and advanced RNG are durable")
	g.advance(g.offerings[0].id,"supply" if g.draft_candidate in g.hero_keys else "")
	restored.advance(restored.offerings[0].id,"supply" if restored.draft_candidate in restored.hero_keys else "")
	expect(restored.hero_keys==g.hero_keys and restored.names_upgrades==g.names_upgrades,"Same final recruit and perk after restart")
	g.choose_route(0)
	restored.choose_route(0)
	expect(restored.battle_seed==g.battle_seed,"Future field RNG continues after reload")
	print("RNG replay candidate ",visible.draft_result," board ",restored.battle_seed)
	for instance in [g,paired,restored]:
		instance.clear_battle()
		instance.host.queue_free()

func recruitment_checks() -> void:
	var g = make()
	for mode in ["history","fiction"]:
		g.new_run(245,mode)
		g.choose_route(0)
		g.enter_battle()
		g.finish_battle(true)
		var expected = [0,0,10,8,0] if mode=="history" else [0,0,8,6,4]
		expect(g.draft_weights()==expected,mode+" first free weights redistribute nine owned faces")
		var camp = g.checkpoint()
		var seen = {}
		var rng = RandomNumberGenerator.new()
		for seed_value in range(1,500):
			rng.seed = seed_value
			var initial = rng.state
			var face = rng.randi_range(1,18)
			if seen.has(face): continue
			seen[face] = true
			g.restore(camp)
			g.draft_rng.state = initial
			g.roll()
			var id = "han" if face<=expected[2] else ("cao" if face<=expected[2]+expected[3] else "xiang")
			var streams = g.checkpoint().streams
			expect(g.draft_result.begins_with(str(face)+"면") and g.draft_candidate==id,mode+" assigns face %d to %s" % [face,id])
			expect(g.supply==camp.supply and streams==[camp.streams[0],camp.streams[1],rng.state,camp.streams[3]],"Only the recruitment stream advances")
			if seen.size()==18: break
		expect(seen.size()==18,mode+" visits all die faces")

	g.new_run(245,"history")
	g.choose_route(0)
	g.enter_battle()
	g.finish_battle(true)
	g.hero_keys.append("han")
	expect(g.draft_weights()==[0,0,0,18,0],"The last eligible history recruit gets all 18 faces")
	g.hero_keys.append("cao")
	expect(g.draft_weights()==[4,5,5,4,0] and g.roll() and g.draft_candidate in g.hero_keys,"No eligible recruit falls back to a safe duplicate")
	g.clear_battle()
	g.host.queue_free()

func promotion_checks() -> void:
	var g = make()
	g.new_run(245,"history")
	g.choose_route(0)
	g.enter_battle()
	g.finish_battle(true)
	var camp = g.checkpoint()
	var rng = RandomNumberGenerator.new()
	for seed_value in range(1,500):
		rng.seed = seed_value
		var state = rng.state
		if rng.randi_range(1,18)<=7 and rng.randi_range(1,18)>10:
			camp.streams[2] = state
			break
	g.restore(camp)
	var before = g.supply
	expect(g.change_plan("shield") and g.draft_weights()==[7,4,4,3,0] and g.roll() and g.draft_candidate=="fan","Paid first-camp plan retains its weight and may draw a duplicate")
	var paid = g.checkpoint()
	expect(g.supply==before-1 and not g.roll() and g.supply==before-1,"Paid roll debits exactly once")
	expect(g.redraw_reward() and not g.redraw_reward() and g.draft_candidate=="" and g.draft_plan=="balance","Redraw discards the pending reward and is single use")
	expect(g.draft_rng.state==paid.streams[2] and g.supply==before-3 and g.roll() and g.draft_candidate=="cao","Replacement uses one further draw and first-camp balance weights")
	var perk: String = g.offerings[0].id
	expect(g.advance(perk) and "cao" in g.hero_keys and g.promotion_level("fan")==0,"Only the replacement joins")

	for level in range(3):
		g.restore(paid)
		g.promotions["fan"] = level
		var unchanged = g.checkpoint()
		expect(not g.advance(perk) and g.checkpoint()==unchanged,"Duplicate requires an explicit decision")
		expect(g.advance(perk,"promote") and not g.advance(perk,"promote") and g.promotion_level("fan")==level+1 and g.supply==paid.supply,"Promotion grants exactly one rank and no supply")
		expect(g.make_actor("fan",Vector2.ZERO).promotion==level+1 and g.make_actor("fan",Vector2.ZERO,true).promotion==0,"Promotion is applied to the allied actor")
	g.restore(paid)
	g.promotions["fan"] = 3
	expect(not g.advance(perk,"promote") and g.promotion_level("fan")==3,"Promotion refuses a fourth rank")
	for stores in [5,8,9]:
		g.restore(paid)
		g.supply = stores
		expect(g.advance(perk,"supply") and g.supply==mini(stores+2,9) and g.promotion_level("fan")==0,"Conversion grants up to two supplies within the cap")

	var old = paid.duplicate(true)
	old.erase("promotions")
	old.draft_result += " 중복이면 보급 +1"
	expect(g.restore(old) and g.promotion_level("fan")==0 and g.draft_candidate=="fan" and g.draft_result==old.draft_result and g.draft_rng.state==old.streams[2] and not g.roll(),"Legacy saved result stays revealed with a zero starting rank")
	old.erase("rolled")
	expect(g.restore(old) and not g.roll() and g.draft_candidate=="fan","A saved face and candidate also seal an incomplete checkpoint")
	old.erase("draft_candidate")
	expect(g.restore(old) and not g.roll() and g.draft_candidate=="" and g.advance(perk) and g.supply==old.supply,"Incomplete result lets the march proceed without re-rolling or granting a reward")
	old.erase("draft_result")
	old["redrawn"] = true
	old.draft_plan = "balance"
	expect(g.restore(old) and g.roll() and not g.redraw_reward() and g.supply==old.supply,"Legacy paid redraw can complete after restart without another redraw charge")
	g.restore(paid)
	g.promotions["fan"] = 3
	var promoted = g.checkpoint()
	expect(g.restore(promoted) and g.promotion_level("fan")==3,"Promotion survives restoration")
	g.new_run(245,"history")
	expect(g.promotion_level("fan")==0,"A new run resets promotion ranks")
	g.clear_battle()
	g.host.queue_free()

func promotion_effect_checks() -> void:
	var g = make()
	g.new_run(245,"fiction")
	g.choose_route(0)
	g.enter_battle()
	g.clear_battle()
	g.barrier.clear()
	g.board_mask.fog = false
	var state = g.combat_rng.state
	for id in Campaign.DRAFT:
		var outcomes := []
		for level in [0,1]:
			g.combat_rng.state = state
			g.promotions[id] = level
			var actor = g.make_actor(id,Vector2(300,200))
			var target = g.make_actor("guard",Vector2(390 if id=="cao" else 345,200),true)
			target.hp = 100
			target.max_hp = 100
			var patient = g.make_actor("liu",Vector2(345,200))
			patient.hp = 50
			g.team = [patient,actor]
			g.foes = [target]
			actor.role = "guard"
			if id=="fan":
				g.hurt(actor,100)
				outcomes.append(actor.hp)
			else:
				g.attack(actor,patient.p if id=="xiao" else target.p,true)
				g.contact(actor)
				match id:
					"xiao": outcomes.append(patient.hp)
					"han": outcomes.append(g.strikes[0].power)
					_: outcomes.append(target.max_hp-target.hp)
			g.clear_battle()
		match id:
			"fan": expect(is_equal_approx(outcomes[1]-outcomes[0],6.0),"Fan takes six percentage points less damage while guarding")
			"xiao": expect(is_equal_approx(outcomes[1]-outcomes[0],4.0),"Xiao restores four more HP")
			"han": expect(is_equal_approx(outcomes[1],outcomes[0]*1.12),"Han fires stronger special arrows")
			"cao": expect(outcomes[0]==0 and outcomes[1]>0,"Cao's special reaches a target outside the base spear range")
			"xiang": expect(is_equal_approx(outcomes[1],outcomes[0]*1.18),"Xiang's special strike deals more damage")
	g.host.queue_free()

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

func tactic_hit(heroes: Array, ranks: Dictionary, id: String, skill: bool) -> Dictionary:
	var g = make()
	g.new_run(301,"history")
	g.hero_keys = heroes
	g.promotions = ranks
	g.choose_route(0)
	g.enter_battle()
	g.clear_battle()
	g.barrier.clear()
	var player = g.make_actor("liu",Vector2(210,210))
	var enemy = g.make_actor("guard",Vector2(260,210),true)
	enemy.hp = 1000.0
	g.team = [player]
	g.foes = [enemy]
	if id=="cao":
		player.p.x -= 90
		g.team.append(g.make_actor("cao",Vector2(214,210)))
	for frame in 32:
		g.tick(Campaign.STEP,Vector2.ZERO,enemy.p,id=="liu" and frame==0,false,false,skill and frame==0)
	var outcome = {"damage":1000.0-enemy.hp,"events":g.events.duplicate()}
	g.clear_battle()
	g.host.queue_free()
	return outcome

func support_tactics_checks() -> void:
	var royals = ["liu","fan","han","cao"]
	var normal = tactic_hit(royals,{},"liu",true)
	var first = tactic_hit(royals,{"han":1},"liu",true)
	var second = tactic_hit(royals,{"han":2},"liu",true)
	expect(normal.damage>0 and is_equal_approx(first.damage,normal.damage*1.25) and is_equal_approx(second.damage,normal.damage*1.35),"Han's first rank activates and second rank strengthens Liu's special hit")
	expect(first.events.count("왕의 신호")==1 and "방패와 장창" not in first.events,"One support tactic applies once on the special hit")
	expect(tactic_hit(royals,{"han":1},"liu",false).damage==tactic_hit(royals,{},"liu",false).damage,"Royal signal does not boost a regular sword attack")
	var regular = tactic_hit(["liu","cao"],{},"cao",false)
	var regular_promoted = tactic_hit(["liu","cao"],{"cao":1},"cao",false)
	var joined = tactic_hit(royals,{},"cao",false)
	var promoted = tactic_hit(royals,{"cao":1},"cao",false)
	var overridden = tactic_hit(royals,{"han":1,"cao":1},"cao",false)
	expect(regular.damage>0 and regular_promoted.damage>0 and is_equal_approx(joined.damage,regular.damage*1.20) and is_equal_approx(promoted.damage,regular_promoted.damage*1.30),"Fan and Cao unlock a 20 percent spear hit bonus and Cao promotion raises it")
	expect(is_equal_approx(overridden.damage,regular_promoted.damage) and "방패와 장창" not in overridden.events,"A promoted Han suppresses the competing support bonus")

	var g = make()
	g.new_run(245,"history")
	g.phase = "camp"
	g.offer_for("liu")
	var fresh = g.checkpoint()
	if not g.has_method("project_candidate"):
		expect(false,"Campaign is missing pure draft projections")
	else:
		for id in ["cao","han"]:
			var joined_roster = g.project_candidate(id,"")
			expect(g.checkpoint()==fresh,"Roster projection preserves checkpoint and all four streams")
			g.draft_candidate = id
			expect(g.advance(g.offerings[0].id) and g.hero_keys==joined_roster.heroes and g.tactics==joined_roster.tactics,"Joining commits the projected roster and tactics for "+id)
			g.phase = "camp"
			g.draft_candidate = id
			var pending = g.checkpoint()
			var upgraded = g.project_candidate(id,"promote")
			var converted = g.project_candidate(id,"supply")
			expect(g.checkpoint()==pending and converted.tactics==g.tactics and converted.promotions==g.promotions,"Duplicate projections preserve streams and conversion preserves tactics")
			expect(g.advance(g.offerings[0].id,"promote") and g.tactics==upgraded.tactics and g.promotions==upgraded.promotions,"Promotion commits projected tactics and rank for "+id)
			var committed = g.checkpoint()
			expect(g.restore(committed) and g.tactics==upgraded.tactics and g.checkpoint()==committed,"Checkpoint derives the same bonus without adding persisted tactic data")
			expect(g.restore(fresh),"Restore clean camp after projection")
		expect(g.project_candidate("xiang","").is_empty(),"History rejects a hypothetical Xiang recruit")
	g.host.queue_free()

func opening_path(seed_value: int, route: int) -> Dictionary:
	var g = make()
	g.new_run(seed_value,"history")
	var proof = g.preview_route(route)
	var stream = g.field_rng.state
	g.preview_route(1-route)
	expect(g.field_rng.state==stream,"Preview does not spend the field RNG")
	g.choose_route(route)
	g.enter_battle()
	expect(proof.weather==g.field_rule and proof.opponents==g.foes.size(),"Forecast matches real first battle")
	var squad = g.foes.map(func(enemy): return enemy.id)
	var consequence = g.targets[1][0]
	var stores = g.supply
	Pilot.pilot(g,4500)
	var offer = g.offerings.map(func(perk): return perk.id)
	var result = {"seed":seed_value,"route":route,"weather":proof.weather,"squad":squad,
		"event":consequence,"stores_at_entry":stores,"phase":g.phase,"perk_choices":offer}
	g.clear_battle()
	g.host.queue_free()
	return result

func diversity_checks() -> void:
	var one = opening_path(12345,0)
	var alternate = opening_path(12345,1)
	expect(one.squad.size()!=alternate.squad.size() and one.stores_at_entry!=alternate.stores_at_entry,"Same seed route changes playable enemy count and supply")
	var other = {}
	for candidate in range(12500,12508):
		other = opening_path(candidate,0)
		if other.phase=="camp" and one.phase=="camp" and other.event!=one.event and other.perk_choices!=one.perk_choices:
			break
	expect(one.phase=="camp" and other.phase=="camp" and one.squad!=other.squad and one.event!=other.event and one.perk_choices!=other.perk_choices,"Two worked history seeds change deployed enemies, optional event and actual growth offers")
	print("Opening paths ",JSON.stringify([one,alternate,other]))
	var g = make()
	g.new_run(12345,"history")
	g.choose_route(0)
	g.enter_battle()
	var option = g.targets[1]
	var before = g.supply
	g.team[0].p = option[1]
	g.interact(g.team[0],0.70,true)
	expect(g.field_rule=="진흙" and g.supply==before+2 and not g.scout_bonus.is_empty(),"Muddy salvage is an actionable supply reward")
	g.clear_battle()
	g.host.queue_free()

func verify() -> void:
	timing_checks()
	await departure_checks()
	await battle_resume_checks()
	checkpoint_checks()
	recruitment_checks()
	promotion_checks()
	promotion_effect_checks()
	tactics_checks()
	support_tactics_checks()
	diversity_checks()
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
	var defeated = expedition(fantasy_seed,"fiction",[1])
	expect(defeated.hero_keys.has("xiang") and defeated.names_upgrades.values().any(func(list): return not list.is_empty()),"Defeat fixture run has a recruit and a perk to reset")
	defeated.choose_route(0)
	defeated.enter_battle()
	defeated.team[0].hp = 0
	defeated.tick(Campaign.STEP,Vector2.ZERO,Vector2.UP,false,false,false,false)
	expect(defeated.phase=="lost","A second-chapter loss ends the advanced run")
	defeated.new_run(520,"history")
	expect(defeated.hero_keys==["liu","fan","xiao"] and defeated.supply==3 and defeated.names_upgrades.values().all(func(list): return list.is_empty()),"New march drops recruited heroes, supplies and perks")
	expect(defeated.chapter==0 and defeated.completed.is_empty() and defeated.record.has("lost") and defeated.record.has("fantasy"),"New march resets the route and retains discovered stories")
	defeated.choose_route(0)
	defeated.enter_battle()
	Pilot.pilot(defeated,5000)
	expect(defeated.phase=="camp" and defeated.draft_result.is_empty() and defeated.roll(),"First camp in restarted march gets a fresh free roll")
	var g = make()
	g.new_run(245,"history")
	g.choose_route(0)
	g.enter_battle()
	var player = g.team[0]
	g.tick(0.02,Vector2.RIGHT,player.p+Vector2.RIGHT*40,false,true,false,false)
	expect(g.dodge_left>0 and g.hurt(player,20)==false and player.hp==player.max_hp,"Timely dodge avoids hit and moves")
	for i in 24: g.tick(0.02,Vector2.ZERO,player.p+Vector2.LEFT*40,false,false,false,false)
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
	g.advance(g.offerings[0].id,"supply" if g.draft_candidate in g.hero_keys else "")
	expect(g.hero_keys.size()<=4,"Keeping a draw grants at most one recruit")
	print("Campaign checks ",checks-failed.size(),"/",checks)
	for backend in [g,classic,fiction,defeated]:
		backend.clear_battle()
		backend.host.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed.is_empty() else 1)
