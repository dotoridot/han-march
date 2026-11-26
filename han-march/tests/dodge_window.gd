extends SceneTree

const Campaign = preload("res://campaign.gd")
var failed := 0

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, label: String) -> void:
	if not passed:
		failed += 1
		printerr(label)

func run(dodge_at: int, overlap: bool) -> Array:
	var game = Campaign.new()
	game.mount(root)
	game.new_run(12345,"history")
	game.choose_route(0)
	game.enter_battle()
	game.clear_battle()
	game.barrier.clear()
	game.training_ticks = 0
	var player = game.make_actor("liu",Vector2(320,200))
	game.team.append(player)
	game.foes.append(game.make_actor("guard",Vector2(320,176),true))
	if overlap:
		game.foes.append(game.make_actor("pursuer",Vector2(320,225),true))
	var warned: Dictionary = {}
	var contacts: Dictionary = {}
	var protected_ticks := 0
	for tick in range(68):
		game.step(Vector2.ZERO,Vector2.UP,false,tick>=dodge_at,false,false)
		if game.dodge_ticks>0:
			protected_ticks += 1
		for foe in game.foes:
			if foe.attack.is_empty():
				continue
			if not warned.has(foe.id): warned[foe.id] = tick
			if foe.attack.contact and not contacts.has(foe.id): contacts[foe.id] = tick
	var result = [warned,contacts,player.hp,protected_ticks]
	game.clear_battle()
	game.host.queue_free()
	return result

func verify() -> void:
	var timely = run(25,true)
	var late = run(44,false)
	print("Guard+pursuer, dodge on tick 25 ",timely," | guard, dodge on tick 44 ",late)
	expect(timely[0].get("pursuer",-1)>=10,"Enemy AI must stagger overlapping floor warnings")
	expect(late[1].get("guard",0)-late[0].get("guard",0)>=31,"Opening melee warning must leave 0.5s")
	expect(timely[3]>=20 and timely[3]<=22,"One held input gives one finite dodge")
	expect(late[2]<152 and timely[2]==152,"Dodge after the warning protects. Input after contact cannot undo damage.")
	await process_frame
	quit(failed)
