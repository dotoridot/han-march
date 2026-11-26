extends SceneTree

const Scene = preload("res://main.tscn")
const Pilot = preload("res://tests/pilot.gd")

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var app = Scene.instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.set_process(false)
	var game = app.game
	var mode = OS.get_environment("HAN_MARCH_SAVE_TEST")
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
			app.queue_free()
			await process_frame
			await process_frame
			quit()
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
