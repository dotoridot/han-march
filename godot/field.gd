extends Node2D

const Run = preload("res://run.gd")
const PALETTES = {
	"liu": ["78382d","be5540","e3a054","4c3027"],
	"fan": ["54382b","9b6040","cf8a4a","352924"],
	"xiao": ["28463e","467764","83a47b","293d37"],
	"xiang": ["4b354e","845476","c479a0","392d47"],
	"zhou": ["60412a","a66b42","c68d55","4c332a"],
	"cao": ["36485e","587084","8f9d9d","2d3644"],
	"bow": ["453f30","6b7047","9e9554","292e26"],
	"qin": ["303d3c","586762","889780","252b29"],
	"pike": ["394339","656955","a39d72","30382d"],
	"captain": ["583733","805049","a36b57","312626"],
}
var model
var motion = false
var pointer = Vector2(-100,-100)
var stage_time = 0.0
var maps = {}
var background_only = false
var background_layer
var background_key = ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if background_only:
		return
	for i in ["defense","camp","assault"]:
		maps[i] = terrain(i)
	background_layer = get_script().new()
	background_layer.maps = maps
	background_layer.model = model
	background_layer.background_only = true
	background_layer.z_index = -1
	add_child(background_layer)

func terrain(zone: String) -> ImageTexture:
	var img = Image.create_empty(640,384,false,Image.FORMAT_RGB8)
	var random = RandomNumberGenerator.new()
	random.seed = 245 + zone.length()
	var palette = ["3e4836","384033","424a38","47503c","665c44","716148","53523f","8b7550"]
	if zone == "assault":
		palette = ["454334","3c3c2d","4a4937","534d39","665540","735b40","56503c","8b6b47"]
	for y in range(0,384,4):
		for x in range(0,640,4):
			var road = absf(x - 315 - sin(y/47.0)*22.0) < 53
			var side_road = absf(x - 550 - cos(y/29.0)*12.0) < 17
			var camp_yard = zone == "camp" and Vector2(x,y).distance_to(Vector2(320,220)) < 84
			var color = palette[random.randi_range(4,6) if road or side_road or camp_yard else random.randi_range(0,3)]
			img.fill_rect(Rect2i(x,y,4,4),Color(color))
			if random.randf() < 0.24:
				img.fill_rect(Rect2i(x,y+1,random.randi_range(1,3),1),Color(palette[7 if random.randf() < 0.22 else 0]))
	return ImageTexture.create_from_image(img)

func rect(x: float, y: float, w: float, h: float, c: String) -> void:
	draw_rect(Rect2(roundf(x),roundf(y),w,h),Color(c))

func poly(points: Array, color: String) -> void:
	var vs = PackedVector2Array()
	for p in points:
		vs.append(Vector2(roundf(p[0]),roundf(p[1])))
	draw_colored_polygon(vs, Color(color))

func oval(p: Vector2, w: float, h: float, color: String) -> void:
	poly([[p.x-w,p.y],[p.x-w+3,p.y-h],[p.x+w-3,p.y-h],[p.x+w,p.y],[p.x+w-3,p.y+h],[p.x-w+3,p.y+h]],color)

func tree(x: float,y: float, variation: float) -> void:
	oval(Vector2(x+7,y+3),23*variation,8,"242f25")
	rect(x-2,y-21,5,22,"63523b")
	poly([[x-24*variation,y-9],[x-27*variation,y-18],[x-12,y-24],[x-15,y-31],[x-8,y-44],
		[x+9,y-45],[x+17,y-35],[x+14,y-29],[x+26*variation,y-22],[x+23*variation,y-11]],"2a382b")
	poly([[x-19*variation,y-17],[x-10,y-25],[x-7,y-38],[x+5,y-41],[x+13,y-34],[x+9,y-27],
		[x+21*variation,y-21],[x+11,y-15],[x-10,y-14]],"4a5a40")
	rect(x-9,y-32,11,3,"65724e")
	rect(x+5,y-23,10,2,"5a6846")
	rect(x-14,y-21,7,2,"546246")

func wall(x: float, y: float, w: float, qin: bool) -> void:
	rect(x,y-5,w,33,"34372c")
	rect(x,y-7,w,11,"857358" if qin else "9a805b")
	rect(x,y+4,w,21,"585440")
	for k in range(3):
		var px = x + (k % 2) * 8
		while px + 2 < x+w:
			rect(px,y+4+k*7,minf(14,x+w-px),6,["7c6b52","847255","74694f"][(int(px/8)+k)%3])
			if (int(px/8)+k)%4==0:
				rect(px,y+4+k*7,minf(12,x+w-px),1,"a6946b")
			px += 16
	for j in range(int(w/10)):
		rect(x+j*10,y-5,2,6,"524b38")
	rect(x,y+24,w,3,"a88e62")

func roof(x: float,y: float,w: float,red: bool) -> void:
	var dark = "51332b" if red else "294039"
	var mid = "784b38" if red else "435944"
	var light = "a47450" if red else "6b7651"
	poly([[x-7,y+20],[x+8,y],[x+w-8,y],[x+w+7,y+20],[x+w+9,y+24],[x-9,y+24]],dark)
	poly([[x-3,y+19],[x+9,y+2],[x+w-9,y+2],[x+w+3,y+19]],mid)
	for i in range(10, int(w)-5, 5):
		var drift = floorf((i/w-0.5)*15.0)
		poly([[x+i,y+2],[x+i+1,y+2],[x+i+drift+2,y+18],[x+i+drift,y+18]],light)
	rect(x+8,y-1,w-16,2,"b98e5f")
	rect(x-6,y+21,w+12,2,light)

func house(x: float,y: float,w: float,red: bool) -> void:
	oval(Vector2(x+w/2,y+8),w/2+8,11,"2e3127")
	rect(x,y-23,w,32,"674d35")
	rect(x+3,y-23,w-6,24,"96764d")
	for j in range(4,int(w)-2,10):
		rect(x+j,y-20,2,28,"4e3a2b")
	rect(x+w/2-6,y-13,12,20,"272723")
	rect(x+w/2-8,y-15,16,2,"ba8d58")
	roof(x-2,y-46,w+4,red)
	rect(x-1,y+7,w+3,3,"8f724b")

func banner(x: float,y: float,red: bool) -> void:
	var sway = 0.0 if motion else roundf(sin(stage_time*6.0+x)*2.0)
	rect(x,y-37,2,37,"bb9460")
	poly([[x+3,y-35],[x+23,y-32+sway],[x+19,y-25],[x+24,y-19+sway],[x+3,y-21]],
		"9d4b32" if red else "4e6250")
	rect(x+7,y-31,3,8,"d9a754")
	rect(x+5,y-28,7,2,"d9a754")
	rect(x-1,y-38,4,2,"dfb16c")

func torch(x: float,y: float) -> void:
	var flick = 0.0 if motion else floorf(fmod(stage_time*11+x,3))
	oval(Vector2(x,y-7),13,9,"a96b3533")
	oval(Vector2(x,y-6),8,5,"c0833a45")
	rect(x-1,y-3,2,13,"b0814b")
	poly([[x-4,y-2],[x-3,y-8],[x+1,y-12-flick],[x+5,y-7],[x+4,y-2]],"c6622c")
	rect(x-1,y-7,3,4,"fac66c")
	rect(x+3,y-13-flick,1,1,"eeb350")

func crate(x: float,y: float,w: float) -> void:
	rect(x-2,y+3,w+4,8,"31342a")
	rect(x,y-5,w,13,"7e5e3d")
	rect(x,y-6,w,4,"b48a54")
	rect(x+2,y-2,2,9,"503e2d")
	rect(x+w-4,y-2,2,9,"463827")
	rect(x,y+6,w,2,"614a32")

func tent(x: float,y: float,w: float) -> void:
	oval(Vector2(x+w/2,y+4),w/2+5,13,"34392b")
	poly([[x-2,y-7],[x+10,y-35],[x+w-10,y-35],[x+w+3,y-7]],"8e7351")
	poly([[x,y-7],[x+6,y-8],[x+w-5,y-8],[x+w,y+5],[x,y+5]],"9f7e51")
	rect(x+w/2-7,y-9,14,14,"49372a")
	rect(x+10,y-35,w-20,2,"bd935d")
	rect(x,y-8,w,2,"c39761")

func scene(zone: String) -> void:
	draw_texture(maps[zone],Vector2.ZERO)
	for pair in [[20,64],[60,46],[143,38],[221,26],[449,36],[517,56],[607,42],
		[17,155],[28,230],[610,142],[624,217],[18,284],[625,269],[57,372],[596,370]]:
		tree(pair[0],pair[1],0.85 if int(pair[0])%3==0 else 1.0)
	if zone == "defense":
		wall(0,284,263,false)
		wall(377,284,263,false)
		for x in [37,155,224,376,459,579]:
			house(x,300,32,true)
		for x in [267,370]:
			rect(x-2,283,7,28,"493426")
			rect(x,281,3,26,"b68b55")
		for x in range(275,372,6):
			rect(x,305,4,2,"a1885c")
		for x in [265,373]:
			banner(x,315,true)
		for x in [111,185,440,525]:
			torch(x,316)
		for b in [[94,128],[104,136],[482,112],[490,105],[51,228],[565,193]]:
			crate(b[0],b[1],18)
		for i in range(6):
			rect(521,308-i*3,23,2,"b18b59")
		banner(547,290,true)
	elif zone == "assault":
		wall(0,113,274,true)
		wall(365,113,141,true)
		wall(585,113,55,true)
		if model.route != "front":
			wall(274,113,91,true)
		if model.route != "side":
			wall(506,113,79,true)
		for x in [52,174,235,367,474,591]:
			house(x,127,30,false)
		house(310,48,64,true)
		for pair in [[289,63],[399,74],[142,252],[152,257],[62,152],[477,86]]:
			crate(pair[0],pair[1],19)
		for x in [255,380,508,576]:
			torch(x,149)
			banner(x+9,122,false)
	else:
		for pair in [[78,236],[154,255],[405,243],[483,214],[406,126]]:
			tent(pair[0],pair[1],63)
		for pair in [[156,186],[272,230],[390,227],[481,168]]:
			crate(pair[0],pair[1],18)
		house(288,133,68,true)
		torch(321,195)
		banner(344,184,true)

func person(u: Dictionary) -> void:
	var p: Vector2 = u.p.round()
	var x = p.x
	var y = p.y
	var pal = PALETTES[u.id]
	var wide = u.weapon == "방패·도끼" or u.id == "xiang"
	var high = u.id == "xiang" or u.id == "captain"
	var spread = 9 if wide else 6
	var step = roundf(sin(u.walk/4.0)*2.0) if u.moving and not motion else 0.0
	var side = signf(u.face.x)
	var up = u.face.y < -0.6
	if u.hp == 0:
		oval(p,13,4,"302b22")
		rect(x-8,y-5,17,5,pal[0])
		return
	oval(p,spread+5,4,"232922")
	if u.id == "liu":
		oval(p,spread+7,4,"d59a4f")
		oval(p,spread+4,2,"4b4933")
	if u.id in ["liu","xiao","xiang","captain"]:
		poly([[x-spread-3,y-4],[x-spread,y-20],[x+spread,y-20],[x+spread+2,y-4]],pal[0])
	rect(x-5,y-8+step,4,8,pal[3])
	rect(x+2,y-8-step,4,8,pal[3])
	rect(x-spread,y-20,spread*2,13,pal[3])
	rect(x-spread+1,y-19,spread*2-2,11,pal[1])
	rect(x-spread+1,y-19,spread*2-2,3,pal[2])
	for i in range(3):
		rect(x-spread+3,y-15+i*2,spread*2-6,1,pal[0])
		rect(x-1,y-15+i*2,2,1,pal[2])
	var top = y-27 if high else y-25
	rect(x-5,top,10,8,"2c2825")
	rect(x-4,top+1,8,6,pal[3] if up else "d6a277")
	rect(x-3,top-3,6,4,pal[0])
	rect(x-5,top,10,1,pal[2])
	if not up:
		rect(x+side*2,top+3,1,1,"492f25")
	if high or u.id == "liu":
		rect(x-1,top-7,3,5,pal[1])
		rect(x,top-7,1,5,pal[2])
	if u.hit > 0.12:
		rect(x-spread+2,y-17,spread*2-4,2,"e7a270")
	if u.weapon == "방패·도끼":
		var sx = x - (side if side != 0 else 1.0)*9.0
		poly([[sx-4,y-20],[sx+4,y-20],[sx+6,y-17],[sx+4,y-9],[sx,y-6],[sx-5,y-10]],"523d2c")
		rect(sx-3,y-18,7,8,"a77445")
		rect(sx-1,y-17,2,4,"d8a659")
	weapon(u,p+Vector2(0,-13))
	if u.hp < u.max_hp:
		rect(x-10,y-36,20,3,"25271c")
		rect(x-9,y-35,floorf(18.0*u.hp/u.max_hp),1,"d47b44" if u.is_enemy else "d3a64f")

func weapon(u: Dictionary, hand: Vector2) -> void:
	var dir: Vector2 = u.face
	var a: Dictionary = u.attack
	var extra = 0.0
	if not a.is_empty():
		dir = a.dir
		extra = -10.0 if a.stage == "wind" else (11.0 if a.stage == "hit" else -3.0)
		if u.weapon in ["검","방패·도끼"]:
			dir = dir.rotated(-0.8 if a.stage == "wind" else (0.25 if a.stage == "hit" else 1.05))
	var start = hand + dir * (6.0 + extra)
	match u.weapon:
		"장병기":
			draw_line(start-dir*9,start+dir*22,Color("b48a56"),2)
			draw_line(start+dir*20,start+dir*30,Color("c6c7a3"),3)
			draw_line(start+dir*23,start+dir*27+dir.orthogonal()*4,Color("a99f7f"),2)
		"활":
			var center = start+dir*5
			var side = dir.orthogonal()*8
			draw_polyline(PackedVector2Array([center+side,center+dir*4+side/2,center+dir*6,
				center+dir*4-side/2,center-side]),Color("c59a53"),2)
			draw_line(center+side,center-dir*(6 if extra < 0 else 1),Color("d5c198"))
			draw_line(center-dir*(6 if extra < 0 else 1),center-side,Color("d5c198"))
		"약낭":
			rect(start.x-3,start.y-4,8,9,"6c523d")
			rect(start.x-2,start.y-3,6,6,"c29356")
			rect(start.x-1,start.y-1,4,1,"815e3b")
		"방패·도끼":
			draw_line(start-dir*5,start+dir*13,Color("a17b54"),2)
			var pt = start+dir*12
			draw_line(pt-dir.orthogonal()*5,pt+dir.orthogonal()*5,Color("bcab8a"),4)
		_:
			draw_line(start,start+dir*18,Color("a4ad9a"),3)
			draw_line(start+dir*4,start+dir*18,Color("e4cea1"),1)
			draw_line(start-dir.orthogonal()*3,start+dir.orthogonal()*3,Color("b8884e"),2)

func _draw() -> void:
	if model == null or maps.is_empty():
		return
	var zone = "camp" if model.phase == "camp" else ("assault" if model.phase in ["assault","won"] or not model.route.is_empty() else "defense")
	if background_only:
		scene(zone)
		return
	var id = zone + "/" + model.route
	if id != background_key or background_layer.model != model:
		background_key = id
		background_layer.model = model
		background_layer.queue_redraw()
	if model.phase == "intro":
		return
	if zone == "defense":
		for w in model.wounds:
			if w.state == "waiting":
				oval(w.p,11,5,"4a382b")
				rect(w.p.x-9,w.p.y-5,18,6,"bc9560")
				rect(w.p.x-4,w.p.y-4,7,4,"9d4631")
		rect(Run.GATE.x-30,Run.GATE.y+7,60,5,"28271f")
		rect(Run.GATE.x-29,Run.GATE.y+8,58*model.gate/100.0,3,"e8a246")
	var people = model.team + model.living(model.foes)
	people.sort_custom(func(a,b): return a.p.y < b.p.y)
	for u in people:
		if u.is_enemy and u.attack.get("stage")=="wind":
			var direction: Vector2 = u.attack.dir
			var tip: Vector2 = u.p + direction * Run.WEAPONS[u.weapon][0]
			var side = direction.orthogonal() * 10.0
			poly([[u.p.x,u.p.y],[tip.x+side.x,tip.y+side.y],[tip.x-side.x,tip.y-side.y]],"a34a2a85")
		person(u)
	for projectile in model.arrows:
		draw_line(projectile.p,projectile.p-projectile.dir*12,Color("e4ab4f"),2)
	for fx in model.effects:
		if not fx.has("kind"):
			continue
		var origin: Vector2 = fx.p + Vector2(0,-6)
		var direction: Vector2 = fx.dir
		if fx.kind == "장병기":
			draw_line(origin+direction*13,origin+direction*60,Color("e8ad5a"),2)
			draw_line(origin+direction*24+direction.orthogonal()*4,origin+direction*68,Color("9f7047"))
		elif fx.kind in ["검","방패·도끼"]:
			var radius = 38.0 if fx.kind == "검" else 31.0
			draw_arc(origin,radius,direction.angle()-0.63,direction.angle()+0.65,14,Color("e5ac57"),3)
			if fx.kind == "방패·도끼":
				var spark = origin+direction*27
				rect(spark.x-1,spark.y-1,5,5,"c67137")
		elif fx.kind == "약낭":
			draw_arc(origin,21,0,TAU,16,Color("b7a443"),2)
	if model.phase == "assault" and model.loading >= 0:
		draw_arc(Run.SUPPLY,93,0,TAU,60,Color("d0a45277"),2)
	if model.rally_left > 0:
		draw_arc(model.team[0].p,28,0,TAU,18,Color("d7aa55"),2)
	if pointer.x > 0 and model.phase in ["defense","assault"]:
		draw_line(pointer+Vector2(-5,0),pointer+Vector2(-2,0),Color("e7ac54"),1)
		draw_line(pointer+Vector2(2,0),pointer+Vector2(5,0),Color("e7ac54"),1)
		draw_line(pointer+Vector2(0,-5),pointer+Vector2(0,-2),Color("e7ac54"),1)
		draw_line(pointer+Vector2(0,2),pointer+Vector2(0,5),Color("e7ac54"),1)
