extends SceneTree

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
	ui.show_phase()
	if ui.game.phase!="camp":
		push_error("Narrow-window run did not reach the first camp")
		status = 1
		return
	var before: Dictionary = ui.game.checkpoint()
	await snap("narrow-first-camp")
	var table = camp_labels()
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
	if ui.game.draft_candidate not in ["han","cao"] or ui.game.supply!=before.supply:
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
	ui.game.restore(camp)
	ui.show_phase()
	var streams: Array = ui.game.checkpoint().streams
	await snap("orders-unrolled")
	if ui.game.checkpoint().streams!=streams:
		status = 1
	ui.change_odds("lance")
	ui.perform_roll()
	await snap("orders-golden")
	var labels = camp_labels()
	if not "후보 확정 시 보급 +1" in labels or not "눈 18 / 18" in labels or not "첫 공격의 피로 증가량 최대 10 감소" in labels:
		push_error("Order labels omit conditions, the final face, or the numeric effect")
		status = 1
	if directory:
		DirAccess.copy_absolute(ui.store_path,directory.path_join("camp.cfg"))
	ui.choose_draft_resolution("promote")
	await snap("orders-promotion")
	var confirm: Button = ui.primary_button
	if not root.get_visible_rect().encloses(confirm.get_global_rect()) or not confirm.has_focus():
		push_error("Orders confirmation is out of the viewport or lost keyboard focus")
		status = 1
	var key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	await snap("orders-map")
	if ui.game.phase!="map" or ui.game.promotion_level("cao")!=1 or not "조참 최대 및 시작 MP +4" in camp_labels() or ui.game.supply!=3:
		push_error("The confirmation did not show the queued ration and one refund")
		status = 1
	print("Orders UI ",root.size," / text scale ",ui.text_zoom," / result ",status)

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
	if not clipped.is_empty() or state==ui.game.field_rng.state or serialized.board_seed!=ui.game.battle_seed or ui.game.seed_value!=12345:
		status = 1
	if orders.is_empty():
		await camp_edges()
	else:
		await order_edges()
	ui.queue_free()
	await process_frame
	await process_frame
	quit(status)
