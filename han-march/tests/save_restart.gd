extends SceneTree

const Scene = preload("res://main.tscn")
const Campaign = preload("res://campaign.gd")
const Pilot = preload("res://tests/pilot.gd")

func _initialize() -> void:
	call_deferred("verify")

func commit_failures(app) -> bool:
	var game = app.game
	var camp: Dictionary = game.checkpoint()
	var path: String = app.store_path
	var broken = path.get_base_dir().path_join("missing-subdirectory/campaign.cfg")
	for option in [["xiang",""],["fan","promote"],["fan","supply"]]:
		var fixture = camp.duplicate(true)
		fixture.mode = "fiction"
		fixture.rolled = true
		fixture.draft_candidate = option[0]
		fixture.draft_result = "1면 · %s" % Campaign.HEROES[option[0]][0]
		game.restore(fixture)
		app.show_phase()
		if option[1]!="":
			app.choose_draft_resolution(option[1])
		if not app.save():
			return false
		var before: Dictionary = game.checkpoint()
		var record: Array = game.record.duplicate()
		var bytes = FileAccess.get_file_as_string(path)
		var perk: String = game.offerings[0].id
		var expected = game.supply+2 if option[1]=="supply" else game.supply
		app.store_path = broken
		app.choose_perk(perk)
		if not app.modal_active or game.checkpoint()!=before or game.record!=record or FileAccess.get_file_as_string(path)!=bytes:
			push_error("Failed confirmation changed pending reward, chronicle, cost or checkpoint")
			return false
		app.close_modal()
		app.store_path = path
		app.choose_perk(perk)
		app.choose_perk(perk)
		var saved = ConfigFile.new()
		if saved.load(path)!=OK or saved.get_value("checkpoint","state").phase!="map" or game.phase!="map" or game.supply!=expected:
			push_error("Retried confirmation did not persist exactly one reward")
			return false
		if ("xiang" in game.hero_keys)!=(option[0]=="xiang") or game.promotion_level("fan")!=(1 if option[1]=="promote" else 0) or game.names_upgrades["liu"]!=[perk] or game.record.has("fantasy")!=(option[0]=="xiang"):
			push_error("Retried confirmation added a second reward or omitted the selected reward")
			return false
		game.record = record
	game.restore(camp)
	app.show_phase()
	app.save()
	app.store_path = broken
	app.perform_redraw()
	if not app.modal_active or game.checkpoint()!=camp:
		push_error("Failed redraw did not restore its right, candidate and cost")
		return false
	app.close_modal()
	app.store_path = path
	app.perform_redraw()
	app.perform_redraw()
	if not game.rerolled or game.draft_done or game.supply!=camp.supply-2 or game.draft_rng.state!=camp.streams[2]:
		push_error("Redraw retry did not charge once without rolling")
		return false
	print("Join, promotion, conversion and redraw: write failure rolls back; retry commits once")
	return true

func tactics_restart(app, mode: String) -> bool:
	var game = app.game
	var id = "cao" if OS.get_environment("HAN_MARCH_TACTIC_HERO")=="cao" else "han"
	var has_projection: bool = game.has_method("project_candidate")
	var signal_name = "왕의 신호"
	var spear_name = "방패와 장창"
	var effect = signal_name+" (유방의 기세 베기 피해 +25%)" if id=="han" else spear_name+" (조참의 공격 피해 +30%)"
	if mode=="tactics-write":
		app.run_seed.text = "12345"
		app.start_historical()
		app.choose_route(0)
		app.complete_travel()
		Pilot.pilot(game,5000)
		if game.phase!="camp":
			return false
		var camp: Dictionary = game.checkpoint()
		camp.heroes.append_array(["han","cao"])
		camp.perks["han"] = []
		camp.perks["cao"] = []
		camp.rolled = true
		camp.recipient = "fan"
		camp.draft_candidate = id
		camp.draft_result = "1면 · %s" % Campaign.HEROES[id][0]
		if not game.restore(camp):
			return false
		var projected_effect: String = game.tactic_effects(game.project_candidate(id,"promote").tactics) if has_projection else ""
		app.show_phase()
		app.choose_draft_resolution("promote")
		app.choose_perk(game.offerings[0].id)
		if game.checkpoint().streams!=camp.streams or game.supply!=camp.supply:
			return false
		if has_projection and game.tactic_effects(game.tactics)!=projected_effect:
			return false
	else:
		app.continue_run()
	if game.phase!="map" or game.promotion_level(id)!=1:
		return false
	var actual_effect: String = game.tactic_effects(game.tactics) if has_projection else game.tactic_name()
	var proof = {"effect":actual_effect,"ranks":game.promotions.duplicate(),"heroes":game.hero_keys.duplicate(),
		"streams":game.checkpoint().streams.map(func(state): return str(state)),"supply":game.supply,"chapter":game.chapter}
	if not game.choose_route(0):
		return false
	game.enter_battle()
	# Place one enemy in range of the attack under test, away from other allies.
	game.barrier.clear()
	var player: Dictionary = game.team[0]
	var enemy: Dictionary = game.foes[0]
	player.p = Vector2(210,210)
	for ally in game.team.slice(1): ally.p = Vector2(100,350)
	for foe in game.foes.slice(1): foe.p = Vector2(580,50)
	enemy.p = Vector2(250,210)
	enemy.hp = 1000.0
	if id=="cao":
		var cao: Dictionary = game.team.filter(func(unit): return unit.id=="cao")[0]
		cao.p = Vector2(210,210)
		player.p = Vector2(160,330)
	for frame in 32:
		game.tick(Campaign.STEP,Vector2.ZERO,enemy.p,false,false,false,id=="han" and frame==0)
	proof["frames"] = game.step_number
	proof["damage"] = 1000.0-enemy.hp
	proof["royal_hits"] = game.events.count(signal_name)
	proof["spear_hits"] = game.events.count(spear_name)
	print(JSON.stringify(proof))
	# The seeded first contact rolls base power 26. Both attacks use the 1.55 special multiplier.
	var expected_damage = 26.0*1.55*(1.25 if id=="han" else 1.30)
	if actual_effect!="방패 엄호 (한신이 지원 사격 사용) + "+effect or proof.frames!=32 or not is_equal_approx(proof.damage,expected_damage):
		return false
	if proof.royal_hits!=(1 if id=="han" else 0) or proof.spear_hits!=(1 if id=="cao" else 0):
		return false
	return AudioServer.is_bus_mute(0)

func order_rng_state(first: int, second := 0) -> int:
	var rng = RandomNumberGenerator.new()
	for seed_value in range(1,5000):
		rng.seed = seed_value
		var state = rng.state
		if rng.randi_range(1,18)==first and (second==0 or rng.randi_range(1,18)==second):
			return state
	push_error("No matching 18-face fixture")
	return 0

func order_expect(result: bool, purpose: String) -> bool:
	if not result:
		push_error(purpose)
	return result

func order_position(game) -> void:
	game.barrier.clear()
	game.team[0].p = Vector2(210,210)
	for ally in game.team.slice(1): ally.p = Vector2(90,350)
	for foe in game.foes.slice(1): foe.p = Vector2(580,50)
	game.foes[0].p = Vector2(210,178)
	game.foes[0].hp = 1000
	game.foes[0].max_hp = 1000

func order_counter(game) -> bool:
	var no_order: Dictionary = game.checkpoint()
	for scenario in ["no-order","start","hit","expires","command-first","overlap"]:
		var departure = no_order.duplicate(true)
		if scenario!="no-order":
			departure.perks.liu.append("ambush_counter")
		game.restore(departure)
		game.enter_battle()
		order_position(game)
		var player: Dictionary = game.team[0]
		player.p = Vector2(17,216)
		var foe: Dictionary = game.make_actor("guard",Vector2(44,216),true)
		foe.hp = 1000
		foe.max_hp = 1000
		game.team.resize(1)
		game.foes.assign([foe])
		game.attack(foe,player.p)
		var impact: int = foe.attack.impact
		var dodge_frame = impact-18
		var late: Dictionary = {}
		if scenario=="overlap":
			late = game.make_actor("guard",foe.p,true)
			game.attack(late,player.p)
			game.step_attack(late)
			game.foes.append(late)
		# The wall holds one dodge within contact range. The other dodge exits the sweep.
		for frame in dodge_frame+Campaign.DODGE_STEPS+1:
			var dodge = frame==dodge_frame
			var movement = Vector2.DOWN if scenario=="start" else Vector2.LEFT
			game.tick(Campaign.STEP,movement if dodge else Vector2.ZERO,foe.p,false,dodge,false,false)
		var received = game.events.has("회피 성공")
		if not order_expect(received==(scenario!="start"),"Counter fixture distinguishes a successful dodge from movement alone: "+scenario):
			return false
		if scenario=="overlap":
			if not order_expect(game.events.count("회피 성공")==2 and game.get("counter_until")==impact-1+60,"Two live contacts in one dodge arm once, at the first tick"):
				return false
			game.cancel(late)
			game.foes.erase(late)
		if scenario=="expires":
			# Keep the first foe out of range while the 60-step window expires.
			foe.p = Vector2(530,130)
			for frame in 60:
				game.tick(Campaign.STEP,Vector2.ZERO,Vector2.UP,false,false,false,false)
			foe.p = player.p+Vector2.UP*22
		if scenario=="command-first":
			game.tick(Campaign.STEP,Vector2.ZERO,foe.p,true,false,false,true)
			if not order_expect(player.attack.special and is_equal_approx(player.cool.command,5.0) and not game.events.has("기습 반격"),"Simultaneous command wins and keeps its normal cost"):
				return false
			for frame in 42:
				game.tick(Campaign.STEP,Vector2.ZERO,foe.p,false,false,false,false)
		if scenario in ["start","command-first"]:
			foe.p = player.p+Vector2.UP*22
		if scenario=="command-first":
			game.cancel(foe)
		var before_mp: float = player.mp
		var before_cool: float = player.cool.get("command",0.0)
		var boosted = scenario in ["hit","command-first","overlap"]
		game.tick(Campaign.STEP,Vector2.ZERO,foe.p,true,false,false,false)
		if not order_expect(not player.attack.is_empty() and player.attack.special==boosted and player.mp>=before_mp and player.cool.get("command",0.0)<=before_cool and game.events.count("기습 반격")==int(boosted),"Only the first eligible normal sword entry spends an earned counter: "+scenario):
			return false
		var attack: Dictionary = player.attack
		var clone = RandomNumberGenerator.new()
		clone.state = game.combat_rng.state
		var damage: float = (25+clone.randi_range(-1,1))*(1.55 if boosted else 1.0)
		var hp: float = foe.hp
		for frame in attack.impact-1:
			game.tick(Campaign.STEP,Vector2.ZERO,foe.p,false,false,false,false)
		game.contact(player)
		if not order_expect(is_equal_approx(hp-foe.hp,damage) and attack.hit.size()==1,"Counter contact %s: damage %.2f, expected %.2f, targets %d" % [scenario,hp-foe.hp,damage,attack.hit.size()]):
			return false
		for frame in 22:
			game.tick(Campaign.STEP,Vector2.ZERO,foe.p,false,false,false,false)
		game.tick(Campaign.STEP,Vector2.ZERO,foe.p,true,false,false,false)
		if not order_expect(not player.attack.is_empty() and not player.attack.special,"Spent/expired counter does not buff the following attack: "+scenario):
			return false
	return true

func order_camp(app, camp: Dictionary) -> bool:
	var game = app.game
	var legacy = camp.duplicate(true)
	legacy.erase("orders_pool")
	legacy.erase("ration_hero")
	game.restore(legacy)
	if not order_expect(game.offerings.all(func(perk): return perk.tag!="군령"),"Legacy camp retains its original choices"):
		return false
	var names: Array[String] = []
	for nonce in range(1,80):
		var fixture = camp.duplicate(true)
		fixture.reward_nonce = nonce
		fixture.recipient = "fan"
		game.restore(fixture)
		var order = game.offerings.filter(func(perk): return perk.tag=="군령")
		if order.is_empty():
			continue
		var perk: String = order[0].id
		if perk in names:
			continue
		names.append(perk)
		app.show_phase()
		var streams: Array = game.checkpoint().streams
		app.choose_perk(perk)
		if not order_expect(game.phase=="map" and game.names_upgrades.liu==[perk] and game.names_upgrades.fan.is_empty() and game.checkpoint().streams==streams,"Order is picked from the ordinary camp choices and stored once for the whole army: "+perk):
			return false
	if not order_expect(names.size()==4,"Four distinct orders occur in the seeded camp pool"):
		return false
	var path: String = app.store_path
	for entry in [[17,"balance",0,0], [16,"shield",0,-1], [17,"shield",0,0], [18,"lance",0,0], [18,"balance",16,-2], [16,"balance",18,-1]]:
		var fixture = camp.duplicate(true)
		fixture.perks.liu.append("golden_eye")
		fixture.streams[2] = order_rng_state(entry[0],entry[2])
		game.restore(fixture)
		app.show_phase()
		app.change_odds(entry[1])
		var before: Dictionary = game.checkpoint()
		app.store_path = path.get_base_dir().path_join("missing-subdirectory/campaign.cfg")
		app.perform_roll()
		if not order_expect(game.checkpoint()==before and app.modal_active,"Failed roll does not charge, reveal, or consume an RNG result"):
			return false
		app.close_modal()
		app.store_path = path
		app.perform_roll()
		if not order_expect(game.draft_result.begins_with("%d면" % entry[0]) and game.supply==camp.supply-int(entry[1]!="balance"),"Actual 18-face draw determines future refund; the roll charges upfront"):
			return false
		if entry[2]>0:
			app.perform_redraw()
			app.perform_redraw()
			app.perform_roll()
			if not order_expect(game.draft_result.begins_with("%d면" % entry[2]) and game.supply==camp.supply-2,"Paid redraw discards the previous eye and charges once"):
				return false
		var pending: Dictionary = game.checkpoint()
		app.show_phase()
		app.show_phase()
		var expected = entry[2] if entry[2]>0 else entry[0]
		var rng = RandomNumberGenerator.new()
		rng.state = fixture.streams[2]
		rng.randi_range(1,18)
		if entry[2]>0: rng.randi_range(1,18)
		if not order_expect(game.checkpoint().streams==[camp.streams[0],camp.streams[1],rng.state,camp.streams[3]] and game.draft_result.begins_with("%d면" % expected),"Offer and face presentation preserve the separate reward and recruit streams"):
			return false
		var perk: String = game.offerings[0].id
		app.store_path = path.get_base_dir().path_join("missing-subdirectory/campaign.cfg")
		app.choose_perk(perk)
		if not order_expect(game.checkpoint()==pending and app.modal_active,"Failed confirmation preserves pending Golden Eye without refund"):
			return false
		app.close_modal()
		app.store_path = path
		app.choose_perk(perk)
		app.choose_perk(perk)
		if not order_expect(game.phase=="map" and game.supply==camp.supply+entry[3],"Retry applies only the final paid 17/18 outcome once"):
			return false
	var capped = camp.duplicate(true)
	capped.perks.liu.append("golden_eye")
	capped.heroes.append("cao")
	capped.perks["cao"] = []
	capped.supply = 9
	capped.streams[2] = order_rng_state(18)
	game.restore(capped)
	app.show_phase()
	app.change_odds("lance")
	app.perform_roll()
	app.choose_draft_resolution("supply")
	app.choose_perk(game.offerings[0].id)
	return order_expect(game.phase=="map" and game.supply==9,"Duplicate conversion and Golden Eye share the supply cap")

func golden_restart(app, mode: String) -> bool:
	var game = app.game
	if mode=="golden-write":
		app.run_seed.text = "12345"
		app.start_historical()
		app.choose_route(0)
		app.complete_travel()
		Pilot.pilot(game,5000)
		if game.phase!="camp":
			return false
		var camp: Dictionary = game.checkpoint()
		camp.perks.liu.append("golden_eye")
		camp.supply = 5
		camp.streams[2] = order_rng_state(16,18)
		game.restore(camp)
		app.show_phase()
		app.perform_roll()
		app.perform_redraw()
		app.perform_roll()
	else:
		app.continue_run()
	if not order_expect(game.phase=="camp" and game.draft_done and game.rerolled and game.draft_result.begins_with("18면") and game.supply==3,"Paid replacement is saved at face 18 and a single redraw cost"):
		return false
	if mode=="golden-write":
		print("Paid replacement written; supply 3, face 18")
		return true
	var before: Dictionary = game.checkpoint()
	app.perform_roll()
	app.perform_redraw()
	if game.checkpoint()!=before:
		return false
	app.choose_perk(game.offerings[0].id)
	if not order_expect(game.phase=="map" and game.supply==4 and game.checkpoint().streams==before.streams,"A restarted Golden Eye pays the committed refund once without another RNG draw"):
		return false
	print("Paid replacement reopened and committed; supply 4")
	return AudioServer.is_bus_mute(0)

func order_bow(game, departure: Dictionary) -> bool:
	var fixture = departure.duplicate(true)
	fixture.heroes.append("han")
	fixture.perks["han"] = ["arch"]
	game.restore(fixture)
	game.enter_battle()
	order_position(game)
	var player: Dictionary = game.team[0]
	var bow: Dictionary = game.team[-1]
	var foe: Dictionary = game.foes[0]
	game.foes.resize(1)
	player.p = Vector2(210,270)
	bow.p = Vector2(210,280)
	var expected = RandomNumberGenerator.new()
	expected.state = game.combat_rng.state
	var power = (25+expected.randi_range(-1,1))*1.55*1.30
	var arrows: Array = []
	var capture = func(projectile): arrows.append(projectile)
	game.arrow_released.connect(capture)
	for frame in 42:
		game.tick(Campaign.STEP,Vector2.ZERO,foe.p,false,false,false,false)
	game.arrow_released.disconnect(capture)
	return order_expect(arrows.size()==1 and arrows[0].actor==bow and is_equal_approx(arrows[0].power,power) and bow.cool.cover>4.125-42*Campaign.STEP and bow.cool.cover<4.125,"An allied archer gets Last Stand cooldown and builds the boosted projectile")

func order_restart(app, mode: String) -> bool:
	var game = app.game
	if mode=="orders-write":
		app.run_seed.text = "12345"
		app.start_historical()
		app.choose_route(0)
		app.complete_travel()
		Pilot.pilot(game,5000)
		if not order_expect(game.phase=="camp","Orders fixture reaches a playable camp"):
			return false
		var camp: Dictionary = game.checkpoint()
		if not order_camp(app,camp):
			return false
		var fixture = camp.duplicate(true)
		fixture.perks.liu.append_array(["ration_cycle","last_stand"])
		fixture.perks.fan.append("reserve")
		fixture.supply = 2
		fixture.streams[2] = order_rng_state(1)
		game.restore(fixture)
		app.show_phase()
		app.change_odds("shield")
		app.perform_roll()
		app.choose_draft_resolution("promote")
		var pending: Dictionary = game.checkpoint()
		var path: String = app.store_path
		var perk: String = game.offerings[0].id
		app.store_path = path.get_base_dir().path_join("missing-subdirectory/campaign.cfg")
		app.choose_perk(perk)
		if not order_expect(game.checkpoint()==pending and app.modal_active,"Promotion failure rolls back ration entitlement"):
			return false
		app.close_modal()
		app.store_path = path
		app.choose_perk(perk)
		app.choose_perk(perk)
		if not order_expect(game.promotion_level("fan")==1 and game.supply==1 and game.checkpoint().get("ration_hero")=="fan","One committed promotion schedules one army ration"):
			return false
		app.choose_route(0)
	else:
		app.continue_run()
	var departure: Dictionary = app.checkpoint_data.duplicate(true)
	if mode=="orders-counter":
		departure.perks.liu.clear()
		game.restore(departure)
		return order_counter(game)
	if mode=="orders-bow":
		return order_bow(game,departure)
	var old = departure.duplicate(true)
	old.erase("ration_hero")
	var default_game = Campaign.new()
	default_game.mount(root)
	default_game.restore(old)
	default_game.enter_battle()
	var old_fan: Dictionary = default_game.team[1]
	var base_mp: float = 24+old_fan.perks.count("reserve")*8
	if not order_expect(old_fan.max_mp==base_mp and not old_fan.has("ration_credit"),"Old checkpoint without a ration starts with normal perks only"):
		return false
	default_game.clear_battle()
	default_game.host.queue_free()
	app.complete_travel()
	if not order_expect(game.phase=="battle" and game.supply==0,"Saved travel resumes with zero supply"):
		return false
	order_position(game)
	var player: Dictionary = game.team[0]
	var fan: Dictionary = game.team[1]
	var enemy: Dictionary = game.foes[0]
	if not order_expect(fan.max_mp==base_mp+4 and fan.mp==fan.max_mp and player.max_mp==24,"Rations grant exactly +4 MP to the promoted ally at battle entry"):
		return false
	if not order_expect(game.get("last_stand")==true,"Last Stand reapplies on zero-supply departure"):
		return false
	fan.p = enemy.p+Vector2.DOWN*22
	game.tick(Campaign.STEP,Vector2.ZERO,enemy.p,false,false,false,true)
	if not order_expect(player.cool.command==3.75 and fan.fatigue==0.0 and not fan.has("ration_credit") and not fan.attack.is_empty(),"Last Stand shortens Command and fan consumes the fatigue credit on attack entry"):
		return false
	var clone = RandomNumberGenerator.new()
	clone.state = game.combat_rng.state
	var expected_damage = (25+clone.randi_range(-1,1))*1.55*1.30
	for frame in player.attack.impact-1:
		game.tick(Campaign.STEP,Vector2.ZERO,enemy.p,false,false,false,false)
	if not order_expect(is_equal_approx(1000.0-enemy.hp,expected_damage),"Last Stand grants exactly +30% contact damage"):
		return false
	for frame in 55:
		game.tick(Campaign.STEP,Vector2.ZERO,enemy.p,false,false,false,false)
	if not order_expect(fan.fatigue>0.0,"The next attack pays its regular fatigue"):
		return false
	app.save()
	if not order_expect(app.checkpoint_data==departure,"Mid-battle save keeps the exact departure for process resume"):
		return false
	if mode=="orders-write":
		print("Orders written at departure, zero supply and exactly one rank; midpoint save retained departure")
		return true
	game.finish_battle(true)
	game.restore(game.checkpoint())
	if not order_expect(game.get("ration_hero")=="","Completed battle consumes the ration for later chapters"):
		return false
	var next = departure.duplicate(true)
	next.supply = 1
	var checkpoint_no_orders: Dictionary = next.duplicate(true)
	checkpoint_no_orders.perks.liu.clear()
	game.restore(next)
	game.enter_battle()
	if not order_expect(game.get("last_stand")==false,"A route leaving one supply does not activate Last Stand"):
		return false
	if not order_bow(game,departure):
		return false
	game.restore(checkpoint_no_orders)
	var proof := order_counter(game)
	print("Orders reopened from disk; ration, Last Stand, and dodge-counter contact checked")
	return proof and AudioServer.is_bus_mute(0)

func verify() -> void:
	var app = Scene.instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.set_process(false)
	var game = app.game
	var mode = OS.get_environment("HAN_MARCH_SAVE_TEST")
	if mode in ["orders-write","orders-read","orders-bow","orders-counter","golden-write","golden-read"]:
		var passed = golden_restart(app,mode) if mode.begins_with("golden") else order_restart(app,mode)
		app.queue_free()
		await process_frame
		await process_frame
		quit(0 if passed else 1)
		return
	if mode in ["tactics-write","tactics-read"]:
		var passed = tactics_restart(app,mode)
		app.queue_free()
		await process_frame
		await process_frame
		quit(0 if passed else 1)
		return
	if mode in ["write","failure"]:
		app.run_seed.text = "12345"
		app.start_historical()
		app.choose_route(0)
		app.complete_travel()
		Pilot.pilot(game,5000)
		if game.phase!="camp":
			push_error("Writer did not reach a genuine camp")
			quit(1)
			return
		app.show_phase()
		app.change_odds("shield")
		var previous = game.checkpoint()
		if mode=="failure":
			app.store_path = app.store_path.get_base_dir().path_join("missing-subdirectory/campaign.cfg")
		app.perform_roll()
		if mode=="failure":
			var state = game.checkpoint()
			if not app.modal_active or not app.save_error or state.rolled or state.draft_candidate!="" or state.streams!=previous.streams or state.supply!=previous.supply:
				push_error("Save failure spent resources, drew a result, or did not report recovery")
				quit(1)
				return
			print("Unwritable target: error is visible, no result, probabilities and supply preserved")
			app.close_modal()
			app.store_path = app.store_path.get_base_dir().get_base_dir().path_join("campaign.cfg")
			app.perform_roll()
			if not game.draft_done or game.supply!=previous.supply-1:
				push_error("Paid roll retry failed")
				quit(1)
				return
			var passed = commit_failures(app)
			app.queue_free()
			await process_frame
			await process_frame
			quit(0 if passed else 1)
			return
	elif mode=="read":
		app.continue_run()
	if game.phase!="camp" or not game.draft_done or game.draft_result.is_empty() or game.roll() or not AudioServer.is_bus_mute(0):
		push_error("Saved roll did not reopen sealed")
		quit(1)
		return
	var next = RandomNumberGenerator.new()
	next.state = game.draft_rng.state
	print(JSON.stringify({"candidate":game.draft_candidate,"draft":game.draft_result,"next_face":next.randi_range(1,18),
		"supply":game.supply,"phase":game.phase,"stream":str(game.draft_rng.state),"seed":game.seed_value}))
	app.queue_free()
	await process_frame
	await process_frame
	quit()
