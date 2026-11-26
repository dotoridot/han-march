extends SceneTree

const App = preload("res://main.tscn")
const Campaign = preload("res://campaign.gd")
const Relief = preload("res://mounted_map.gd")
const Pilot = preload("res://tests/pilot.gd")
var app
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(description)
		printerr(description)

func key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func step_to(at: Vector2) -> void:
	for _step in 150:
		var gap: Vector2 = at-app.mounted_map.point
		if gap.length()<0.18:
			return
		key(KEY_LEFT,gap.x<-0.11)
		key(KEY_RIGHT,gap.x>0.11)
		key(KEY_UP,gap.y<-0.11)
		key(KEY_DOWN,gap.y>0.11)
		app._physics_process(Campaign.STEP)

func stop() -> void:
	for code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		key(code,false)
	app._physics_process(Campaign.STEP)

func ride_branch(branch: int) -> void:
	for target in Relief.TRAILS[branch]:
		step_to(target)
	stop()

func seal_check() -> void:
	var seal = app.seal_view
	var before: Quaternion = seal.pivot.quaternion
	var surface_point: Vector2 = seal.camera.unproject_position(seal.pivot.to_global(Vector3(0,-0.61,0.76)))
	expect(seal.ray_hit(surface_point) is Vector3,"Seal ray picks the actual bronze face")
	expect(seal.ray_hit(Vector2(-500,-500))==null,"Empty space is not pickable")
	seal.pointer = surface_point
	seal.hovering = true
	for tick in 24:
		seal._process(1.0/60)
	expect(seal.exposure>0.52 and seal.dust.multimesh.visible_instance_count>0 and seal.dust.multimesh.visible_instance_count<seal.home.size()/2,"Only local samples leave the seal")
	seal.hovering = false
	for tick in 120: seal._process(1.0/60)
	expect(seal.exposure<0.008 and seal.dust.multimesh.visible_instance_count==0 and before.angle_to(seal.pivot.quaternion)<0.001,"Leave restores the original composed seal")
	seal.hovering = true
	seal.reduced = true
	seal._process(1.0/60)
	expect(seal.exposure==0 and before.angle_to(seal.pivot.quaternion)<0.001,"Reduced motion keeps seal intact")
	seal.reduced = false
	seal.hovering = false

func skill_check() -> void:
	var game = app.game
	game.clear_battle()
	game.barrier.clear()
	game.training_ticks = 0
	game.names_upgrades["liu"] = ["shield","reserve"]
	game.names_upgrades["han"] = ["arch"]
	var player = game.make_actor("liu",Vector2(300,210))
	var bow = game.make_actor("han",Vector2(322,212))
	var enemy = game.make_actor("guard",Vector2(420,211),true)
	game.team.assign([player,bow])
	var original: float = player.mp
	tap(KEY_R)
	tap(KEY_F)
	app.combat_input(Campaign.STEP)
	var life: float = player.hp
	game.hurt(player,20.0)
	expect(game.player_skill=="brace" and player.brace_time>0 and is_equal_approx(original-player.mp,7.0) and is_equal_approx(life-player.hp,6.3),"F brace uses 7 MP and reduces a real hit")
	tap(KEY_F)
	app.combat_input(Campaign.STEP)
	expect(player.mp>original-7 and player.cool.brace>6.9,"Fast F cannot spend twice during active cooldown")
	tap(KEY_R)
	player.mp = 1.0
	bow.fatigue = 57.0
	game.cancel(bow)
	bow.mp = 3.0
	tap(KEY_F)
	app.combat_input(Campaign.STEP)
	expect(game.player_skill=="rally" and bow.fatigue>55 and not player.cool.has("rally"),"F rally needs at least 12 MP")
	player.mp = 14.0
	tap(KEY_F)
	app.combat_input(Campaign.STEP)
	expect(player.mp<3 and bow.fatigue<34 and bow.mp>9 and player.cool.rally>7.9,"Rally trades MP for nearby ally MP and lower fatigue")
	game.foes.assign([enemy])
	bow.mp = 18.0
	bow.cool.clear()
	bow.decision = 0
	game.run_ally(bow,player,Campaign.STEP)
	expect(bow.role=="cover" and not bow.attack.is_empty() and bow.attack.special and bow.mp==10.0,"Archer without the formation autonomously uses upgraded cover")
	var saved: Dictionary = game.checkpoint()
	expect(game.restore(saved) and game.player_skill=="rally","Selected skill survives checkpoint")
	saved.erase("player_skill")
	expect(game.restore(saved) and game.player_skill=="command","Old checkpoint defaults to the existing F attack")

func campaign(seed_value: int, mode: String, routes: Array) -> void:
	app.back_to_title()
	app.run_seed.text = str(seed_value)
	app.start_run(mode)
	for chapter in 4:
		var favored: String = "shield" if mode=="history" else "reserve"
		var branch: int = routes[chapter]
		var map = app.mounted_map
		var state: int = app.game.field_rng.state
		expect(map.chapter==chapter and map.point.distance_to(Relief.TRAILS[0][0])<0.05,"Each map begins mounted at its chapter start")
		ride_branch(branch)
		expect(map.nearby==branch and map.on_road(map.point) and app.map_prompt.text.contains("E로 출발"),"Arrow keys reach the expected route marker")
		expect(app.game.field_rng.state==state,"Riding and preview do not consume field RNG")
		tap(KEY_E)
		if app.game.phase=="travel": app.complete_travel()
		expect(app.game.phase=="battle" and app.game.selected_route==branch,"E launches the chosen chapter")
		if app.game.phase!="battle": return
		if app.game.names_upgrades["liu"].has(favored):
			expect(("brace" if favored=="shield" else "rally") in app.game.player_skills(),"Chosen camp upgrade changes next chapter's F options")
		Pilot.pilot(app.game,5000)
		app.show_phase()
		expect(app.game.phase==("ending" if chapter==3 else "camp"),"Battle objective opens the next real scene")
		if app.game.phase!="camp": break
		if mode=="fiction" and chapter==0: app.change_odds("lance")
		app.perform_roll()
		var die = app.dice_view
		var number: int = app.game.draft_result.get_slice("면",0).to_int()
		expect(number in range(1,19) and die.number_frames.size()==18 and die.face_target==number,"18-faced model reveals saved die number")
		for _tick in 64: die._process(1.0/60)
		var top: Vector3 = die.pivot.basis*die.number_frames[number-1].z
		expect(top.dot(die.camera.basis.z)>0.999,"Actual revealed face turns to the camera")
		var perk: String = favored if app.game.offerings.any(func(option): return option.id==favored) else app.game.offerings[0].id
		app.choose_perk(perk)
		expect(app.game.names_upgrades["liu"].has(perk),"Camp choice applies a deterministic offered upgrade")
	expect(app.game.phase=="ending" and app.game.completed.size()==4,"Mounted route campaign reaches the founding")
	print(mode," mounted routes ",routes," completed ",app.game.completed.size()," roster ",app.game.hero_keys," / ",app.game.names_upgrades["liu"])

func verify() -> void:
	root.size = Vector2i(1280,800)
	app = App.instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	await process_frame
	await process_frame
	expect(AudioServer.is_bus_mute(0),"Master is muted on test host")
	seal_check()
	campaign(12345,"history",[0,0,1,0])
	app.motion_reduced = true
	campaign(3,"fiction",[1,1,0,1])
	root.size = Vector2i(760,544)
	app.back_to_title()
	app.introduction_open = true
	app.text_zoom = 1.18
	app.build_theme()
	app.show_phase()
	await process_frame
	expect(app.screen_body.find_children("*","Button",true,false).all(func(button): return root.get_visible_rect().encloses(button.get_global_rect())),"Title controls fit 760x544 at 118 percent")
	app.run_seed.text = "12345"
	app.start_historical()
	var map = app.mounted_map
	var unused = map.point
	key(KEY_W,true)
	for _tick in 20: app._physics_process(Campaign.STEP)
	key(KEY_W,false)
	app._physics_process(Campaign.STEP)
	var saved_point: Vector2 = map.point
	expect(saved_point.y<unused.y and map.legs.all(func(leg): return is_zero_approx(leg.rotation.x)),"W moves the rider and reduced motion keeps gait static")
	app.back_to_title()
	var config = ConfigFile.new()
	expect(config.load(app.store_path)==OK,"Scene uses a real profile")
	app.game.new_run(12345,"history")
	app.checkpoint_data = app.game.checkpoint()
	app.checkpoint_data["march_at"] = saved_point
	app.continue_run()
	expect(map.point.distance_to(saved_point)<0.01,"Ride position restored separately from the campaign seed")
	app.game.supply = 0
	app.show_phase()
	var field_stream: int = app.game.field_rng.state
	ride_branch(1)
	tap(KEY_E)
	expect(app.game.phase=="map" and app.game.field_rng.state==field_stream and app.map_prompt.text.contains("보급 부족"),"Locked route cannot spend or advance RNG on E")
	expect(not map.on_road(Relief.FIELDS[0][3]),"Lake center is outside the traversable ribbon")
	app.game.supply = 3
	tap(KEY_E)
	expect(app.game.phase=="battle","Reduced motion enters the valid battle without travel animation")
	skill_check()
	print("Relief, mounted controls, skills and model checks ",checks-failures.size(),"/",checks)
	app.game.clear_battle()
	await process_frame
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if not failures.is_empty() else 0)
