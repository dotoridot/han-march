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

func verify() -> void:
	var app = Scene.instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.set_process(false)
	var game = app.game
	var mode = OS.get_environment("HAN_MARCH_SAVE_TEST")
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
