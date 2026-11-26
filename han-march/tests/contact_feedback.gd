extends SceneTree

const Campaign = preload("res://campaign.gd")
const Scene = preload("res://main.tscn")
var game
var checks := 0
var failed := 0

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failed += 1
		printerr(message)

func stage(attacker: String, target_at: Vector2) -> Array:
	game.clear_battle()
	game.barrier.clear()
	game.dodge_ticks = 0
	var source = game.make_actor(attacker,Vector2(260,197))
	var target = game.make_actor("guard",target_at,true)
	game.team.append(source)
	game.foes.append(target)
	return [source,target]

func outcome(id: int, category: String) -> Array:
	return game.traces.filter(func(mark): return mark.get("attack_id",-1)==id and mark.kind==category)

func check_audio_pool(app) -> void:
	var players = app.get("audio_players")
	expect(players is Array and players.size()==4,"Combat audio has four slots")
	if not players is Array or players.size()!=4:
		app.toggle_impacts()
		return
	var rng_state: int = game.combat_rng.state
	var loop: AudioStreamWAV = app.sounds["impact"].duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = 2200
	for i in players.size():
		var player: AudioStreamPlayer = players[i]
		expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(player.bus)),"Every slot routes through the muted bus")
		player.stream = loop
		player.play()
		app.audio_started[i] = [8,5,7,6][i]
	await process_frame
	app.audio_next = 2
	expect(app.next_audio_slot()==1,"Only a saturated pool replaces the oldest active cue")
	players[0].stop()
	expect(app.next_audio_slot()==0,"The next idle slot wins over any active cue")
	players[3].stop()
	expect(app.next_audio_slot()==3,"Idle slots are visited in round-robin order")
	app.play("axe_impact")
	app.toggle_impacts()
	app.play("axe_impact")
	expect(AudioServer.is_bus_mute(0) and not players[0].playing and not players[3].playing,"Muted cues cannot start in either sound mode")
	expect(game.combat_rng.state==rng_state,"Audio scheduling does not consume combat RNG")
	for player in players: player.stop()

func weapon_case(weapon: String, attacker: String, distance: float) -> void:
	var actors = stage(attacker,Vector2(260+distance,197))
	var source = actors[0]
	var target = actors[1]
	game.attack(source,target.p,true)
	var info: Dictionary = source.attack
	var previous_offset := Vector2.ZERO
	var pose_steps = []
	var transfer_changed_inside_pose := false
	for tick in range(info.impact-1):
		var before: int = info.frame
		previous_offset = info.node.visual_transfer
		game.step_attack(source)
		if before==info.frame and previous_offset.distance_to(info.node.visual_transfer)>0.01:
			transfer_changed_inside_pose = true
		if before!=info.frame: pose_steps.append(tick+1)
	var hp: float = target.hp
	expect(not info.contact and outcome(info.id,weapon).is_empty() and game.strikes.is_empty(),"Wind-up cannot emit contact or missile early")
	game.step_attack(source)
	expect(info.contact and info.frame==3 and info.node.painted_pose==3 and outcome(info.id,weapon).size()==1,"The same tick publishes the contact pose and weapon cue")
	expect(transfer_changed_inside_pose,"Movement inside a sprite pose is interpolated")
	if weapon=="bow":
		expect(target.hp==hp and game.strikes.size()==1 and game.sound_cue=="loose","Bow loose spawns a projectile with no immediate target damage")
		for tick in 20: game.move_projectiles(Campaign.STEP)
	expect(target.hp<hp and outcome(info.id,"impact").size()==1 and target.recoil.length()>0 and target.hit>0,"The target recoils when the weapon actually lands")
	var after: float = target.hp
	var state: int = game.combat_rng.state
	game.contact(source)
	expect(target.hp==after and game.combat_rng.state==state and outcome(info.id,"impact").size()==1,"Replayed contact cannot change damage, cues or RNG")
	var at_impact = info.node.visual_transfer
	for tick in range(info.duration-info.impact-1): game.step_attack(source)
	expect(info.frame==5 and info.node.visual_transfer.distance_to(at_impact)>0.2,"Recovery moves back into a usable pose")
	game.step_attack(source)
	expect(source.attack.is_empty(),"Attack releases controls after recovery")
	print(weapon," keyed prepare ",pose_steps," contact ",info.impact," recovery ",info.duration-info.impact,
		" HP ",hp," -> ",after," transfer ",at_impact)
	await process_frame

func verify() -> void:
	var app = Scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	game = app.game
	game.new_run(12345,"history")
	game.choose_route(0)
	game.enter_battle()
	game.training_ticks = 0
	await weapon_case("sword","liu",26.0)
	await weapon_case("axe","fan",26.0)
	await weapon_case("bow","han",96.0)
	var actors = stage("liu",Vector2(350,197))
	var source = actors[0]
	var target = actors[1]
	game.attack(source,target.p)
	var id: int = source.attack.id
	for tick in source.attack.impact: game.step_attack(source)
	expect(outcome(id,"miss").size()==1 and target.hp==target.max_hp and game.sound_cue=="whiff","Whiff gets a dry cue without damage")
	actors = stage("han",Vector2(325,197))
	source = actors[0]
	target = actors[1]
	game.barrier.assign([Rect2(297,177,7,40)])
	game.attack(source,target.p)
	id = source.attack.id
	for tick in source.attack.impact: game.step_attack(source)
	for tick in 20: game.move_projectiles(Campaign.STEP)
	expect(outcome(id,"block").size()==1 and target.hp==target.max_hp and game.sound_cue=="block","Arrow hitting the wall gets a block cue")
	actors = stage("liu",Vector2(282,197))
	source = actors[0]
	target = actors[1]
	game.attack(source,target.p)
	var canceled: int = source.attack.id
	game.step(Vector2.ZERO,Vector2.RIGHT,false,true,false,false)
	expect(source.attack.is_empty() and outcome(canceled,"sword").is_empty(),"Dodge interrupts a pending attack without emitting its contact")
	var old_health: float = source.hp
	game.hurt(source,20,target,136,Vector2.LEFT)
	expect(outcome(136,"evade").size()==1 and source.hp==old_health and game.dodge_ticks==Campaign.DODGE_STEPS,"Evade cue does not interrupt invulnerability or cause damage")
	app.motion_reduced = true
	app.show_phase()
	expect(app.landscape.reduce_motion and len(game.traces)>0,"Reduced motion leaves the same hit and evade evidence")
	for tick in range(Campaign.DODGE_STEPS):
		game.step(Vector2.ZERO,Vector2.RIGHT,false,false,false,false)
	game.step(Vector2.ZERO,target.p,true,false,false,false)
	expect(not source.attack.is_empty() and source.attack.id!=canceled,"Attack returns immediately after the evade window")
	game.team.append(game.make_actor("fan",Vector2(280,200)))
	var inspected = InputEventKey.new()
	inspected.physical_keycode = KEY_C
	inspected.pressed = true
	app._input(inspected)
	app.refresh_battle()
	expect(app.landscape.get("inspected_uid")==game.team.back().uid and "HP 165/165" in app.field_status.text,"C exposes the selected ally's exact values")
	expect(AudioServer.is_bus_mute(0) and app.impacts.size()==5,"Recorded sound data imported while the test stays muted")
	await check_audio_pool(app)
	expect(not app.recorded_impacts and AudioServer.is_bus_mute(0),"Switching recorded and synthetic sounds does not clear the mute")
	app.close_modal()
	print("Contact and animation checks ",checks-failed,"/",checks)
	game.clear_battle()
	app.queue_free()
	await process_frame
	await process_frame
	quit(failed)
