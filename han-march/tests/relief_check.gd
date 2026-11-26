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

func map_orders_layout(window_size: Vector2i) -> void:
	for input in ["nameplate","flag","keyboard","compact-nameplate","badges"]:
		app.game.new_run(57,"fiction")
		app.march_at = Relief.TRAILS[0][0]
		app.show_phase()
		for chapter in 2:
			app.choose_route(1-chapter)
			app.complete_travel()
			app.game.finish_battle(true)
			app.show_phase()
			app.change_odds("shield")
			app.perform_roll()
			app.choose_draft_resolution("promote")
			app.choose_perk("last_stand" if chapter==0 else "ration_cycle")
			await process_frame
			await process_frame
		expect(app.game.phase=="map" and app.game.chapter==2 and app.game.supply==1 and app.game.ration_hero=="xiao" and
			"last_stand" in app.game.names_upgrades["liu"] and "ration_cycle" in app.game.names_upgrades["liu"] and
			"승급 확정" in app.confirmed_draft.get("text",""),"The seed 57 campaign reaches Xingyang with both orders")
		if input in ["compact-nameplate","badges"]:
			app.confirmed_draft = {"face":18,"kind":"환전","text":"조참 중복, 보급 전환 확정 / 황금 눈으로 추가 보급, 보급 상한을 적용했습니다.",
				"color":Color("e5b75d")}
			app.show_phase()
			await process_frame
			await process_frame
		var map = app.mounted_map
		for i in map.flags.size():
			var flag: Rect2 = map.flags[i].get_global_rect()
			var label: Rect2 = map.nameplates[i].get_global_rect()
			expect(root.get_visible_rect().encloses(flag) and flag.encloses(label) and
				not flag.intersects(app.map_choices[i].get_global_rect()),
				"The complete flag and nameplate fit above the card at %s, route %d" % [window_size,i])
		if input=="badges":
			await map_badge_details(window_size)
			continue
		var route = 0 if input.ends_with("nameplate") else 1
		var preview: Dictionary = app.game.preview_route(route)
		if input=="keyboard":
			expect(app.map_choices[0].has_focus(),"The first card starts focused with both orders")
			tap(KEY_TAB)
			expect(app.map_choices[1].has_focus(),"Tab reaches the second card with both orders")
			tap(KEY_ENTER)
		elif input=="flag":
			var rect: Rect2 = map.flags[route].get_global_rect()
			click_map(Vector2(rect.get_center().x+8,rect.position.y+12))
		else:
			click_map(map.nameplates[route].get_global_rect().get_center())
		expect(app.game.phase=="travel" and app.game.selected_route==route and app.game.battle_seed==preview.seed,
			"The %s inputs launch the forecast route at %s" % [input,window_size])

func map_badge_details(window_size: Vector2i) -> void:
	var badges: Array[Button] = []
	for button in app.screen_body.find_children("*","Button",true,false):
		if button.accessibility_name in ["대길 환전","군량 순환 군령","배수진 군령"]:
			badges.append(button)
	expect(badges.size()==3,"Draft outcome and both orders have separate compact controls at %s" % window_size)
	if badges.size()!=3:
		return
	var copy = ["등용 확정 / 18면 대길 / 조참 중복, 보급 전환 확정",
		"군령 / 군량 순환 / 소하 최대 및 시작 MP +4","군령 / 배수진 / 공격 피해 +30%, 특기 대기 -25% / 성고 산등성이"]
	var mouse = InputEventMouseMotion.new()
	for i in badges.size():
		var badge := badges[i]
		var detail_text := badge.accessibility_description
		expect(detail_text.begins_with(copy[i]),"The badge identifies its outcome or affected route")
		var preview: Label
		var collapsed := true
		for label in app.screen_body.find_children("*","Label",true,false):
			if label.text==detail_text and label.is_visible_in_tree():
				collapsed = false
		expect(collapsed,"Unused details start collapsed")
		mouse.position = badge.get_global_rect().get_center()
		root.push_input(mouse)
		await process_frame
		await process_frame
		for label in app.screen_body.find_children("*","Label",true,false):
			if label.text==detail_text and label.is_visible_in_tree():
				preview = label
		expect(is_instance_valid(preview) and preview.is_visible_in_tree() and preview.text==detail_text and
			preview.get_visible_line_count()==preview.get_line_count(),"Hover presents the whole accessible description")
		if is_instance_valid(preview):
			var detail_rect: Rect2 = preview.get_parent().get_global_rect()
			expect(root.get_visible_rect().encloses(detail_rect),"Expanded detail fits in the window")
			for flag in app.mounted_map.flags:
				expect(not flag.get_global_rect().intersects(detail_rect) and
					not flag.get_global_rect().intersects(badge.get_global_rect()),"Badge and preview leave the flag target clear")
			mouse.position = Vector2(badge.get_global_rect().get_center().x,detail_rect.position.y+2)
			root.push_input(mouse)
			await process_frame
			expect(preview.is_visible_in_tree(),"The description stays visible under the pointer")
		mouse.position = Vector2(8,8)
		root.push_input(mouse)
		await process_frame
		expect(not is_instance_valid(preview) or not preview.is_visible_in_tree(),"Leaving a hovered badge collapses the detail")

	var hovered := badges[1]
	mouse.position = hovered.get_global_rect().get_center()
	root.push_input(mouse)
	for step in 7:
		if badges[0].has_focus(): break
		tap(KEY_TAB)
		await process_frame
	expect(badges[0].has_focus(),"Tab reaches the result badge while the pointer is on an order")
	var result: Label
	for label in app.screen_body.find_children("*","Label",true,false):
		if label.text==badges[0].accessibility_description and label.is_visible_in_tree():
			result = label
	expect(is_instance_valid(result),"Keyboard focus shows the same detail as hover")
	if not is_instance_valid(result):
		return
	tap(KEY_ENTER)
	await process_frame
	expect(not result.is_visible_in_tree() and badges[0].has_focus(),"Enter closes the focused result")
	tap(KEY_ENTER)
	await process_frame
	expect(result.is_visible_in_tree() and result.text==badges[0].accessibility_description,"Enter reopens the same result")

	mouse.position = badges[0].get_global_rect().get_center()
	root.push_input(mouse)
	await process_frame
	click_map(mouse.position)
	await process_frame
	expect(not result.is_visible_in_tree() and badges[0].has_focus(),"Click closes the same focused result")
	click_map(mouse.position)
	await process_frame
	expect(result.is_visible_in_tree() and result.text==badges[0].accessibility_description,"Click reopens the same result")
	tap(KEY_ESCAPE)
	await process_frame
	expect(not result.is_visible_in_tree() and badges[0].has_focus() and not app.modal_active,
		"Escape first dismisses detail and retains badge focus")
	tap(KEY_ESCAPE)
	await process_frame
	expect(app.modal_active,"Escape opens the menu once the detail is closed")
	tap(KEY_ESCAPE)
	await process_frame
	expect(badges[0].has_focus() and not result.is_visible_in_tree(),"Closing the menu restores focus without reopening the detail")
	mouse.position = Vector2(8,8)
	root.push_input(mouse)
	tap(KEY_TAB)
	await process_frame
	expect(badges[1].has_focus() and result.is_visible_in_tree() and result.text==badges[1].accessibility_description,
		"Tab into another badge shows that badge's details")
	click_map(badges[2].get_global_rect().get_center())
	await process_frame
	expect(badges[2].has_focus() and app.game.phase=="map" and app.game.supply==1,
		"Clicking another order focuses its badge without departing or spending supply")
	mouse.position = Vector2(8,8)
	root.push_input(mouse)

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
		await map_orders_layout(window_size)
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
