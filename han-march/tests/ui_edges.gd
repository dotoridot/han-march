extends SceneTree

const Campaign = preload("res://campaign.gd")
const Scene = preload("res://main.tscn")
const Pilot = preload("res://tests/pilot.gd")
var ui
var directory: String
var status = 0

func _initialize() -> void:
	call_deferred("verify")

func snap(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()=="headless":
		await process_frame
		return
	await RenderingServer.frame_post_draw
	if directory:
		root.get_texture().get_image().save_png(directory.path_join(name+".png"))

func camp_labels() -> String:
	var lines: Array[String] = []
	for label in ui.screen_body.find_children("*","Label",true,false):
		lines.append(label.text)
	return "\n".join(lines)

func camp_edges() -> void:
	ui.text_zoom = 1.18
	ui.build_theme()
	ui.complete_travel()
	Pilot.pilot(ui.game,5000)
	if ui.game.phase!="camp":
		push_error("Narrow-window run did not reach the first camp")
		status = 1
		return
	var before: Dictionary = ui.game.checkpoint()
	ui.show_phase()
	if ui.game.checkpoint()!=before:
		push_error("First camp forecast changed checkpoint or RNG state")
		status = 1
	ui.show_phase()
	await snap("narrow-first-camp")
	var table = camp_labels()
	if "다음 전장 / 팽성" not in table or "추격병" not in table or "경유지 선택 전" not in table:
		push_error("Camp forecast omits the next battlefield, its pursuit or the unselected routes")
		status = 1
	if ui.game.checkpoint()!=before:
		push_error("Camp forecast changed checkpoint or RNG state")
		status = 1
	if "조참 8/18 | 합류: 기본 대열 → 약낭 돌파" not in table or "항우 0/18 | 역사 행군에서는 등용할 수 없습니다." not in table:
		push_error("Odds rows omit the tactic transition or the zero-weight reason")
		status = 1
	var roll: Button = ui.primary_button
	if not root.get_visible_rect().encloses(roll.get_global_rect()) or not roll.has_focus() or roll.accessibility_name!=roll.text:
		push_error("Free roll is not visible and focused at 760x544")
		status = 1
	var key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	await snap("narrow-first-recruit")
	if "합류 예정" not in camp_labels() or "합류 확정" in camp_labels():
		push_error("The rolled recruit must remain pending")
		status = 1
	if ui.game.draft_candidate not in ["han","cao"] or ui.game.supply!=before.supply:
		status = 1
	var recruit: String = ui.game.draft_candidate
	ui.motion_reduced = true
	ui.continue_run()
	await snap("narrow-reopened-roll")
	var settled: float = ui.dice_view.get("reveal_elapsed")
	if settled<.74 or "합류 예정" not in camp_labels():
		push_error("Restoring a saved roll should show the pending result without motion")
		status = 1
	ui.choose_perk(ui.game.offerings[0].id)
	await snap("narrow-recruit-confirmed")
	if recruit not in ui.game.hero_keys or "합류 확정" not in camp_labels() or ui.audio_sequence!=0:
		push_error("The saved recruit must be announced on the map")
		status = 1
	ui.continue_run()
	await process_frame
	if "합류 확정" in camp_labels() or ui.audio_sequence!=0:
		push_error("Reloading a map checkpoint must not replay the confirmed result")
		status = 1
	# The imported pending result exercises a duplicate even if the normal roll is a recruit.
	before.heroes.append_array(["han","cao"])
	before.perks["han"] = []
	before.perks["cao"] = []
	before["rolled"] = true
	before["draft_candidate"] = "han"
	before["draft_result"] = "1면 · 한신"
	ui.game.restore(before)
	ui.show_phase()
	await snap("narrow-duplicate")
	var options = camp_labels()
	if "왕의 신호 (유방의 기세 베기 피해 +25%)" not in options or "보급 +2 전환: 방패 엄호" not in options or "방패와 장창 (조참의 공격 피해 +20%)" not in options:
		push_error("Duplicate options omit the upgrade and conversion previews")
		status = 1
	var promote: Button = ui.primary_button
	if not promote.text.begins_with("승급") or not promote.has_focus() or not root.get_visible_rect().encloses(promote.get_global_rect()):
		push_error("Promotion choice is not visible and focused at 760x544")
		status = 1
	var click = InputEventMouseButton.new()
	click.position = promote.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await snap("narrow-promote-preview")
	var confirm: Button = ui.primary_button
	if ui.draft_resolution!="promote" or ui.game.promotion_level("han")!=0 or not confirm.has_focus() or not root.get_visible_rect().encloses(confirm.get_global_rect()) or "출발 후 진법: 방패 엄호 (한신이 지원 사격 사용) + 왕의 신호" not in camp_labels():
		push_error("Confirmation is not visible or the preview already applied its reward")
		status = 1
	key = key.duplicate()
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	if ui.game.phase!="map" or ui.game.promotion_level("han")!=1 or ui.game.tactics.support!="royal_signal":
		status = 1
	print("Narrow camp 760x544 (118%): keyboard roll, mouse promotion choice, keyboard confirmation")
	for supply in [0,1]:
		var route_camp = before.duplicate(true)
		route_camp.rolled = false
		route_camp.draft_result = ""
		route_camp.draft_candidate = ""
		route_camp.supply = supply
		ui.game.restore(route_camp)
		ui.show_phase()
		var can_depart: bool = supply==1
		var forecast: String = camp_labels()
		ui.choose_perk(ui.game.offerings[0].id)
		var choice: Button = ui.primary_button
		ui.choose_route(0)
		var departed: bool = ui.game.phase=="battle" and ui.checkpoint_data.get("phase")=="travel"
		if ("수변 나루 (보급 부족, 1 필요)" in forecast)==can_depart or ("수변 나루 (초기 적이 적음)" in forecast)!=can_depart or choice.disabled==can_depart or departed!=can_depart:
			push_error("Camp, map and departure disagree on the ferry at supply %d" % supply)
			status = 1
		print("Ferry supply ",supply," / disabled ",choice.disabled," / departed ",departed)
	var conversion = before.duplicate(true)
	conversion.supply = 0
	ui.game.restore(conversion)
	ui.show_phase()
	ui.choose_draft_resolution("supply")
	var available: bool = "수변 나루 (초기 적이 적음)" in camp_labels()
	ui.choose_perk(ui.game.offerings[0].id)
	ui.choose_route(0)
	if not available or ui.game.phase!="battle" or ui.game.supply!=1:
		push_error("The ferry forecast must use supply from the pending conversion")
		status = 1
	print("Ferry projected conversion 0 → 2 / departure supply ",ui.game.supply)
	var convoy = before.duplicate(true)
	convoy.chapter = 1
	ui.game.restore(convoy)
	ui.show_phase()
	if "오창 보급길 (매복병이 많음)" not in camp_labels() or "성고 산등성이 (매복병이 적음)" not in camp_labels():
		push_error("The convoy forecast must describe the route-dependent ambush")
		status = 1

func order_edges() -> void:
	ui.complete_travel()
	Pilot.pilot(ui.game,5000)
	if ui.game.phase!="camp":
		push_error("Orders UI fixture did not reach camp")
		status = 1
		return
	var camp: Dictionary = ui.game.checkpoint()
	camp.heroes.append("cao")
	camp.perks["cao"] = []
	camp.perks.liu.append_array(["golden_eye","ration_cycle"])
	camp.supply = 3
	var rng = RandomNumberGenerator.new()
	for seed_value in range(1,100):
		rng.seed = seed_value
		var state = rng.state
		if rng.randi_range(1,18)==18:
			camp.streams[2] = state
			break
	for example in [[3,"promote",3], [9,"supply",9], [9,"promote",9]]:
		camp.supply = example[0]
		ui.game.restore(camp)
		ui.show_phase()
		var streams: Array = ui.game.checkpoint().streams
		await snap("orders-unrolled")
		if ui.game.checkpoint().streams!=streams:
			status = 1
		ui.change_odds("lance")
		ui.perform_roll()
		await snap("orders-golden-%d" % example[0])
		if "18면 대길" not in camp_labels() or "조참 승급 확정" in camp_labels():
			push_error("18 must be visible alongside the pending duplicate reward")
			status = 1
		var before: Dictionary = ui.game.checkpoint()
		var rolled: int = example[0]-1
		var promote = "승급 시 보급 %d → %d / 전환 +0 / 황금 눈 +1 (상한 9)" % [rolled,rolled+1]
		var conversion: int = mini(2,9-rolled)
		var supply = "보급 전환 시 보급 %d → %d / 전환 +%d / 황금 눈 +%d (상한 9)" % [
			rolled,mini(9,rolled+conversion+1),conversion,int(rolled+conversion<9)]
		if not "눈 18 / 18" in camp_labels() or not "첫 공격 또는 응급 처치의 피로 증가량 최대 10 감소" in camp_labels():
			push_error("Camp labels omit the final face or the first-healing effect")
			status = 1
		if directory and example[0]==3:
			DirAccess.copy_absolute(ui.store_path,directory.path_join("camp.cfg"))
		check_reward_view(promote, "승급")
		if not supply in camp_labels():
			push_error("Both choices must show their separate supply outcomes before selection")
			status = 1
		confirm_with_enter()
		await snap("orders-promotion-%d" % example[0])
		check_reward_view(promote,"강화")
		var pending_label: Label
		for label in ui.dice_view.get_parent().find_children("*","Label",true,false):
			if label.text.begins_with("조참 승급 예정"):
				pending_label = label
		if not is_instance_valid(pending_label) or not root.get_visible_rect().encloses(pending_label.get_global_rect()):
			push_error("The pending promotion must stay visible when focus scrolls to the perk")
			status = 1
		if example[0]==9:
			ui.choose_draft_resolution("supply")
			await snap("orders-cap-conversion")
			check_reward_view(supply,"강화")
			if example[1]=="promote":
				ui.choose_draft_resolution("promote")
				await snap("orders-cap-promotion")
				check_reward_view(promote,"강화")
		if ui.game.checkpoint()!=before or ui.game.supply!=rolled:
			push_error("Preview changed the rolled checkpoint")
			status = 1
		if example[0]==3:
			var path: String = ui.store_path
			ui.store_path = path.path_join("unwritable.cfg")
			ui.choose_perk(ui.game.offerings[0].id)
			var failed: Dictionary = ui.game.checkpoint()
			if failed.streams!=before.streams or failed.phase!="camp" or failed.promotions!=before.promotions or failed.supply!=before.supply or failed.draft_candidate!=before.draft_candidate or not ui.save_error or "조참 승급 확정" in camp_labels() or ui.audio_sequence!=0:
				print("Save failure state: ",failed.phase," / ",failed.promotions," / ",failed.supply," / ",failed.draft_candidate," / ",ui.save_error," / muted cues ",ui.audio_sequence)
				push_error("Save failure must leave the promotion and its presentation pending")
				status = 1
			ui.store_path = path
			ui.close_modal()
			await process_frame
			await process_frame
		confirm_with_enter()
		await snap("orders-map-%d-%s" % [example[0],example[1]])
		var saved = ConfigFile.new()
		var saved_ok = saved.load(ui.store_path)==OK
		var state: Dictionary = saved.get_value("checkpoint","state",{}) if saved_ok else {}
		var promoted: bool = example[1]=="promote"
		var outcome = "조참 승급 확정" if promoted else "조참 중복, 보급 전환 확정"
		if not root.get_visible_rect().encloses(ui.map_prompt.get_global_rect()) or not root.get_visible_rect().encloses(ui.primary_button.get_global_rect()):
			push_error("The confirmed result must leave the map controls and prompt visible")
			status = 1
		if "18면 대길" not in camp_labels() or outcome not in camp_labels() or ui.audio_sequence!=0:
			push_error("Confirmed result must identify both 18 and its saved outcome while muted")
			status = 1
		ui.show_phase()
		if outcome not in camp_labels() or ui.dice_view.get("reveal_elapsed")<.74 or ui.audio_sequence!=0:
			push_error("Rebuilding the map must preserve the result without replaying it")
			status = 1
		if ui.game.phase!="map" or ui.game.supply!=example[2] or state.get("supply")!=example[2] or state.get("streams")!=before.streams or ui.game.promotion_level("cao")!=int(promoted) or ("조참 최대 및 시작 MP +4" in camp_labels())!=promoted:
			push_error("Saved supply, rank or RNG differs from the forecast")
			status = 1
	await ration_heal(camp)
	if OS.get_environment("HAN_MARCH_FORECAST_AUDIO_TEST")=="1":
		check_draft_audio(camp)
	print("Orders UI ",root.size," / text scale ",ui.text_zoom," / result ",status)

func check_draft_audio(camp: Dictionary) -> void:
	if DisplayServer.get_name()!="headless" or AudioServer.get_driver_name()!="Dummy" or not AudioServer.is_bus_mute(0) or not OS.has_environment("HAN_MARCH_PROFILE"):
		push_error("Draft audio probe requires a muted, isolated headless Dummy run")
		status = 1
		return
	print("Draft audio driver: ",AudioServer.get_driver_name(),", initially muted")
	AudioServer.set_bus_mute(0,false)
	for example in [
		[18,"cao","promote",["promotion","great_fortune"]],
		[18,"cao","",["recruit","great_fortune"]],
		[9,"han","",["recruit"]],
		[1,"fan","promote",["promotion"]],
		[18,"cao","supply",["great_fortune"]],
	]:
		for player in ui.audio_players:
			player.stop()
		var pending = camp.duplicate(true)
		if example[2]=="":
			pending.heroes.erase(example[1])
			pending.perks.erase(example[1])
		pending.rolled = true
		pending.draft_candidate = example[1]
		pending.draft_result = "%d면 / %s" % [example[0],Campaign.HEROES[example[1]][0]]
		var first: int = ui.audio_sequence
		var slot: int = ui.audio_next
		ui.game.restore(pending)
		ui.show_phase()
		ui.perform_redraw()
		ui.game.restore(pending)
		ui.show_phase()
		ui.choose_draft_resolution(example[2])
		var path: String = ui.store_path
		ui.store_path = path.path_join("unwritable.cfg")
		var perk: String = ui.game.offerings[0].id
		ui.choose_perk(perk)
		if not ui.save_error or ui.audio_sequence!=first:
			push_error("Pending, redrawn or failed draft played a cue")
			status = 1
		ui.store_path = path
		ui.close_modal()
		ui.choose_perk(perk)
		var expected: Array = example[3]
		var played: Array[String] = []
		for i in expected.size():
			var index = (slot+i)%4
			var player: AudioStreamPlayer = ui.audio_players[index]
			if player.playing and player.stream==ui.sounds.get(expected[i]) and ui.audio_started[index]==first+i+1:
				played.append(expected[i])
		if ui.game.phase!="map" or ui.audio_players.size()!=4 or ui.audio_sequence!=first+expected.size() or played!=expected:
			push_error("Saved draft did not play each expected cue once in the four-slot pool")
			status = 1
		var committed: int = ui.audio_sequence
		ui.choose_perk(perk)
		ui.show_phase()
		ui.continue_run()
		if ui.audio_sequence!=committed:
			push_error("Repeat confirmation, redraw or checkpoint resume replayed a saved cue")
			status = 1
		print("Draft audio ",example[0],"/",example[1],"/",example[2],": ",played," / first slot ",slot," / total ",ui.audio_sequence-first)
	AudioServer.set_bus_mute(0,true)

func check_reward_view(note: String, stage: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	var bounds = Rect2()
	for label in ui.screen_body.find_children("*","Label",true,false):
		if note in label.text and label.get_parent()==ui.screen_body:
			bounds = label.get_global_rect()
			break
	var desc: String = focus.accessibility_description if focus!=null else ""
	print(stage," ",note," / label ",bounds," / viewport ",root.get_visible_rect()," / AX ",desc)
	if not bounds.has_area() or not root.get_visible_rect().encloses(bounds) or focus==null or focus!=ui.primary_button or not root.get_visible_rect().encloses(focus.get_global_rect()) or desc!=note:
		push_error("Refund summary and accessible description are required at the focused decision")
		status = 1

func confirm_with_enter() -> void:
	var key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)

func ration_heal(camp: Dictionary) -> void:
	var fixture = camp.duplicate(true)
	fixture.rolled = true
	fixture.draft_candidate = "xiao"
	fixture.draft_result = "6면 · 소하"
	fixture.perks.xiao.append("reserve")
	ui.game.restore(fixture)
	ui.show_phase()
	ui.choose_draft_resolution("promote")
	await snap("orders-heal-preview")
	if not "첫 공격 또는 응급 처치 시 피로 최대 -10" in camp_labels():
		status = 1
	confirm_with_enter()
	await snap("orders-heal-map")
	if not "소하 최대 및 시작 MP +4, 첫 공격 또는 응급 처치 시 피로 최대 -10" in camp_labels():
		status = 1
	ui.choose_route(0)
	ui.complete_travel()
	var game = ui.game
	var player: Dictionary = game.team[0]
	var medic: Dictionary = game.team[2]
	var ready: bool = medic.mp==36.0 and medic.max_mp==36.0 and medic.get("ration_credit",0)==10
	game.clear_battle()
	game.team.append_array([player,medic])
	game.barrier.clear()
	player.p = Vector2(200,200)
	player.hp = 40.0
	medic.p = Vector2(200,205)
	for frame in 100:
		game.step(Vector2.ZERO,Vector2.RIGHT,false,false,false,false)
		if game.events.has("응급 처치"):
			break
	if not ready or player.hp!=61.0 or medic.fatigue!=0.0 or medic.has("ration_credit"):
		push_error("Xiao's first heal must spend the ration and keep its usual healing amount")
		status = 1
	print("Ration heal / ",ready," / HP ",player.hp," / fatigue ",medic.fatigue," / credit ",medic.get("ration_credit",0))

func verify() -> void:
	directory = OS.get_environment("HAN_MARCH_CAPTURE")
	var orders = OS.get_environment("HAN_MARCH_ORDERS_UI")
	root.size = Vector2i(1280,800) if orders=="wide" else Vector2i(760,544)
	ui = Scene.instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	ui.text_zoom = 1.0 if orders=="wide" else 1.18
	ui.introduction_open = true
	ui.build_theme()
	ui.show_phase()
	await snap("narrow-title")
	var clipped: Array[String] = []
	for button in ui.screen_body.find_children("*","Button",true,false):
		if not root.get_visible_rect().encloses(button.get_global_rect()):
			clipped.append(button.text)
	print("Title clipped: ",clipped)
	ui.run_seed.text="12345"
	ui.start_historical()
	await snap("narrow-route-12345")
	var state: int = ui.game.field_rng.state
	ui.show_menu()
	await snap("narrow-options")
	print("Menu focus: ",root.gui_get_focus_owner()!=null," settings pause: ",ui.modal_active)
	ui.close_modal()
	ui.choose_route(0)
	ui.complete_travel()
	ui.save()
	var serialized: Dictionary = ui.checkpoint_data
	ui.queue_free()
	await process_frame
	ui = Scene.instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	ui.continue_run()
	await snap("narrow-reopened-checkpoint")
	print("Reopen: ",ui.game.seed_value," / ",ui.game.selected_route," / ",ui.game.battle_seed)
	if not clipped.is_empty() or state==ui.game.field_rng.state or serialized.version!=2 or serialized.board_seed!=ui.game.battle_seed or ui.game.seed_value!=12345:
		status = 1
	if orders.is_empty():
		await camp_edges()
	else:
		await order_edges()
	ui.queue_free()
	await process_frame
	await process_frame
	quit(status)
