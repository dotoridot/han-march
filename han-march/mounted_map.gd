extends Control

signal route_pressed(index: int)
signal route_hovered(index: int)

const TRAILS = [
	[Vector2(0,4.2),Vector2(0,1.7),Vector2(0,0),Vector2(-1.7,-1.2),Vector2(-3.4,-1.6),Vector2(-4.6,-3.2)],
	[Vector2(0,4.2),Vector2(0,1.7),Vector2(0,0),Vector2(1.4,-1.4),Vector2(3.1,-2.0),Vector2(4.7,-3.4)],
]
const FIELDS = [
	[Color("666341"),Color("3d4a38"),Color("425c59"),Vector2(-2.3,0.1),2.2],
	[Color("77704b"),Color("474335"),Color("536568"),Vector2(-2.5,0.9),0.78],
	[Color("78644b"),Color("544537"),Color("465c5e"),Vector2(2.9,0.8),1.15],
	[Color("6a6250"),Color("443e39"),Color("55525b"),Vector2(3.1,0.4),2.7],
]
const WATER_Y = 0.12
const REGIONS = [
	preload("res://assets/strategy_map/guanzhong.webp"),
	preload("res://assets/strategy_map/pengcheng.webp"),
	preload("res://assets/strategy_map/xingyang.webp"),
	preload("res://assets/strategy_map/gaixia.webp"),
]
const RIDER = preload("res://assets/strategy_rider.svg")
const FLAG = preload("res://assets/strategy_flag.svg")
const FLAG_OFFSET = Vector2(-16,-49)
const FLAG_SIZE = Vector2(53,51)
const VILLAGE = preload("res://assets/strategy_village.svg")
const INK = Color("292522")
const PAPER = Color("f4ecdc")
const VERMILION = Color("a92f22")
const GOLD = Color("e5b75d")

var chapter := -1
var point := TRAILS[0][0] as Vector2
var nearby := -1
var focused_route := -1
var hovered_route := -1
var selected_route := -1
var flags: Array[Button] = []
var nameplates: Array[Label] = []
var water: PackedVector2Array
var terrain: Texture2D
var route_area := Vector2.ZERO
var walk_time := 0.0
var gait := 0.0
var facing := 1.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(layout_flags)
	for index in TRAILS.size():
		var flag = Button.new()
		flag.flat = true
		flag.focus_mode = FOCUS_NONE
		for state in ["normal","hover","pressed","disabled","focus"]:
			flag.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		add_child(flag)
		flag.pressed.connect(func(): route_pressed.emit(index))
		flag.mouse_entered.connect(func(): route_hovered.emit(index))
		flag.mouse_exited.connect(func(): route_hovered.emit(-1))
		flags.append(flag)

		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color",PAPER)
		var surface = StyleBoxFlat.new()
		surface.bg_color = Color("252321f2")
		surface.content_margin_left = 9
		surface.content_margin_right = 9
		surface.content_margin_top = 3
		surface.content_margin_bottom = 3
		label.add_theme_stylebox_override("normal",surface)
		label.mouse_filter = MOUSE_FILTER_IGNORE
		flag.add_child(label)
		nameplates.append(label)

func setup(index: int, routes: Array, supply: int, zoom: float, selection: int) -> void:
	if chapter!=index:
		chapter = index
		terrain = REGIONS[chapter]
		water.clear()
		for sample in 241:
			var y = -30.0+float(sample)*0.25
			var x = [-2.3+0.58*sin(y*0.64),-3.5-0.9*sin(y*0.71),
				3.1+0.8*cos(y*0.81),4.6+sin(y*0.9)][chapter]
			water.append(Vector2(x,y))
	selected_route = selection
	focused_route = -1
	hovered_route = -1
	facing = 1.0
	reset_position(point)
	for index_on_map in flags.size():
		var locked: bool = selection<0 and supply+routes[index_on_map][3]<0
		var flag = flags[index_on_map]
		var label = nameplates[index_on_map]
		flag.disabled = locked or selection>=0
		flag.mouse_filter = MOUSE_FILTER_STOP if selection<0 else MOUSE_FILTER_IGNORE
		label.text = "%s%s" % [routes[index_on_map][0]," / 보급 부족" if locked else ""]
		flag.accessibility_name = label.text
		flag.tooltip_text = label.text
		flag.mouse_default_cursor_shape = CURSOR_ARROW if locked else CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size",roundi(15*zoom))
	layout_flags()

func map_pixel(at: Vector2) -> Vector2:
	var top = maxf(size.y*0.3116,route_area.x)
	var bottom = minf(size.y*0.6612,route_area.y-18.0) if route_area.y>0.0 else size.y*0.6612
	var height = maxf(bottom-top,36.0)
	var south = clampf(at.x/4.7,0,1)*height*0.20 if chapter==3 else 0.0
	return Vector2((0.5+at.x*0.066)*size.x,top+(at.y+3.4)/7.6*height+south)

func fit_routes(top: float, bottom: float) -> void:
	var area = Vector2(top,bottom)
	if not route_area.is_equal_approx(area):
		route_area = area
		layout_flags()

func layout_flags() -> void:
	var compact = false
	for index in flags.size():
		var marker = map_pixel(TRAILS[index][-1])
		if route_area.y>0 and marker.y+nameplates[index].get_minimum_size().y>route_area.y-4:
			compact = true
	for index in flags.size():
		var flag = flags[index]
		var label = nameplates[index]
		var label_size = label.get_minimum_size()
		var marker = map_pixel(TRAILS[index][-1])
		var art = Rect2(marker+FLAG_OFFSET,FLAG_SIZE)
		var label_at = marker-Vector2(label_size.x*0.5,0)
		if compact:
			var x = art.end.x+3 if index==0 else art.position.x-label_size.x-3
			label_at = Vector2(x,art.position.y+5)
		var bounds = art.merge(Rect2(label_at,label_size))
		flag.position = bounds.position
		flag.size = bounds.size
		label.position = label_at-bounds.position
		label.size = label_size
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PAPER)
	if chapter<0:
		return
	if terrain!=null:
		draw_texture_rect(terrain,Rect2(Vector2.ZERO,size),false)
	draw_waterways()
	var short_side = minf(size.x,size.y)
	var village_width = clampf(short_side*0.16,70.0,118.0)
	for index in TRAILS.size():
		var marker = map_pixel(TRAILS[index][-1])
		var offset = Vector2(village_width*(-1.03 if index==0 else 0.32),-village_width*0.52)
		var destination = Rect2(marker+offset,Vector2(village_width,village_width*0.6))
		draw_texture_rect_region(VILLAGE,destination,Rect2(index*160,0,160,96))
	var highlight = selected_route if selected_route>=0 else hovered_route
	if highlight<0: highlight = nearby if nearby>=0 else focused_route
	var paint_order = [1,0] if highlight==0 else [0,1]
	for index in paint_order:
		var trail: Array = TRAILS[index]
		var points = PackedVector2Array([map_pixel(trail[0])])
		for i in range(1,trail.size()-1):
			var bend = map_pixel(trail[i])
			var from = bend.lerp(map_pixel(trail[i-1]),0.13)
			var to = bend.lerp(map_pixel(trail[i+1]),0.13)
			for sample in 6:
				var weight = float(sample)/5.0
				points.append(from.lerp(bend,weight).lerp(bend.lerp(to,weight),weight))
		points.append(map_pixel(trail[-1]))
		var bold = index==highlight
		var blocked = flags[index].disabled and selected_route<0
		var tint = VERMILION if bold and not blocked else Color("675045")
		draw_polyline(points,Color("f7efdd"),9.0 if bold else 7.0,true)
		draw_polyline(points,tint,4.0 if bold else 2.0,true)
	for index in TRAILS.size():
		var marker = map_pixel(TRAILS[index][-1])
		if index==highlight:
			var rim = Color("c2ad9b") if flags[index].disabled and selected_route<0 else GOLD
			draw_circle(marker,14,rim,true,-1,true)
			draw_circle(marker,9,INK,true,-1,true)
		var tint = Color("a6978d") if flags[index].disabled and selected_route<0 else Color.WHITE
		draw_texture_rect(FLAG,Rect2(marker+FLAG_OFFSET,FLAG_SIZE),false,tint)
		if selected_route==index:
			draw_circle(marker,5,GOLD,true,-1,true)
	var base = map_pixel(point)
	var token_size = clampf(short_side*0.135,68.0,106.0)
	draw_set_transform(base+Vector2(3,2),0,Vector2(1,0.31))
	draw_circle(Vector2.ZERO,token_size*0.29,Color("271e1a36"),true,-1,true)
	draw_set_transform(base+Vector2(0,gait),0,Vector2(facing,1))
	draw_texture_rect(RIDER,Rect2(Vector2(-token_size*0.5,-token_size*0.84),Vector2.ONE*token_size),false)
	draw_set_transform(Vector2.ZERO)

func draw_waterways() -> void:
	if chapter!=1:
		var center: Vector2 = FIELDS[chapter][3]
		var basin = map_pixel(center)
		var radius = [0.073,0.0,0.054,0.061][chapter]*size.x
		var depth = minf(radius*0.53,map_pixel(center+Vector2.DOWN).y-basin.y)
		var shore = PackedVector2Array()
		for i in 112:
			var angle = TAU*float(i)/112.0
			var edge = 1.0+0.11*sin(3*angle)+0.07*cos(5*angle+0.6)+0.022*sin(11*angle)
			shore.append(Vector2(radius*cos(angle),depth*sin(angle))*edge)
		for wash in 9:
			var ring = PackedVector2Array()
			for i in shore.size():
				var grain = 0.008*sin(i*4.53+wash*3.25)+0.012*sin(i*0.65+wash*0.38)
				ring.append(basin+shore[i]*(1.04-wash*0.025+grain)+Vector2(wash*0.42,wash*0.31))
			var shade = Color("496266").lerp(Color("233e50"),float(wash)/8.0)
			shade.a = 0.24+wash*0.075
			draw_colored_polygon(ring,shade)
		for i in shore.size():
			var slip = sin(i*2.33+0.6)
			if slip>0.43:
				var edge = basin+shore[i]*(0.958+0.027*sin(i))
				var tip = basin+shore[(i+1)%shore.size()]*(1.012+0.035*sin(i*1.4))
				draw_line(edge,tip,Color("364f5380"),1.4+slip,true)
			if i%2==1 and slip<0.46:
				var shift = Vector2(sin(i*7.0)*0.59*radius,cos(i*4.3)*0.68*depth)
				var sweep = radius*(0.025+0.09*pow(absf(slip),1.5))
				var at = basin+shift
				var ended = at+Vector2(sweep+0.8,sweep*0.26*sin(i))
				draw_line(at,ended,Color("adbbb27b").lerp(Color("637b8262"),absf(slip)),0.7,true)
	if chapter==0:
		return
	draw_channel(water,[0.0,0.064,0.047,0.056][chapter])
	if chapter==1:
		# The ferry lands at a western bend. The second path follows the eastern levee.
		var ferry = PackedVector2Array()
		var levee = PackedVector2Array()
		for at in water:
			ferry.append(Vector2(at.x-1.55*exp(-pow((at.y+3.4)/1.42,2)),at.y))
			levee.append(Vector2(5.32+0.27*cos(at.y*0.75),at.y))
		draw_channel(ferry,0.024)
		draw_channel(levee,0.022)
		var landing = map_pixel(TRAILS[0][-1])+Vector2(0,-2)
		draw_line(landing,landing+Vector2(19,-9),Color("403a37"),7,true)
		for plank in 4:
			var post = landing+Vector2(5.0,-2.4)*plank
			draw_line(post+Vector2(-2,-3),post+Vector2(2,3),Color("a79172"),1.3,true)

func draw_channel(channel: PackedVector2Array, width: float) -> void:
	var west_bank = PackedVector2Array()
	var east_bank = PackedVector2Array()
	var shade_bank = PackedVector2Array()
	var bed = PackedVector2Array()
	for i in channel.size():
		var at = channel[i]
		var pixel = map_pixel(at)
		var breadth = (0.86+0.18*sin(at.y*0.83)+0.12*cos(at.y*1.45)+0.05*sin(at.y*5.1))*width*size.x
		west_bank.append(pixel-Vector2(breadth*(0.53+0.018*sin(i*2.2)),0))
		east_bank.append(pixel+Vector2(breadth*(0.48+0.025*sin(i*1.5)),0))
		shade_bank.append(pixel-Vector2(breadth*(0.33+0.08*sin(at.y*1.82)),0))
		bed.append(pixel-Vector2(breadth*(0.13+0.15*sin(at.y*1.01)),0))
	var rim = east_bank.duplicate()
	rim.reverse()
	draw_colored_polygon(west_bank+rim,Color("7b909085"))
	draw_colored_polygon(shade_bank+rim,Color("4d6b71de"))
	draw_colored_polygon(bed+rim,Color("304f5bc8"))
	for i in range(1,channel.size()-2):
		if i%3==1:
			var bank = west_bank[i]
			var tip = west_bank[i+1]+Vector2(4.0*cos(i*3.0),4.0*sin(i))
			draw_line(bank,tip,Color("3b535550"),1.1,true)
		if sin(i*5.3)<0.1: continue
		var pixel = map_pixel(channel[i])
		var shift = Vector2(width*size.x*sin(i*3.0)*0.23,0)
		var next_pixel = map_pixel(channel[i+2])
		draw_line(pixel+shift,pixel.lerp(next_pixel,0.65+0.25*sin(i))+shift,Color("a2b5ac88"),1.0,true)

func path_distance(at: Vector2) -> float:
	var result := INF
	for trail in TRAILS:
		for i in range(trail.size()-1):
			result = minf(result,at.distance_to(Geometry2D.get_closest_point_to_segment(at,trail[i],trail[i+1])))
	return result

func elevation(at: Vector2, road_gap: float) -> float:
	var field: Array = FIELDS[chapter]
	var water_distance: float = at.distance_to(field[3])
	if chapter==1:
		water_distance = absf(at.x+3.5+0.9*sin(at.y*0.71))+0.35
	elif chapter==2:
		water_distance = minf(water_distance,absf(at.x-3.1-0.8*cos(at.y*0.81))+0.70)
	elif chapter==3:
		water_distance = minf(water_distance,absf(at.x-4.6-sin(at.y*0.9))+1.00)
	var ridge = pow(maxf(0.0,absf(at.x)-2.8),1.2)*0.27
	var peaks = (0.50+0.30*sin(at.x*1.1+at.y*0.9)+0.20*cos(at.y*1.6-at.x))*field[4]
	var base = 0.31 + 0.12*sin(at.x*1.3+at.y)*cos(at.y*0.8)
	var bank = smoothstep(0.7,2.15,water_distance)
	return lerpf(-0.36,base+(ridge+peaks)*smoothstep(0.42,1.75,road_gap),bank) if road_gap>0.62 else base

func reset_position(at: Vector2) -> void:
	point = at if on_road(at) else TRAILS[0][0]
	nearby = -1
	ride(Vector2.ZERO,0.0,true)

func on_road(at: Vector2) -> bool:
	var dist = path_distance(at)
	return dist<=0.53 and elevation(at,dist)>WATER_Y

func ride(direction: Vector2, dt: float, reduced: bool) -> int:
	var delta = direction.normalized()*3.2*dt
	var next = point+delta
	if direction!=Vector2.ZERO:
		# Keep the mount on the road even when a key points along its verge.
		var closest = point
		var gap = INF
		for trail in TRAILS:
			for i in range(trail.size()-1):
				var candidate = Geometry2D.get_closest_point_to_segment(next,trail[i],trail[i+1])
				if next.distance_to(candidate)<gap:
					gap = next.distance_to(candidate)
					closest = candidate
		if not on_road(next) and point.distance_to(closest)<=delta.length()*1.5:
			next = closest if gap<0.95 else point
		if not on_road(next):
			next = point
	place_rider(next,dt,reduced)
	var previous = nearby
	nearby = -1
	for route in TRAILS.size():
		if point.distance_to(TRAILS[route][-1])<0.90:
			nearby = route
	if previous!=nearby:
		queue_redraw()
	return nearby

func place_rider(next: Vector2, dt: float, reduced: bool) -> void:
	var motion = next-point
	var previous_gait = gait
	point = next
	if absf(motion.x)>0.001:
		facing = signf(motion.x)
	if not reduced and motion.length_squared()>0.00001:
		walk_time += dt*14.0
		gait = -absf(sin(walk_time))*3.0
	else:
		gait = 0.0
	if motion!=Vector2.ZERO or previous_gait!=gait:
		queue_redraw()

func travel(branch: int, progress: float, dt: float, reduced: bool) -> void:
	var trail = TRAILS[branch]
	var part = clampf(progress,0,1)*float(trail.size()-1)
	var i = mini(int(part),trail.size()-2)
	place_rider(trail[i].lerp(trail[i+1],part-i),dt,reduced)
