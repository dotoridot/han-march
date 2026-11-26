extends SceneTree

const Scene = preload("res://main.tscn")
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
	ui.queue_free()
	await process_frame
	await process_frame
	quit(status)
