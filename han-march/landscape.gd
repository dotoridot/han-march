extends Control

const Campaign = preload("res://campaign.gd")
const TEXT = preload("res://assets/NotoSansKR.ttf")
const Figure = preload("res://battle_figure.gd")
const SITES = [Vector2(116,265),Vector2(179,193),Vector2(485,160),Vector2(339,149),Vector2(502,246)]
const NAMES = ["한중","관중 · 삼진","팽성","형양 · 성고","해하"]
const MAP = Vector2(640,374)
const FILL_ENTER = 118.0
const FILL_LEAVE = 138.0
const FILL_OFFSET = Vector2(-20,-29)
const FIGURE_CENTER = Vector2(0,-26)
const INK = Color("1e1714")
const TEXT_COLOR = Color("f4e6c8")
const GOLD = Color("e3ad5e")
const RIVER = Color("527974")
const DANGER = Color("f2a271")
const DANGER_FILL = Color("d0653c99")
var game: Campaign
var display = "map"
var transfer = 0.0
var reduce_motion = false
var box = Rect2()
var text_zoom = 1.0
var backdrop: Texture2D
var cache_key = [-1,0]
var pointer = Vector2.ZERO
var inspected_uid := -1
var render_build_usec = 0
var chip_font: FontVariation
var drafted_map: Texture2D
var figures: Node2D
var overlay: Node2D
var ink: CanvasItem
var key_light: PointLight2D
var warm_light: PointLight2D
var actors: Dictionary = {}
var actor_count := 0
var release_bow: Figure
static var unlit: CanvasItemMaterial

func _ready() -> void:
	game.arrow_released.connect(capture_bow_release)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chip_font = FontVariation.new()
	chip_font.base_font = TEXT
	chip_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):520}

	figures = Node2D.new()
	figures.name = "PaintedCompany"
	figures.hide()
	add_child(figures)
	if unlit==null:
		unlit = CanvasItemMaterial.new()
		unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	overlay = Node2D.new()
	overlay.material = unlit
	overlay.z_index = 2000
	overlay.draw.connect(draw_overlay)
	add_child(overlay)
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var lamp = GradientTexture2D.new()
	lamp.gradient = gradient
	lamp.fill = GradientTexture2D.FILL_RADIAL
	lamp.fill_from = Vector2(0.5,0.5)
	lamp.fill_to = Vector2(1.0,0.5)
	# DirectionalLight2D ignores item masks, so use a wide masked key and a small warm fill.
	key_light = figure_light(lamp,16.0,0.26,195.0,Color("e4dbcd"))
	key_light.position = Vector2(265,95)
	warm_light = figure_light(lamp,2.5,0.22,68.0,Color("eac890"))
	warm_light.range_item_cull_mask = Figure.FILL_MASK

func figure_light(lamp: Texture2D, span: float, energy: float, height: float, tint: Color) -> PointLight2D:
	var light = PointLight2D.new()
	light.texture = lamp
	light.texture_scale = span
	light.range_item_cull_mask = Figure.BONE_MASK
	light.color = tint
	light.energy = energy
	light.height = height
	figures.add_child(light)
	return light

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		sync_figures()

func sync_figures() -> void:
	var active = game!=null and size.x>=10 and size.y>=10 and display=="battle" and not game.team.is_empty()
	figures.visible = active
	if not active:
		if not actors.is_empty():
			for rig in actors.values(): rig.queue_free()
			actors.clear()
		actor_count = 0
		return
	var factor = minf(size.x/MAP.x,size.y/MAP.y)
	figures.position = (size-MAP*factor)*0.5
	figures.scale = Vector2.ONE*factor
	var bodies = game.alive(game.team)+game.alive(game.foes)
	bodies.sort_custom(func(a,b): return a.uid<b.uid if is_equal_approx(a.p.y,b.p.y) else a.p.y<b.p.y)
	var seen: Dictionary = {}
	var focus: Vector2 = Vector2(318,194) if reduce_motion else game.team[0].p
	var warm_center = focus+FILL_OFFSET
	var arena = Rect2(Vector2.ZERO,MAP)
	for index in bodies.size():
		var unit: Dictionary = bodies[index]
		seen[unit.uid] = true
		var rig: Figure = actors.get(unit.uid)
		if rig==null:
			rig = Figure.new()
			figures.add_child(rig)
			rig.setup(unit.id,unit.weapon)
			actors[unit.uid] = rig
		rig.position = unit.p
		rig.set_rank(index)
		rig.present(unit,reduce_motion,unit.id=="liu" and game.dodge_left>0)
		var priority: bool = not unit.side or unit.id in ["captain","fiction"]
		var radius = FILL_LEAVE if rig.has_fill else FILL_ENTER
		var visibility = arena.grow(8.0) if rig.has_fill else arena
		rig.set_fill(priority and visibility.has_point(unit.p) and (Vector2(unit.p)+FIGURE_CENTER).distance_squared_to(warm_center)<=radius*radius)
	for uid in actors.keys():
		if not seen.has(uid):
			actors[uid].hide()
			actors[uid].queue_free()
			actors.erase(uid)
	actor_count = bodies.size()
	if warm_light.position!=warm_center: warm_light.position = warm_center

func capture_bow_release(projectile: Dictionary) -> void:
	if not is_instance_valid(release_bow):
		release_bow = Figure.new()
		add_child(release_bow)
		release_bow.setup("han","bow")
	release_bow.present(projectile.actor,reduce_motion,false)
	release_bow.hide()
	projectile["visual_offset"] = get_global_transform().affine_inverse() * release_bow.tool.to_global(Vector2(32,0))

func visible_arrow(arrow: Dictionary) -> Vector2:
	var offset: Vector2 = arrow.get("visual_offset",Vector2(0,-20))
	var flown: float = arrow.p.distance_to(arrow.get("origin",arrow.p))
	return arrow.p+offset.lerp(Vector2(0,-15),clampf(flown/90.0,0,1))

func to_world(global_at: Vector2) -> Vector2:
	return ((global_at-get_global_rect().position-box.position)/box.size)*MAP if box.size.x>0 else MAP*0.5

func to_screen(world_at: Vector2) -> Vector2:
	return box.position + world_at*(box.size/MAP)

func slab(p: Vector2, dimensions: Vector2, tint: String) -> void:
	ink.draw_rect(Rect2(p,dimensions),Color(tint))

func route_points(index: int, branch: int) -> PackedVector2Array:
	var a: Vector2 = SITES[index]
	var b: Vector2 = SITES[index+1]
	var middle = a.lerp(b,0.51) + Vector2(0,-33 if branch==0 else 30)
	return PackedVector2Array([a,a.lerp(middle,0.58),middle,middle.lerp(b,0.69),b])

func march_position(index: int, branch: int, along: float) -> Vector2:
	var path = route_points(index,branch)
	var piece = mini(path.size()-2,floori(along*(path.size()-1)))
	return path[piece].lerp(path[piece+1],along*(path.size()-1)-piece)

func terrain() -> Texture2D:
	var paper = Image.create(320,187,false,Image.FORMAT_RGBA8)
	var tones = ["514a38","4b3b35","544633","424936"]
	var base = Color(tones[game.chapter])
	var wash = FastNoiseLite.new()
	wash.seed = game.battle_seed
	wash.frequency = 0.047
	for y in 187:
		for x in 320:
			var value = wash.get_noise_2d(x,y)*0.060+(0.5-y/187.0)*0.045
			paper.set_pixel(x,y,Color(base.r+value,base.g+value,base.b+value))
	return ImageTexture.create_from_image(paper)

func paper_map() -> Texture2D:
	var grit = Image.create(640,374,false,Image.FORMAT_RGBA8)
	var brush = RandomNumberGenerator.new()
	brush.seed = 206
	for i in 6200:
		var point = Vector2i(brush.randi_range(0,637),brush.randi_range(0,372))
		var ink = Color("c1a47c2d") if i%4==0 else Color("130d102e")
		grit.fill_rect(Rect2i(point,Vector2i(brush.randi_range(1,3),1)),ink)
	return ImageTexture.create_from_image(grit)

func map_bg() -> void:
	slab(Vector2.ZERO,MAP,"3a2d24")
	var zones = [
		[Vector2(36,120),Vector2(154,114),Vector2(232,149),Vector2(194,228),Vector2(154,264),Vector2(41,288),Vector2(11,224)],
		[Vector2(43,29),Vector2(359,25),Vector2(360,135),Vector2(329,190),Vector2(234,165),Vector2(154,114),Vector2(36,120)],
		[Vector2(365,26),Vector2(550,14),Vector2(626,77),Vector2(626,253),Vector2(543,305),Vector2(323,273),Vector2(339,163)],
	]
	var fills = ["4b513d","514033","553727"]
	for i in zones.size():
		var shape = PackedVector2Array(zones[i])
		ink.draw_colored_polygon(shape,Color(fills[i]))
		var outline = shape.duplicate()
		outline.append(shape[0])
		ink.draw_polyline(outline,Color("795e3f"),1)
	if drafted_map==null:
		drafted_map = paper_map()
	ink.draw_texture(drafted_map,Vector2.ZERO)
	var river = PackedVector2Array([Vector2(0,63),Vector2(85,81),Vector2(134,29),Vector2(226,47),Vector2(244,100),Vector2(226,165),Vector2(308,161),Vector2(379,113),Vector2(468,95),Vector2(548,53),Vector2(640,42)])
	ink.draw_polyline(river,Color("2c3932"),9)
	ink.draw_polyline(river,RIVER,3)
	var yangtze = PackedVector2Array([Vector2(0,322),Vector2(126,306),Vector2(206,328),Vector2(321,300),Vector2(417,315),Vector2(543,306),Vector2(639,260)])
	ink.draw_polyline(yangtze,Color("3d5a53"),5)
	for i in 38:
		var px = 15+(i*83)%605
		var py = 29+(i*119)%307
		if py>196 and py<299 and px<310 or py<111 and px<228:
			var peak = Vector2(px,py)
			ink.draw_colored_polygon(PackedVector2Array([peak+Vector2(-8,6),peak+Vector2(0,-8),peak+Vector2(10,6)]),Color("675642"))
			ink.draw_line(peak+Vector2(0,-8),peak+Vector2(9,5),Color("99815b"))
	for index in range(4):
		for branch in 2:
			var done = game.completed.any(func(route): return route[0]==index and route[1]==branch)
			var active = game.chapter==index and (game.selected_route<0 or game.selected_route==branch)
			var tint = Color("af824b") if done else (GOLD if active else Color("726451"))
			ink.draw_polyline(route_points(index,branch),tint,2.0 if active else 1.0)
	for i in range(SITES.size()):
		var at: Vector2 = SITES[i]
		ink.draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),INK)
		ink.draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),GOLD if i<=game.chapter+1 else Color("a39379"))
		ink.draw_rect(Rect2(at-Vector2(1,1),Vector2(2,2)),TEXT_COLOR)
	if display=="travel":
		var at = march_position(game.chapter,game.selected_route,transfer)
		ink.draw_circle(at,9,INK)
		ink.draw_colored_polygon(PackedVector2Array([at+Vector2(-5,4),at+Vector2(-5,-5),at+Vector2(7,-1)]),GOLD)

func draw_landmark(at: Vector2, large: bool) -> void:
	var width = 66 if large else 46
	slab(at+Vector2(-3,1),Vector2(width+6,8),"27291e")
	slab(at+Vector2(0,-15),Vector2(width,24),"704f35")
	slab(at+Vector2(4,-11),Vector2(width-8,18),"a28259")
	var tall = 7 if large else 3
	ink.draw_colored_polygon(PackedVector2Array([at+Vector2(-6,-12),at+Vector2(6,-22-tall),at+Vector2(width-6,-22-tall),at+Vector2(width+6,-12)]),Color("51362b"))
	ink.draw_line(at+Vector2(-5,-12),at+Vector2(width+5,-12),Color("bb8660"),2)
	for x in range(8,width,15):
		slab(at+Vector2(x,-7),Vector2(5,9),"594339")

func battlefield() -> void:
	if cache_key != [game.chapter,game.battle_seed] or backdrop==null:
		cache_key = [game.chapter,game.battle_seed]
		backdrop = terrain()
	ink.draw_texture_rect(backdrop,Rect2(Vector2.ZERO,MAP),false)
	match game.chapter:
		0:
			slab(Vector2(0,62),Vector2(640,18),"74634c")
			for x in range(7,640,72): draw_landmark(Vector2(x,78),true)
			slab(Vector2(258,97),Vector2(124,276),"80705155")
		1:
			var water = PackedVector2Array([Vector2(22,0),Vector2(84,74),Vector2(37,175),Vector2(87,271),Vector2(48,374)])
			ink.draw_polyline(water,Color("35534e"),36)
			ink.draw_polyline(water,Color("5b7771"),6)
			for x in [183,296,523]: draw_landmark(Vector2(x,91),false)
		2:
			slab(Vector2(15,218),Vector2(612,70),"89704b")
			for x in [12,537]: draw_landmark(Vector2(x,221),true)
			draw_wagon()
		3:
			for x in range(34,627,34):
				if x<128 or x>198 and x<438 or x>528:
					slab(Vector2(x,88),Vector2(29,15),"774f38")
					for post in range(3): slab(Vector2(x+post*10,85),Vector2(3,21),"a27650")
	for wall in game.barrier:
		ink.draw_rect(wall,Color("4a392c"))
		ink.draw_line(wall.position,Vector2(wall.end.x,wall.position.y),Color("8b6f4b"),2)
		for x in range(int(wall.position.x)+4,int(wall.end.x),11):
			slab(Vector2(x,wall.position.y+4),Vector2(5,5),"6c5238")
	if game.board_mask.ridge:
		for i in 3: ink.draw_arc(Vector2(390,117),52+i*12,-2.4,0.1,16,Color("877052"),2)
	elif game.board_mask.mud:
		for i in 12: slab(Vector2(45+(i*163)%535,208+(i*13)%90),Vector2(24,7),"453c30")
	for target in game.targets:
		var p: Vector2 = target[1]
		ink.draw_circle(p,15,Color("654b2d"))
		ink.draw_arc(p,15,0,TAU,20,GOLD,2)
		slab(p-Vector2(1,7),Vector2(3,13),"e3ad5e")
		slab(p+Vector2(2,-6),Vector2(9,5),"983f28")
	if game.chapter==2:
		marker_floor(game.wagon,"ad7545")
	if game.training_ticks>0:
		var origin: Vector2 = game.training_at
		var lane = Rect2(origin-Vector2(13,70),Vector2(26,94))
		ink.draw_rect(lane,Color("a649306c"))
		ink.draw_rect(lane,Color("f4b372"),false,2)
		ink.draw_line(origin-Vector2(7,25),origin,Color("f4b372"),2)
		ink.draw_line(origin+Vector2(7,-25),origin,Color("f4b372"),2)
	for e in game.alive(game.foes):
		if not e.attack.is_empty() and not e.attack.contact:
			var dir: Vector2 = e.attack.dir
			var reach = game.max_range(e)
			var remaining: int = e.attack.impact-e.attack.step
			var progress = 1.0-float(remaining)/e.attack.impact
			var imminent = remaining<=4
			var filled = floorf(progress*4)/4 if reduce_motion else progress
			if e.weapon=="bow":
				var edge: Vector2 = dir.orthogonal()*13
				var cutoff: float = game.line_obstacle(e.p,e.p+dir*reach)
				if cutoff<INF: reach *= sqrt(cutoff)
				var end: Vector2 = e.p+dir*reach
				var lane = PackedVector2Array([e.p-edge,e.p+edge,end+edge,end-edge])
				if reach>0:
					ink.draw_colored_polygon(lane,Color("a84a303a"))
					if filled>0:
						var front: Vector2 = e.p.lerp(end,filled)
						ink.draw_colored_polygon(PackedVector2Array([e.p-edge,e.p+edge,front+edge,front-edge]),DANGER_FILL)
				lane.append(e.p-edge)
				ink.draw_polyline(lane,DANGER,2.0)
			else:
				var points = PackedVector2Array([e.p])
				var fill_points = PackedVector2Array([e.p])
				var angle: float = game.sweep_angle(e)
				for i in 17:
					var ray = dir.rotated(lerpf(-angle,angle,i/16.0))*reach
					points.append(e.p+ray)
					fill_points.append(e.p+ray*filled)
				ink.draw_colored_polygon(points,Color("a84a303a"))
				if filled>0 and reach>0:
					ink.draw_colored_polygon(fill_points,DANGER_FILL)
				points.append(e.p)
				ink.draw_polyline(points,DANGER,2.0)
			if imminent and reach>=12.0:
				var side = dir.orthogonal()*5.0
				for offset in [3.0,10.0]:
					var tip: Vector2 = e.p+dir*(reach-offset)
					var tail = tip-dir*4.0
					var chevron = PackedVector2Array([tail+side,tip,tail-side])
					ink.draw_polyline(chevron,INK,4.0)
					ink.draw_polyline(chevron,TEXT_COLOR,2.0)
	for u in game.team+game.alive(game.foes):
		ink.draw_circle(u.p,6.5,Color("1f1a166a"))
		if u.id=="liu": marker_floor(u.p,"ece0a2")
		if u.id in ["captain","fiction"] and game.gates<2: marker_floor(u.p,"d18d51")

func draw_battle_overlay() -> void:
	for a in game.strikes:
		var point = visible_arrow(a)
		ink.draw_line(point-a.dir*11,point,Color("edbb66"),1.5)
		ink.draw_line(point-a.dir*3,point,Color("efddbb"),2.0)
	for flash in game.traces.slice(maxi(0,game.traces.size()-34)):
		var p: Vector2 = flash.p
		match str(flash.kind):
			"sword","axe","spear","bow":
				draw_weapon_contact(flash)
			"impact","block","miss","evade":
				draw_contact_mark(flash)
			"guard":
				ink.draw_arc(game.team[0].p,19,0,TAU,22,Color("e4aa62"),2)
			"heal":
				ink.draw_arc(p,22,0,TAU,22,Color("8fb3a3"),2)
			"rally":
				for side in [-1,1]:
					var center = p+Vector2(side*15,0)
					ink.draw_polyline(PackedVector2Array([center+Vector2(-4,3),center+Vector2(0,-2),center+Vector2(4,3)]),Color("d1b069"),2)
	if game.dodge_left>0:
		var player = game.team[0]
		var behind: Vector2 = -game.dodge_dir
		ink.draw_line(player.p+behind*7,player.p+behind*21,Color("d7ba78"),3)
	var pos = to_world(pointer)
	if Rect2(Vector2.ZERO,MAP).has_point(pos):
		ink.draw_line(pos-Vector2(6,0),pos+Vector2(6,0),GOLD)
		ink.draw_line(pos-Vector2(0,6),pos+Vector2(0,6),GOLD)
	if game.board_mask.fog:
		slab(Vector2.ZERO,Vector2(640,29),"8a968433")

func draw_weapon_contact(trace: Dictionary) -> void:
	var p: Vector2 = trace.p-Vector2(0,18)
	var direction: Vector2 = trace.dir
	var angle = direction.angle()
	var weight = clampf(trace.life/0.18,0.0,1.0)
	var special: bool = trace.special
	var glow = Color("edbd6b") if special else Color("d7bf96")
	var alpha = weight*0.80 if not reduce_motion else 0.72
	match str(trace.kind):
		"bow":
			ink.draw_line(p+direction*6,p+direction*18,Color(glow,alpha),1)
		"spear":
			ink.draw_line(p+direction*12,p+direction*trace.reach,Color(glow,alpha),2)
			ink.draw_line(p+direction*23,p+direction*trace.reach,Color("fff0bc",alpha*0.67),1)
		_:
			var heavy = trace.kind=="axe"
			var angle_size = 0.90 if heavy else 0.68
			var radius: float = trace.reach*(0.69 if heavy else 0.84)
			for segment in 8:
				var portion = segment/8.0
				var start_angle = angle+lerpf(-angle_size,angle_size,portion)
				var to = angle+lerpf(-angle_size,angle_size,(segment+1)/8.0)
				ink.draw_arc(p,radius,start_angle,to,4,Color(glow,alpha*(0.32+portion*0.68)),1.0+portion*(3.4 if heavy else 2.0))
			if special:
				ink.draw_arc(p,radius+4,angle-0.25,angle+angle_size,12,Color("e7a354",alpha),1)

func draw_contact_mark(trace: Dictionary) -> void:
	var at: Vector2 = trace.p
	var direction: Vector2 = trace.dir if not trace.dir.is_zero_approx() else Vector2.UP
	var side = direction.orthogonal()
	var age = clampf(1.0-trace.life/0.30,0,1)
	var strength = 1.0-age*0.54
	match str(trace.kind):
		"block":
			var steel = Color(Color("eac384"),strength)
			for offset in [-3,3]:
				var p = at+direction*offset
				ink.draw_line(p-side*6-direction*2,p+side*6+direction*2,steel,2)
		"miss":
			ink.draw_line(at-direction*7,at-direction*3,Color("aa9369"),1)
			ink.draw_line(at+direction*2,at+direction*6,Color("aa9369"),1)
		"evade":
			ink.draw_arc(at,13,0.0,TAU,22,Color(Color("a6c1b0"),strength),1)
		"impact":
			var tint = Color("e1a95e") if trace.weapon=="axe" else Color("dcbb91")
			var count = 4 if trace.weapon=="axe" else 3
			for i in count:
				var ray = direction.rotated((i-(count-1)*0.5)*0.65)
				var span = (6.0+7.0*age) if not reduce_motion else 7.0
				ink.draw_line(at+ray*3,at+ray*span,Color(tint,strength),2 if trace.weapon=="axe" else 1)
			if not reduce_motion:
				ink.draw_line(at-Vector2(5,2)+side*age*7,at+Vector2(4,3)+side*age*7,Color(Color("987552"),1.0-age),2)

func marker_floor(p: Vector2, tint: String) -> void:
	ink.draw_arc(p,13,0,TAU,18,Color(tint),1)

func draw_wagon() -> void:
	var p: Vector2 = game.wagon
	ink.draw_circle(p+Vector2(-10,6),7,Color("221b17"))
	ink.draw_circle(p+Vector2(10,6),7,Color("221b17"))
	slab(p-Vector2(15,11),Vector2(32,16),"916741")
	slab(p-Vector2(12,9),Vector2(25,9),"bb8c4e")
	slab(p+Vector2(14,-7),Vector2(14,3),"4c3528")

func label_chip(raw: String, p: Vector2, tint: Color, occupied: Array[Rect2], font_size: int) -> void:
	var dims = chip_font.get_string_size(raw,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var pad = Vector2(5,2)
	var area = Rect2(p-Vector2(dims.x*0.5,dims.y+5),dims+pad*2)
	var offsets = [Vector2.ZERO,Vector2(0,-23),Vector2(0,23),Vector2(0,-46),Vector2(0,46),Vector2(0,-70)]
	if display=="battle":
		var side = area.size.x+13
		offsets.append_array([Vector2(-side,0),Vector2(side,0),Vector2(-side,-20),Vector2(side,-20),Vector2(-side,20),Vector2(side,20)])
		for shift in [-side*2,side*2]:
			offsets.append_array([Vector2(shift,0),Vector2(shift,20)])
	for offset in offsets:
		var moved = Rect2(area.position+offset,area.size)
		moved.position = moved.position.clamp(box.position+Vector2(2,2),box.end-moved.size-Vector2(2,2))
		if occupied.any(func(item): return item.intersects(moved)):
			continue
		ink.draw_rect(moved,Color("211915"))
		ink.draw_string(chip_font,moved.position+pad+Vector2(0,chip_font.get_ascent(font_size)),raw,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
		occupied.append(moved)
		return

func draw_ally_bars(unit: Dictionary, occupied: Array[Rect2], font_size: int) -> void:
	var dimensions = Vector2(roundf(51*text_zoom),roundf(19*text_zoom))
	var anchor = to_screen(unit.p-Vector2(0,46))-Vector2(dimensions.x*0.5,dimensions.y)
	var values = [unit.hp/unit.max_hp,unit.mp/maxf(1.0,unit.max_mp),unit.fatigue/100.0]
	var colors = [Color("a5cb93"),Color("92c2df"),Color("e3ad5e")]
	var side = dimensions.x+4
	var above = -dimensions.y-3
	var offsets = [Vector2.ZERO,Vector2(0,above),Vector2(-side,0),Vector2(side,0),
			Vector2(-side,above),Vector2(side,above),Vector2(0,above*2),
			Vector2(-side*2,0),Vector2(side*2,0),Vector2(-side*3,0),Vector2(side*3,0)]
	for row in [3,4]:
		for column in [0,-1,1,-2,2]:
			offsets.append(Vector2(column*side,-row*above))
	for offset in offsets:
		var area = Rect2(anchor+offset,dimensions)
		area.position = area.position.clamp(box.position+Vector2(2,2),box.end-dimensions-Vector2(2,2))
		if occupied.any(func(item): return item.intersects(area.grow(1))):
			continue
		ink.draw_rect(area,INK)
		if unit.uid==inspected_uid:
			ink.draw_rect(area,TEXT_COLOR,false,1.0)
		var initial: String = Campaign.HEROES[unit.id][0].substr(0,1)
		var baseline = (dimensions.y-chip_font.get_height(font_size))*0.5+chip_font.get_ascent(font_size)
		ink.draw_string(chip_font,area.position+Vector2(3,baseline),initial,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,TEXT_COLOR)
		var height = floorf((dimensions.y-6)/3)
		var left = font_size+5
		for i in values.size():
			var rail = Rect2(area.position+Vector2(left,2+i*(height+1)),Vector2(dimensions.x-left-3,height))
			ink.draw_rect(rail,Color("564a42"))
			rail.size.x *= clampf(values[i],0.0,1.0)
			if rail.size.x>0:
				ink.draw_rect(rail,colors[i])
		occupied.append(area)
		return

func draw_chips() -> void:
	var used: Array[Rect2] = []
	var font_size = roundi(13*text_zoom)
	if display!="battle":
		for i in range(SITES.size()):
			var suffix = " 현재" if i==game.completed.size() else (" 잠김" if i>game.chapter+1 else "")
			label_chip(NAMES[i]+suffix,to_screen(SITES[i])+Vector2(0,-11),TEXT_COLOR,used,font_size)
		for region in [["한",Vector2(83,301)],["옹 · 새 · 적",Vector2(190,94)],["서초",Vector2(527,215)],["한(韓)",Vector2(328,222)],["제",Vector2(516,67)],["황하",Vector2(396,97)],["장강",Vector2(539,341)]]:
			label_chip(region[0],to_screen(region[1]),TEXT_COLOR,used,font_size)
		return
	for unit in game.alive(game.team+game.foes):
		var top_left = to_screen(unit.p-Vector2(12,45))
		var bottom_right = to_screen(unit.p+Vector2(12,3))
		used.append(Rect2(top_left,bottom_right-top_left))
	var warnings = 0
	for enemy in game.alive(game.foes):
		if warnings>=4: break
		if not enemy.attack.is_empty() and not enemy.attack.contact and enemy.p.distance_to(game.team[0].p)<180:
			warnings += 1
			var imminent: bool = enemy.attack.impact-enemy.attack.step<=4
			label_chip("직전" if imminent else "예고",to_screen(enemy.p-Vector2(0,45)),DANGER,used,font_size)
	for target in game.targets:
		var line = target[2]
		if game.hold_target==target[0]:
			line += " %d%%" % mini(100,roundi(game.hold/0.68*100))
		label_chip(line,to_screen(target[1])+Vector2(0,-4),GOLD,used,font_size)
	var damage_labels = 0
	for trace in game.traces:
		if trace.kind=="damage" and damage_labels<6:
			damage_labels += 1
			label_chip("−%d" % trace.value,to_screen(trace.p)+Vector2(0,-36),Color("eb9a72"),used,font_size)
	var response_label := 0
	for trace in game.traces.slice(maxi(0,game.traces.size()-12)):
		if trace.kind in ["block","evade"] and response_label<3:
			response_label += 1
			label_chip("막힘" if trace.kind=="block" else "회피",to_screen(trace.p)+Vector2(0,-17),Color("e8c998"),used,font_size)
	if game.chapter==2:
		label_chip("수레 HP %d" % roundi(game.wagon_hp),to_screen(game.wagon)+Vector2(0,25),GOLD,used,font_size)
	if game.chapter==3 and game.gates<2:
		label_chip("방책 2곳 개방 시 지휘관 공격 가능",to_screen(Vector2(325,54)),TEXT_COLOR,used,font_size)
	for ally in game.alive(game.team):
		if ally.uid==inspected_uid:
			draw_ally_bars(ally,used,font_size)
			break
	for ally in game.alive(game.team):
		if ally.uid!=inspected_uid:
			draw_ally_bars(ally,used,font_size)

func _draw() -> void:
	var reading = Time.get_ticks_usec()
	if game==null or size.x<10 or size.y<10 or (display=="battle" and game.team.is_empty()):
		return
	var scale_factor = minf(size.x/MAP.x,size.y/MAP.y)
	box = Rect2(Vector2.ZERO,MAP*scale_factor)
	box.position = (size-box.size)*0.5
	ink = self
	ink.draw_set_transform(box.position,0,Vector2.ONE*scale_factor)
	if display=="battle":
		battlefield()
	else:
		map_bg()
	ink.draw_set_transform(Vector2.ZERO)
	overlay.queue_redraw()
	render_build_usec = Time.get_ticks_usec()-reading

func draw_overlay() -> void:
	if game==null or box.size.x<=0 or (display=="battle" and game.team.is_empty()):
		return
	ink = overlay
	if display=="battle":
		overlay.draw_set_transform(box.position,0,Vector2.ONE*box.size.x/MAP.x)
		draw_battle_overlay()
	overlay.draw_set_transform(Vector2.ZERO)
	draw_chips()
	ink = self
