extends SceneTree

const Campaign = preload("res://campaign.gd")
const Pilot = preload("res://tests/pilot.gd")
var failures = 0
var checks = 0
var finished = 0
var cleared = 0
var rolls = {}
var trace_hash = 0

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, name: String, seed_value: int) -> void:
	checks += 1
	if not passed:
		failures += 1
		printerr("REGRESSION seed=",seed_value," ",name)

func trial(seed_value: int, mode: String, route_mask: int) -> void:
	var game = Campaign.new()
	game.mount(root)
	game.new_run(seed_value,mode)
	var replay = Campaign.new()
	replay.mount(root)
	var checkpoint_before = game.checkpoint()
	expect(replay.restore(checkpoint_before),"restore at start",seed_value)
	for chapter in 4:
		var preferred = (route_mask >> chapter) & 1
		var route = preferred if game.supply + game.entry().routes[preferred][3]>=0 else 0
		expect(game.choose_route(route),"available routing",seed_value)
		var data = game.checkpoint()
		expect(replay.restore(data),"restore departure",seed_value)
		game.enter_battle()
		replay.enter_battle()
		expect(game.battle_seed==replay.battle_seed and game.foes.map(func(u): return [u.id,u.p])==replay.foes.map(func(u): return [u.id,u.p]),"departure reconstruction",seed_value)
		var count = Pilot.pilot(game,3800)
		var summary = [game.phase,game.team[0].hp,game.defeated,game.gates,game.rescued,game.step_number,game.combat_rng.state]
		var duplicated = Pilot.pilot(replay,3800)
		expect(duplicated==count and summary==[replay.phase,replay.team[0].hp,replay.defeated,replay.gates,replay.rescued,replay.step_number,replay.combat_rng.state],"combat replay divergence",seed_value)
		trace_hash = hash([trace_hash,summary])
		if chapter==3:
			expect(not game.hero_keys.has("xiang") or game.foes.all(func(u): return u.id!="captain"),"Xiang appears on both sides",seed_value)
		if game.phase=="ending":
			finished += 1
			break
		if game.phase!="camp":
			break
		cleared += 1
		if game.supply>0:
			game.change_plan(["balance","shield","lance"][(chapter+seed_value)%3])
		game.roll()
		expect(replay.restore(game.checkpoint()) and not replay.roll() and replay.draft_result==game.draft_result,"revealed roll repeated or absent",seed_value)
		if game.supply>=2 and (seed_value+chapter)%2==0:
			expect(game.redraw_reward(),"eligible redraw failed",seed_value)
			game.roll()
			expect(not game.redraw_reward(),"unlimited redraw",seed_value)
		rolls[game.draft_candidate] = true
		var candidate = game.hero_keys[(chapter+seed_value)%game.hero_keys.size()]
		game.offer_for(candidate)
		expect(game.offerings.size()==3 and game.offerings.any(func(p): return p.tag==Campaign.HEROES[candidate][2] or game.hero_keys.any(func(id): return Campaign.HEROES[id][2]==p.tag)),"tagged offer contract",seed_value)
		var perk = game.offerings[(seed_value+chapter)%3].id
		game.advance(perk)
		expect(game.names_upgrades[candidate].has(perk),"perk not recorded",seed_value)
	game.clear_battle()
	replay.clear_battle()
	game.host.queue_free()
	replay.host.queue_free()

func verify() -> void:
	var starting = OS.get_environment("HAN_MARCH_MATRIX_START").to_int()
	var count = maxi(1,OS.get_environment("HAN_MARCH_MATRIX_COUNT").to_int())
	for n in count:
		var id = starting+n
		trial(1000+id*7919,"history" if n%2==0 else "fiction",id%16)
		await process_frame
	print(JSON.stringify({"start":starting,"count":count,"checks":checks,"failed":failures,"founding":finished,"completed_intermediate":cleared,"drafts":rolls.keys(),"replay_digest":trace_hash}))
	await process_frame
	quit(1 if failures else 0)
