extends SceneTree

const Campaign = preload("res://campaign.gd")
const Pilot = preload("res://tests/pilot.gd")
var failures = 0
var checks = 0
var finished = 0
var cleared = 0
var rolls = {}
var trace_hash = 0
var mode_route_pairs = {}
var army_orders = 0
var redirected_orders = 0
var duplicate_recruits = 0
var new_recruits = 0

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
	mode_route_pairs[mode+":"+str(route_mask)] = true
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
		var focus = game.hero_keys[(chapter+seed_value)%game.hero_keys.size()]
		game.offer_for(focus)
		var offers = game.offerings.map(func(p): return p.id)
		var orders = game.offerings.filter(func(p): return p.tag=="군령")
		var tagged_first = not game.offerings.is_empty() and game.hero_keys.any(func(id): return Campaign.HEROES[id][2]==game.offerings[0].tag)
		expect(offers.size()==3 and offers.all(func(id): return offers.count(id)==1) and tagged_first
			and orders.size()<=1 and orders.all(func(p): return p.id not in game.names_upgrades["liu"]),"tagged offer contract",seed_value)
		if offers.size()!=3:
			break
		var chosen = game.offerings[(seed_value+chapter)%3]
		var perk: String = chosen.id
		var recipient = "liu" if chosen.tag=="군령" else focus
		if chosen.tag=="군령":
			army_orders += 1
			if focus!="liu":
				redirected_orders += 1
		var before = game.checkpoint()
		var recruit: String = before.draft_candidate
		var duplicate = recruit in before.heroes
		var resolution = "supply" if duplicate else ""
		var expected_perks = before.perks.duplicate(true)
		var expected_heroes = before.heroes.duplicate()
		var expected_supply = before.supply
		expected_perks[recipient].append(perk)
		if duplicate:
			duplicate_recruits += 1
			expected_supply += Campaign.DUPLICATE_SUPPLY
		elif not recruit.is_empty():
			new_recruits += 1
			expected_heroes.append(recruit)
			expected_perks[recruit] = []
		if game.golden_refund():
			expected_supply += 1
		expected_supply = mini(expected_supply,Campaign.SUPPLY_CAP)
		expect(replay.restore(before) and replay.checkpoint()==before and replay.offerings==game.offerings,
			"camp restore changes pending recruit or offers",seed_value)
		if duplicate:
			expect(not replay.advance(perk) and replay.checkpoint()==before,"unresolved duplicate changed camp state",seed_value)
		var advanced = game.advance(perk,resolution)
		expect(advanced and game.names_upgrades==expected_perks,"perk not recorded exactly once for "+recipient,seed_value)
		var after = game.checkpoint()
		expect(game.hero_keys==expected_heroes and game.supply==expected_supply and game.promotions==before.promotions
			and game.draft_candidate.is_empty() and game.phase=="map" and game.chapter==chapter+1
			and after.streams==before.streams,"camp choice did not commit expected recruit and departure",seed_value)
		expect(replay.advance(perk,resolution) and replay.checkpoint()==after and not replay.advance(perk,resolution)
			and replay.checkpoint()==after,"replayed camp choice did not commit exactly once",seed_value)
	game.clear_battle()
	replay.clear_battle()
	game.host.queue_free()
	replay.host.queue_free()

func verify() -> void:
	var starting = OS.get_environment("HAN_MARCH_MATRIX_START").to_int()
	var count = maxi(1,OS.get_environment("HAN_MARCH_MATRIX_COUNT").to_int())
	var cross_modes = OS.get_environment("HAN_MARCH_MATRIX_CROSS_MODES")=="1"
	for n in count:
		var id = starting+n
		var group = int(id/16.0) if cross_modes else id
		trial(1000+id*7919,"history" if group%2==0 else "fiction",id%16)
		await process_frame
	print(JSON.stringify({"start":starting,"count":count,"checks":checks,"failed":failures,"founding":finished,"completed_intermediate":cleared,"drafts":rolls.keys(),"replay_digest":trace_hash,"mode_route_pairs":mode_route_pairs.size(),
		"army_orders":army_orders,"redirected_orders":redirected_orders,"duplicate_recruits":duplicate_recruits,"new_recruits":new_recruits}))
	await process_frame
	quit(1 if failures else 0)
