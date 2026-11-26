extends Control

const Campaign = preload("res://campaign.gd")
const TEXT = preload("res://assets/NotoSansKR.ttf")
const SPRITES = preload("res://assets/march-sprites.png")
const SITES = [Vector2(116,265),Vector2(179,193),Vector2(485,160),Vector2(339,149),Vector2(502,246)]
const NAMES = ["한중","관중 · 삼진","팽성","형양 · 성고","해하"]
const MAP = Vector2(640,374)
const TILE = Vector2(88,76)
const INK = Color("1e1714")
const TEXT_COLOR = Color("f4e6c8")
const GOLD = Color("e3ad5e")
const RIVER = Color("527974")
var game: Campaign
var display = "map"
var transfer = 0.0
var reduce_motion = false
var box = Rect2()
var text_zoom = 1.0
var backdrop: Texture2D
var cache_key = [-1,0]
var pointer = Vector2.ZERO
var render_build_usec = 0
var chip_font: FontVariation
var drafted_map: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chip_font = FontVariation.new()
	chip_font.base_font = TEXT
	chip_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):520}

func to_world(global_at: Vector2) -> Vector2:
	return ((global_at-get_global_rect().position-box.position)/box.size)*MAP if box.size.x>0 else MAP*0.5

func to_screen(world_at: Vector2) -> Vector2:
	return box.position + world_at*(box.size/MAP)

func slab(p: Vector2, dimensions: Vector2, tint: String) -> void:
	draw_rect(Rect2(p,dimensions),Color(tint))

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
	var rng = RandomNumberGenerator.new()
	rng.seed = game.battle_seed
	var paper = Image.create(640,374,false,Image.FORMAT_RGBA8)
	var tones = ["4b4634","493934","4e402d","3c4537"]
	paper.fill(Color(tones[game.chapter]))
	for i in 6100:
		var p = Vector2i(rng.randi_range(0,639),rng.randi_range(0,373))
		var base = Color(tones[game.chapter])
		var value = rng.randf_range(-0.055,0.072)
		paper.fill_rect(Rect2i(p,Vector2i(mini(640-p.x,rng.randi_range(1,5)),mini(374-p.y,2))),Color(base.r+value,base.g+value,base.b+value))
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
		draw_colored_polygon(shape,Color(fills[i]))
		var outline = shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline,Color("795e3f"),1)
	if drafted_map==null:
		drafted_map = paper_map()
	draw_texture(drafted_map,Vector2.ZERO)
	var river = PackedVector2Array([Vector2(0,63),Vector2(85,81),Vector2(134,29),Vector2(226,47),Vector2(244,100),Vector2(226,165),Vector2(308,161),Vector2(379,113),Vector2(468,95),Vector2(548,53),Vector2(640,42)])
	draw_polyline(river,Color("2c3932"),9)
	draw_polyline(river,RIVER,3)
	var yangtze = PackedVector2Array([Vector2(0,322),Vector2(126,306),Vector2(206,328),Vector2(321,300),Vector2(417,315),Vector2(543,306),Vector2(639,260)])
	draw_polyline(yangtze,Color("3d5a53"),5)
	for i in 38:
		var px = 15+(i*83)%605
		var py = 29+(i*119)%307
		if py>196 and py<299 and px<310 or py<111 and px<228:
			var peak = Vector2(px,py)
			draw_colored_polygon(PackedVector2Array([peak+Vector2(-8,6),peak+Vector2(0,-8),peak+Vector2(10,6)]),Color("675642"))
			draw_line(peak+Vector2(0,-8),peak+Vector2(9,5),Color("99815b"))
	for index in range(4):
		for branch in 2:
			var done = game.completed.any(func(route): return route[0]==index and route[1]==branch)
			var active = game.chapter==index and (game.selected_route<0 or game.selected_route==branch)
			var tint = Color("af824b") if done else (GOLD if active else Color("726451"))
			draw_polyline(route_points(index,branch),tint,2.0 if active else 1.0)
	for i in range(SITES.size()):
		var at: Vector2 = SITES[i]
		draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),INK)
		draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),GOLD if i<=game.chapter+1 else Color("a39379"))
		draw_rect(Rect2(at-Vector2(1,1),Vector2(2,2)),TEXT_COLOR)
	if display=="travel":
		var at = march_position(game.chapter,game.selected_route,transfer)
		draw_circle(at,9,INK)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-5,4),at+Vector2(-5,-5),at+Vector2(7,-1)]),GOLD)

func draw_landmark(at: Vector2, large: bool) -> void:
	var width = 66 if large else 46
	slab(at+Vector2(-3,1),Vector2(width+6,8),"27291e")
	slab(at+Vector2(0,-15),Vector2(width,24),"704f35")
	slab(at+Vector2(4,-11),Vector2(width-8,18),"a28259")
	var tall = 7 if large else 3
	draw_colored_polygon(PackedVector2Array([at+Vector2(-6,-12),at+Vector2(6,-22-tall),at+Vector2(width-6,-22-tall),at+Vector2(width+6,-12)]),Color("51362b"))
	draw_line(at+Vector2(-5,-12),at+Vector2(width+5,-12),Color("bb8660"),2)
	for x in range(8,width,15):
		slab(at+Vector2(x,-7),Vector2(5,9),"594339")

func battlefield() -> void:
	if cache_key != [game.chapter,game.battle_seed] or backdrop==null:
		cache_key = [game.chapter,game.battle_seed]
		backdrop = terrain()
	draw_texture(backdrop,Vector2.ZERO)
	match game.chapter:
		0:
			slab(Vector2(0,62),Vector2(640,18),"74634c")
			for x in range(7,640,72): draw_landmark(Vector2(x,78),true)
			slab(Vector2(258,97),Vector2(124,276),"80705155")
		1:
			var water = PackedVector2Array([Vector2(22,0),Vector2(84,74),Vector2(37,175),Vector2(87,271),Vector2(48,374)])
			draw_polyline(water,Color("35534e"),36)
			draw_polyline(water,Color("5b7771"),6)
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
		draw_rect(wall,Color("4a392c"))
		draw_line(wall.position,Vector2(wall.end.x,wall.position.y),Color("8b6f4b"),2)
		for x in range(int(wall.position.x)+4,int(wall.end.x),11):
			slab(Vector2(x,wall.position.y+4),Vector2(5,5),"6c5238")
	if game.board_mask.ridge:
		for i in 3: draw_arc(Vector2(390,117),52+i*12,-2.4,0.1,16,Color("877052"),2)
	elif game.board_mask.mud:
		for i in 12: slab(Vector2(45+(i*163)%535,208+(i*13)%90),Vector2(24,7),"453c30")
	for target in game.targets:
		var p: Vector2 = target[1]
		draw_circle(p,15,Color("654b2d"))
		draw_arc(p,15,0,TAU,20,GOLD,2)
		slab(p-Vector2(1,7),Vector2(3,13),"e3ad5e")
		slab(p+Vector2(2,-6),Vector2(9,5),"983f28")
	if game.chapter==2:
		marker_floor(game.wagon,"ad7545")
	if game.training_ticks>0:
		var origin: Vector2 = game.training_at
		var lane = Rect2(origin-Vector2(13,70),Vector2(26,94))
		draw_rect(lane,Color("a649306c"))
		draw_rect(lane,Color("f4b372"),false,2)
		draw_line(origin-Vector2(7,25),origin,Color("f4b372"),2)
		draw_line(origin+Vector2(7,-25),origin,Color("f4b372"),2)
	for e in game.alive(game.foes):
		if not e.attack.is_empty() and e.attack.frame<3:
			var dir: Vector2 = e.attack.dir
			var reach = game.max_range(e)
			if e.weapon=="bow":
				var edge: Vector2 = dir.orthogonal()*13
				var cutoff: float = game.line_obstacle(e.p,e.p+dir*reach)
				if cutoff<INF: reach *= sqrt(cutoff)
				draw_colored_polygon(PackedVector2Array([e.p-edge,e.p+edge,e.p+dir*reach+edge,e.p+dir*reach-edge]),Color("a84a3077"))
				draw_line(e.p,e.p+dir*reach,Color("de754b"),1)
			else:
				var points = PackedVector2Array([e.p])
				var angle: float = game.sweep_angle(e)
				for step in 17:
					points.append(e.p+dir.rotated(lerpf(-angle,angle,step/16.0))*reach)
				draw_colored_polygon(points,Color("b6533788"))
				draw_arc(e.p,reach,dir.angle()-angle,dir.angle()+angle,16,Color("e48a60"),2)
	var bodies = game.team+game.alive(game.foes)
	bodies.sort_custom(func(a,b): return a.uid<b.uid if is_equal_approx(a.p.y,b.p.y) else a.p.y<b.p.y)
	for u in bodies:
		portrait(u)
	for a in game.strikes:
		draw_line(a.p-a.dir*12,a.p,Color("edbb66"),2)
	for flash in game.traces:
		var p: Vector2 = flash.p
		if flash.kind in ["sword","axe","spear"]:
			var direction: Vector2 = flash.dir
			if flash.kind=="spear":
				draw_line(p+direction*14,p+direction*flash.reach,Color("e9bc73"),3)
			else:
				draw_arc(p,flash.reach*0.8,direction.angle()-0.68,direction.angle()+0.63,13,Color("daad67"),2)
		elif flash.kind=="heal":
			draw_arc(p,22,0,TAU,22,Color("8fb3a3"),2)
	if game.dodge_left>0:
		var player = game.team[0]
		var behind: Vector2 = -game.dodge_dir
		draw_line(player.p+behind*7,player.p+behind*21,Color("d7ba78"),3)
	var pos = to_world(pointer)
	if Rect2(Vector2.ZERO,MAP).has_point(pos):
		draw_line(pos-Vector2(6,0),pos+Vector2(6,0),GOLD)
		draw_line(pos-Vector2(0,6),pos+Vector2(0,6),GOLD)
	if game.board_mask.fog:
		slab(Vector2.ZERO,Vector2(640,29),"8a968433")

func marker_floor(p: Vector2, tint: String) -> void:
	draw_arc(p,13,0,TAU,18,Color(tint),1)

func draw_wagon() -> void:
	var p: Vector2 = game.wagon
	draw_circle(p+Vector2(-10,6),7,Color("221b17"))
	draw_circle(p+Vector2(10,6),7,Color("221b17"))
	slab(p-Vector2(15,11),Vector2(32,16),"916741")
	slab(p-Vector2(12,9),Vector2(25,9),"bb8c4e")
	slab(p+Vector2(14,-7),Vector2(14,3),"4c3528")

func portrait(u: Dictionary) -> void:
	var p: Vector2 = u.p.round()
	if u.hp<=0:
		slab(p-Vector2(8,3),Vector2(15,5),"474034")
		return
	var actor = {"liu":0,"fan":1,"xiao":2,"xiang":3,"captain":3,"fiction":3,"cao":3,"han":4,"archer":4}.get(u.id,5)
	var heading: Vector2 = u.face if u.attack.is_empty() else u.attack.dir
	var direction = posmod(roundi((heading.angle()-PI/2)/(PI/4)),8)
	var pose = 0 if not u.move or reduce_motion else (1+int(u.step/5.0)%2)
	if u.hit>0: pose = 9
	if not u.attack.is_empty(): pose = 3+u.attack.node.painted_pose
	var number: int = actor*80+direction*10+pose
	var source = Vector2(number%16,number/16)*TILE
	source.y = floorf(float(number)/16)*TILE.y
	var tint = Color("df8c77") if u.side else Color.WHITE
	if u.id=="cao": tint = Color("d8d1a2")
	if u.id=="fiction": tint = Color("aa9181")
	if u.id=="liu": marker_floor(p,"ece0a2")
	if u.id in ["captain","fiction"] and game.gates<2: marker_floor(p,"d18d51")
	draw_texture_rect_region(SPRITES,Rect2(p-Vector2(44,54),TILE),Rect2(source,TILE),tint)

func label_chip(raw: String, p: Vector2, tint: Color, occupied: Array[Rect2], font_size: int) -> void:
	var dims = chip_font.get_string_size(raw,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var pad = Vector2(5,2)
	var area = Rect2(p-Vector2(dims.x*0.5,dims.y+5),dims+pad*2)
	for offset in [0,-23,23,-46,46,-70]:
		var moved = Rect2(area.position+Vector2(0,offset),area.size)
		moved.position = moved.position.clamp(box.position+Vector2(2,2),box.end-moved.size-Vector2(2,2))
		if occupied.any(func(item): return item.intersects(moved)):
			continue
		draw_rect(moved,Color("211915"))
		draw_string(chip_font,moved.position+pad+Vector2(0,chip_font.get_ascent(font_size)),raw,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
		occupied.append(moved)
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
	for u in game.alive(game.team):
		var at = to_screen(u.p)
		used.append(Rect2(at-Vector2(15,30),Vector2(30,34)))
	for u in game.alive(game.team):
		var at = to_screen(u.p)
		label_chip("%s  HP %d  MP %d  피로 %d" % [Campaign.HEROES[u.id][0],ceili(u.hp),floori(u.mp),roundi(u.fatigue)],at+Vector2(0,-28),TEXT_COLOR,used,font_size)
	for target in game.targets:
		var line = target[2]
		if game.hold_target==target[0]:
			line += " %d%%" % mini(100,roundi(game.hold/0.68*100))
		label_chip(line,to_screen(target[1])+Vector2(0,-4),GOLD,used,font_size)
	var warnings = 0
	for enemy in game.alive(game.foes):
		if warnings>=4: break
		if not enemy.attack.is_empty() and enemy.attack.frame<3 and enemy.p.distance_to(game.team[0].p)<180:
			warnings += 1
			label_chip("예고",to_screen(enemy.p)+Vector2(0,-31),Color("f5af77"),used,font_size)
	var damage_labels = 0
	for trace in game.traces:
		if trace.kind=="damage" and damage_labels<6:
			damage_labels += 1
			label_chip("−%d" % trace.value,to_screen(trace.p)+Vector2(0,-36),Color("eb9a72"),used,font_size)
	if game.chapter==2:
		label_chip("수레 HP %d" % roundi(game.wagon_hp),to_screen(game.wagon)+Vector2(0,25),GOLD,used,font_size)
	if game.chapter==3 and game.gates<2:
		label_chip("방책 2곳 개방 시 지휘관 공격 가능",to_screen(Vector2(325,54)),TEXT_COLOR,used,font_size)

func _draw() -> void:
	var reading = Time.get_ticks_usec()
	if game==null or size.x<10 or size.y<10:
		return
	var scale_factor = minf(size.x/MAP.x,size.y/MAP.y)
	box = Rect2(Vector2.ZERO,MAP*scale_factor)
	box.position = (size-box.size)*0.5
	draw_set_transform(box.position,0,Vector2.ONE*scale_factor)
	if display=="battle":
		battlefield()
	else:
		map_bg()
	draw_set_transform(Vector2.ZERO)
	draw_chips()
	render_build_usec = Time.get_ticks_usec()-reading
