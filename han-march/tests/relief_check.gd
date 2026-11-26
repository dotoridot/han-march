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

func click_map(at: Vector2) -> void:
	var hover = InputEventMouseMotion.new()
	hover.position = at
	root.push_input(hover)
	for pressed in [true,false]:
		var click = InputEventMouseButton.new()
		click.position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click)

func map_keyboard(window_size: Vector2i) -> void:
	for supply in [3,0]:
		app.game.new_run(12345,"history")
		app.game.chapter = 1
		app.game.supply = supply
		app.march_at = Relief.TRAILS[0][0]
		app.show_phase()
		await process_frame
		await process_frame
		var help: Label = app.map_prompt
		expect(help.text.contains("WASD") and help.text.contains("방향키") and help.text.contains("E 출정") and
			help.text.contains("Tab") and help.text.contains("Enter") and
			help.get_visible_line_count()==help.get_line_count() and root.get_visible_rect().encloses(help.get_global_rect()),
			"The full starting help names movement, flag and card keys at %s, supply %d" % [window_size,supply])
		var first_available = 1 if supply==0 else 0
		expect(app.map_choices[first_available].has_focus(),"The first usable route has initial keyboard focus")
		var state: int = app.game.field_rng.state
		tap(KEY_TAB)
		if supply==0:
			expect(not app.map_choices[0].has_focus() and not app.map_choices[1].has_focus(),
				"Tab leaves the available card and skips the locked route")
			tap(KEY_TAB)
		expect(app.map_choices[1].has_focus() and app.game.phase=="map" and app.game.field_rng.state==state,
			"Tab reaches the eastern levee without departing or consuming RNG")
		var preview: Dictionary = app.game.preview_route(1)
		tap(KEY_ENTER)
		expect(app.game.phase=="travel" and app.game.selected_route==1 and app.game.supply==supply+2 and
			app.game.battle_seed==preview.seed,"Enter departs on the focused card with its forecast seed and supply")

func map_layout() -> void:
	app.game.new_run(12345,"history")
	app.show_phase()
	await process_frame
	await process_frame
	var map = app.mounted_map
	var has_flat_map: bool = not map is SubViewportContainer and map.get_global_rect()==root.get_visible_rect()
	expect(has_flat_map,"The strategy map is a 2D control covering the full window")
	if not has_flat_map:
		return
	for window_size in [Vector2i(1280,800),Vector2i(760,544)]:
		root.size = window_size
		app.text_zoom = 1.18 if window_size.x==760 else 1.0
		app.build_theme()
		await map_keyboard(window_size)
		for chapter in 4:
			for route in 2:
				app.game.new_run(12345,"fiction" if chapter==3 else "history")
				app.game.chapter = chapter
				app.march_at = Relief.TRAILS[0][0]
				app.show_phase()
				app.confirmed_draft = {"face":18,"text":"조참 중복, 보급 전환 확정 / 황금 눈으로 추가 보급, 보급 상한을 적용했습니다.",
					"color":Color("e5b75d")}
				app.game.ration_hero = "xiao"
				app.show_phase()
				await process_frame
				await process_frame
				var intro: Label
				for label in app.screen_body.find_children("*","Label",true,false):
					if label.text.begins_with("기록  ") or label.text.begins_with("가상  "):
						intro = label
						break
				var expected_intro: String = ["삼진을 공략했다.","팽성의 한군을 격파했다.","군량과 요충지를 두고 맞섰다.","적장은 창작 인물이다."][chapter]
				expect(is_instance_valid(intro) and intro.is_visible_in_tree() and intro.text.contains(expected_intro) and
					intro.get_visible_line_count()==intro.get_line_count() and root.get_visible_rect().encloses(intro.get_global_rect()),
					"The complete campaign introduction remains visible with a draft result at %s, chapter %d" % [window_size,chapter])
				var flag: Button = map.flags[route]
				var card: Button = app.map_choices[route]
				var label: Label = map.nameplates[route]
				var flag_rect = flag.get_global_rect()
				var bounds = root.get_visible_rect()
				expect(bounds.encloses(flag_rect) and bounds.encloses(card.get_global_rect()) and
					bounds.encloses(app.map_prompt.get_global_rect()),"Route controls and full help fit at %s, chapter %d route %d" %
					[window_size,chapter,route])
				expect(label.text==app.game.entry().routes[route][0] and card.accessibility_name==label.text,
					"Flag and card use the same route name as the campaign")
				expect(not flag_rect.intersects(card.get_global_rect()),"Cards keep each flag's hit target clear")
				if is_instance_valid(intro):
					expect(not flag_rect.intersects(intro.get_global_rect()) and
						not card.get_global_rect().intersects(intro.get_global_rect()),
						"The visible introduction does not cover flag or card input")
				var preview: Dictionary = app.game.preview_route(route)
				click_map(flag_rect.get_center())
				expect(app.game.phase=="travel" and app.game.selected_route==route and app.game.battle_seed==preview.seed,
					"Mouse flag launches the forecast route at %s, chapter %d route %d" % [window_size,chapter,route])
		app.game.new_run(12345,"history")
		app.game.chapter = 1
		app.game.supply = 0
		app.show_phase()
		await process_frame
		await process_frame
		var state: int = app.game.field_rng.state
		expect(map.flags[0].disabled and app.map_choices[0].disabled and
			app.map_choices[0].accessibility_name.contains("보급 부족") and app.map_choices[1].has_focus(),
			"Supply lock is visible and keyboard focus moves to the available bypass")
		click_map(map.flags[0].get_global_rect().get_center())
		click_map(app.map_choices[0].get_global_rect().get_center())
		expect(app.game.phase=="map" and app.game.field_rng.state==state,"Locked flag and card cannot depart")
		expect(not app.map_choices[0].has_focus(),"Clicking a locked card cannot move keyboard focus onto it")
		click_map(app.map_choices[1].get_global_rect().get_center())
		expect(app.game.phase=="travel" and app.game.selected_route==1,"The available route card can depart")
		app.game.new_run(12345,"history")
		app.game.chapter = 1
		app.game.supply = 1
		app.show_phase()
		await process_frame
		await process_frame
		click_map(map.flags[0].get_global_rect().get_center())
		expect(app.game.phase=="travel" and app.game.supply==0 and map.nameplates[0].text=="수변 나루",
			"The selected ferry stays identified as departing after spending its last supply")
	print("Full-window strategy map, flag/card pairing, layout and supply checks complete")

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
		if app.game.draft_candidate in app.game.hero_keys: app.choose_draft_resolution("supply")
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
	if OS.get_environment("HAN_MARCH_MAP_LAYOUT_ONLY")=="1":
		await map_layout()
		print("Map layout checks ",checks-failures.size(),"/",checks)
		app.queue_free()
		await process_frame
		await process_frame
		quit(1 if not failures.is_empty() else 0)
		return
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
	expect(saved_point.y<unused.y and is_zero_approx(map.gait),"W moves the rider and reduced motion keeps gait static")
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
