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
	var roll: Button = ui.primary_button
	if not root.get_visible_rect().encloses(roll.get_global_rect()) or not roll.has_focus():
		push_error("Free roll is not visible and focused at 760x544")
		status = 1
	roll.pressed.emit()
	await snap("narrow-first-recruit")
	if ui.game.draft_candidate not in ["han","cao"] or ui.game.supply!=before.supply:
		status = 1
	# The imported pending result exercises a duplicate even if the normal roll is a recruit.
	before["rolled"] = true
	before["draft_candidate"] = "fan"
	before["draft_result"] = "1면 · 번쾌"
	ui.game.restore(before)
	ui.show_phase()
	await snap("narrow-duplicate")
	var promote: Button = ui.primary_button
	if not promote.text.begins_with("승급") or not promote.has_focus() or not root.get_visible_rect().encloses(promote.get_global_rect()):
		push_error("Promotion choice is not visible and focused at 760x544")
		status = 1
	promote.pressed.emit()
	await snap("narrow-promote-preview")
	var confirm: Button = ui.primary_button
	if ui.game.promotion_level("fan")!=0 or not confirm.has_focus() or not root.get_visible_rect().encloses(confirm.get_global_rect()):
		push_error("Confirmation is not visible or the preview already applied its reward")
		status = 1
	confirm.pressed.emit()
	if ui.game.phase!="map" or ui.game.promotion_level("fan")!=1:
		status = 1
	print("Narrow camp 760x544 (118%): first free roll, duplicate options and confirmation")

func verify() -> void:
	directory = OS.get_environment("HAN_MARCH_CAPTURE")
	root.size = Vector2i(760,544)
	ui = Scene.instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	ui.text_zoom = 1.18
	ui.introduction_open = true
	ui.build_theme()
	ui.show_phase()
	await snap("narrow-title")
	var clipped: Array[String] = []
	for button in ui.screen_body.find_children("*","Button",true,false):
		if not root.get_visible_rect().encloses(button.get_global_rect()):
			clipped.append(button.text)
	print("Narrow title clipped: ",clipped)
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
	await camp_edges()
	ui.queue_free()
	await process_frame
	await process_frame
	quit(status)
