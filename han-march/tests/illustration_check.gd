extends SceneTree

const View = preload("res://landscape.gd")
const Figure = preload("res://battle_figure.gd")
const Rules = preload("res://campaign.gd")
const OLD = preload("res://assets/march-sprites.png")
const PAPER = Color("494438")
var failed := 0
var checks := 0
var game: Rules
var field: View
var out: String
var colors: Image
var normals: Image
var legacy: Image
var compare := false
var profile_render := false
var alpha_counts := {}

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failed += 1
		printerr(description)

func rig(unit: Dictionary) -> Figure:
	return field.actors[unit.uid]

func bounds(sprite: Node2D) -> Rect2i:
	var origin = sprite.get_global_transform()
	var corners = [origin*Vector2(-96,-96),origin*Vector2(96,-96),origin*Vector2(-96,96),origin*Vector2(96,96)]
	var area = Rect2(corners[0],Vector2.ZERO)
	for corner in corners.slice(1): area = area.expand(corner)
	return Rect2i(area.position.floor(),area.size.ceil()+Vector2.ONE)

func paint_sprite(picture: Image, sprite: Node2D, lit: bool) -> void:
	if not sprite.visible: return
	var region = bounds(sprite).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
	var transform = sprite.get_global_transform()
	var inverse = transform.affine_inverse()
	var contour: PackedVector2Array = sprite.get("polygon") if sprite is Polygon2D else PackedVector2Array()
	var center: Vector2 = sprite.get("uv")[0]-contour[0] if sprite is Polygon2D else sprite.get("region_rect").get_center()
	var direction = Vector3(-0.52,-0.42,0.74).normalized()
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var local: Vector2 = inverse*Vector2(x+0.5,y+0.5)
			if absf(local.x)>=96.0 or absf(local.y)>=96.0: continue
			if not contour.is_empty() and not Geometry2D.is_point_in_polygon(local,contour): continue
			var point = Vector2i(center)+Vector2i(local.floor()).clamp(Vector2i(-96,-96),Vector2i(95,95))
			var paint = colors.get_pixel(int(point.x),int(point.y))
			if paint.a<0.02: continue
			if lit:
				var normal = normals.get_pixel(int(point.x),int(point.y))
				var heading = transform.basis_xform(Vector2(normal.r*2-1,1-normal.g*2))/transform.x.length()
				var surface = Vector3(heading.x,heading.y,normal.b*2-1).normalized()
				var amount = 0.88+0.25*maxf(0.0,direction.dot(surface))
				paint = Color(paint.r*amount,paint.g*amount,paint.b*amount,paint.a)
			picture.set_pixel(x,y,picture.get_pixel(x,y).blend(paint))

func old_sprite(picture: Image, unit: Dictionary) -> void:
	var character = {"liu":0,"fan":1,"xiao":2,"xiang":3,"captain":3,"fiction":3,"cao":3,"han":4,"archer":4}.get(unit.id,5)
	var heading: Vector2 = unit.face if unit.attack.is_empty() else unit.attack.dir
	var direction = posmod(roundi((heading.angle()-PI/2)/(PI/4)),8)
	var pose = 0 if unit.attack.is_empty() else 3+unit.attack.node.painted_pose
	var shift := Vector2.ZERO
	if not unit.attack.is_empty():
		var transfer: Vector2 = unit.attack.node.visual_transfer
		shift = heading*transfer.x+Vector2(0,transfer.y)
	var number: int = character*80+direction*10+pose
	var source = Rect2i(number%16*88,floori(number/16.0)*76,88,76)
	var tile = legacy.get_region(source)
	var scale_value: float = field.figures.scale.x
	tile.resize(roundi(88*scale_value),roundi(76*scale_value),Image.INTERPOLATE_NEAREST)
	var at = field.figures.to_global(unit.p+(shift.round())-Vector2(44,54))
	picture.blend_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(at))

func picture(name: String, old := false, lit := true) -> void:
	if out.is_empty() or compare and (name.contains("-before-") or name.contains("-after-")): return
	var canvas = Image.create_empty(roundi(field.size.x),roundi(field.size.y),false,Image.FORMAT_RGBA8)
	canvas.fill(Color("262019"))
	var frame = Rect2i(field.figures.position,Rules.WORLD*field.figures.scale.x)
	canvas.fill_rect(frame,PAPER)
	for line in range(frame.position.y+42,frame.end.y,31):
		canvas.fill_rect(Rect2i(frame.position.x+4,line,frame.size.x-8,1),Color("514b3c"))
	if old:
		for unit in game.alive(game.team+game.foes):
			old_sprite(canvas,unit)
	else:
		var sorted = field.actors.values()
		sorted.sort_custom(func(a,b): return a.rank<b.rank)
		for character in sorted:
			for sprite in character.pieces: paint_sprite(canvas,sprite,lit)
	for arrow in game.strikes:
		var point: Vector2 = arrow.p if old else field.visible_arrow(arrow)
		for step in range(18):
			var pixel = Vector2i(field.figures.to_global(point-arrow.dir*step*0.45))
			if Rect2i(Vector2i.ZERO,canvas.get_size()).has_point(pixel):
				canvas.fill_rect(Rect2i(pixel,Vector2i(2,2)),Color("dec18e"))
	canvas.save_png(out.path_join(name+".png"))

func weapon_proof(id: String) -> void:
	game.clear_battle()
	game.barrier.clear()
	var unit = game.make_actor(id,Vector2(290,193))
	unit.face = Vector2.RIGHT
	game.team.append(unit)
	var reach = 86 if id=="han" else (44 if id=="liu" else 38)
	var opponent = game.make_actor("guard",unit.p+Vector2.RIGHT*reach,true)
	opponent.face = Vector2.LEFT
	game.foes.append(opponent)
	field.sync_figures()
	picture(id+"-before-00",true)
	picture(id+"-after-00")
	game.attack(unit,unit.p+Vector2.RIGHT*100)
	# Existing combat rules own this exact attack lifetime and contact tick.
	var impact: int = unit.attack.impact
	var duration: int = unit.attack.duration
	var frame_count := 0
	for tick in duration:
		game.step_attack(unit)
		game.move_projectiles(Rules.STEP)
		opponent.hit = maxf(0,opponent.hit-Rules.STEP)
		field.sync_figures()
		if tick%2==0:
			picture("%s-before-%02d" % [id,frame_count+1],true)
			picture("%s-after-%02d" % [id,frame_count+1])
			frame_count += 1
		if tick+1 in [int(impact*0.45),impact,duration-3]:
			var phase = "wind" if tick+1<impact else ("contact" if tick+1==impact else "recover")
			picture(id+"-"+phase+"-before",true)
			picture(id+"-"+phase+"-after")
		if tick+1==impact:
			expect(unit.attack.contact and unit.attack.node.painted_pose==3,"Original contact tick unchanged")
			var character = rig(unit)
			var tool = character.tool
			var displayed_direction = (tool.to_global(Vector2.RIGHT)-tool.global_position).normalized()
			expect(absf(displayed_direction.angle_to(unit.attack.dir))<0.001,"Weapon follows the world-space attack direction at contact")
			expect(tool.global_position.distance_to(character.forearms[1].to_global(Vector2(0,Figure.WRIST)))<0.01,"Weapon is attached to the gripping wrist")
			if id=="han":
				expect(game.strikes.size()==1 and field.visible_arrow(game.strikes[0]).y<game.strikes[0].p.y-8,"Bolt origin follows the illustrated bow without changing rules coordinates")
	expect(opponent.hp<opponent.max_hp,"Target receives damage from existing rules")
	print(id," contact=",impact," recovery=",duration-impact," paired_samples=",frame_count+1," target_hp=",opponent.hp)

func bow_release_checks() -> void:
	var origin = Vector2(290,193)
	var release_offset = Vector2.ZERO
	var step_count = 8
	for scenario in ["contact","delayed","removed"]:
		game.clear_battle()
		game.barrier.clear()
		var shooter = game.make_actor("han",origin)
		var witness = game.make_actor("liu",Vector2(206,144))
		game.team = [shooter,witness]
		field.sync_figures()
		game.attack(shooter,origin + Vector2.RIGHT*100)
		for _tick in shooter.attack.impact:
			game.step_attack(shooter)
		var projectile: Dictionary = game.strikes[0]
		if scenario=="contact":
			field.sync_figures()
			var bow = rig(shooter).tool
			release_offset = field.figures.to_local(bow.to_global(Vector2(32,0)))-origin
			expect(field.visible_arrow(projectile).distance_to(origin+release_offset)<0.01,"Arrow starts at the contact bow tip")
			continue
		for _tick in step_count:
			game.step_attack(shooter)
			game.move_projectiles(Rules.STEP)
		shooter.p += Vector2(14,11)
		if scenario=="removed":
			shooter.hp = 0
			game.team.erase(shooter)
		field.sync_figures()
		var expected: Vector2 = projectile.p+release_offset.lerp(Vector2(0,-15),projectile.p.distance_to(origin)/90.0)
		expect(field.visible_arrow(projectile).distance_to(expected)<0.01,"Delayed render retains the release tip: "+scenario)
		expect(projectile.origin==origin and projectile.dir==Vector2.RIGHT and projectile.p.distance_to(origin+Vector2.RIGHT*330.0*Rules.STEP*step_count)<0.01,"Release visualization preserves the rules trajectory: "+scenario)

func verify() -> void:
	var headless = DisplayServer.get_name()=="headless"
	profile_render = not headless and OS.get_environment("HAN_MARCH_PROFILE_RENDER")=="1"
	if not headless and not profile_render:
		quit(2)
		return
	expect(headless or profile_render,"An explicit profile mode is required for a renderer")
	out = OS.get_environment("HAN_MARCH_RIG_DIAGNOSTICS")
	compare = profile_render or OS.get_environment("HAN_MARCH_DIRECTION_COMPARE")=="1"
	if profile_render:
		out = "" # Do not benchmark while encoding images.
		root.size = Vector2i(1280,800)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	colors = Figure.PIGMENTS.get_image()
	normals = Figure.NORMALS.get_image()
	legacy = OLD.get_image()
	expect(colors.get_size()==Vector2i(2304,1920) and colors.get_size()==normals.get_size(),"Aligned diffuse and normal atlas")
	game = Rules.new()
	game.mount(root)
	game.new_run(12345,"history")
	game.choose_route(0)
	game.enter_battle()
	field = View.new()
	field.size = Vector2(1280,800)
	field.game = game
	field.display = "battle"
	root.add_child(field)
	field.set_process(false)
	await process_frame
	var mesh := FileAccess.file_exists("res://assets/illustration/contours.json")
	expect(field.key_light.range_item_cull_mask==2 and field.warm_light.range_item_cull_mask==(4 if mesh else 2),"Expected figure masks")
	expect(field.material==field.overlay.material,"Floor and effects share the unlit material")
	expect(field.overlay.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"HUD and response layer are not lit")
	for id in ["liu","fan","han"]: weapon_proof(id)
	bow_release_checks()
	game.clear_battle()
	game.targets.clear()
	for id in Rules.HEROES:
		var index = game.team.size()+game.foes.size()
		var foe: bool = id in ["guard","pursuer","archer","captain","fiction"]
		var at = Vector2(132+(index%6)*75,132+floori(index/6.0)*94)
		var unit = game.make_actor(id,at,foe)
		(game.foes if foe else game.team).append(unit)
	field.sync_figures()
	expect(field.actor_count==Rules.HEROES.size(),"All playable and enemy designs are instantiated")
	for heading_index in 8:
		var heading = Vector2.from_angle(heading_index*TAU/8)
		for unit in game.team+game.foes:
			unit.face = heading
		field.sync_figures()
		for unit in game.team+game.foes:
			var character = rig(unit)
			expect(character.get_bone_count()==10 and character.pieces[0].texture is CanvasTexture,"Every heading uses the articulated illustration")
			expect(is_finite(character.tool.global_position.x) and is_finite(character.tool.global_position.y),"No invalid pose")
	for axis in 4:
		for unit in game.team+game.foes:
			unit.face = Vector2.DOWN.rotated(-TAU*axis/4)
		field.sync_figures()
		if mesh:
			for unit in game.team+game.foes:
				expect(rig(unit).stance==axis,"Four visual states")
				expect(is_equal_approx(rig(unit).position.y,unit.p.y),"Sorting uses the actor feet")
		picture("cardinal-%d"%axis)
	if mesh:
		check_contours()
		check_boundary()
	var initial = game.team[0]
	initial.move = true
	initial.step = 6.0
	field.sync_figures()
	var moving = rig(initial).thighs[0].rotation
	field.reduce_motion = true
	field.sync_figures()
	expect(not is_equal_approx(moving,rig(initial).thighs[0].rotation),"Reduced motion simplifies locomotion")
	field.size = Vector2(710,365)
	for index in 24: game.foes.append(game.make_actor("guard",Vector2(260+index%6*9,155+index/6*9),true))
	field.sync_figures()
	expect(field.actor_count==35 and field.overlay.z_index>rig(game.foes[-1]).tool.z_index,"Narrow crowd retains a foreground warning layer")
	picture("narrow-crowd")
	if compare:
		field.reduce_motion = false
		await compare_crowd(12,10,mesh)
		await compare_crowd(36,65,mesh)
	print("Illustration checks ",checks-failed,"/",checks)
	field.queue_free()
	game.clear_battle()
	game.host.queue_free()
	await process_frame
	await process_frame
	quit(failed)

func check_contours() -> void:
	var figure = field.actors.values()[0]
	var covers := 0
	var transparent := 0
	for i in figure.get("outlines").size():
		var contour: PackedVector2Array = figure.get("outlines")[i]
		var uv: PackedVector2Array = figure.get("texels")[i]
		var center = uv[0]-contour[0]
		expect(Geometry2D.triangulate_polygon(contour).size()==3*(contour.size()-2),"Convex external mesh triangulates")
		var missing := 0
		var fringe := 0
		for y in range(-96,96):
			for x in range(-96,96):
				var pixel = Vector2(x,y)
				var at = pixel+center
				var alpha = colors.get_pixel(int(at.x),int(at.y)).a
				if alpha<=0.0:
					transparent += 1
					continue
				covers += 1
				if not Geometry2D.is_point_in_polygon(pixel+Vector2(0.5,0.5),contour): missing += 1
				for corner in [Vector2(-0.49,-0.49),Vector2(1.49,-0.49),Vector2(1.49,1.49),Vector2(-0.49,1.49)]:
					if not Geometry2D.is_point_in_polygon(pixel+corner,contour): fringe += 1
		expect(missing==0 and fringe==0,"No cell alpha or bilinear fringe clipped, cell %d"%i)
	print("Atlas nonzero alpha texels=",covers," transparent texels=",transparent)

func check_boundary() -> void:
	var unit = game.team[1]
	var character = rig(unit)
	var previous := Vector2.ZERO
	var previous_angle := 0.0
	var largest_step := 0.0
	var largest_angle := 0.0
	var switches := 0
	var prior_stance: int = character.stance
	for sample in 361:
		unit.face = Vector2.RIGHT.rotated(deg_to_rad(sample))
		field.sync_figures()
		if sample>0:
			largest_step = maxf(largest_step,character.tool.global_position.distance_to(previous)/field.figures.scale.x)
			largest_angle = maxf(largest_angle,absf(wrapf(character.tool.global_rotation-previous_angle,-PI,PI)))
		if prior_stance!=character.stance: switches += 1
		prior_stance = character.stance
		previous = character.tool.global_position
		previous_angle = character.tool.global_rotation
		expect(character.tool.global_position.is_equal_approx(character.forearms[1].to_global(Vector2(0,8.1))),"Keyboard or mouse aim retains weapon hand")
		expect(character.get("guard").global_position.is_equal_approx(character.forearms[0].to_global(Vector2(0,8.1))),"Shield stays on the other hand")
	expect(largest_step<1 and largest_angle<0.08 and switches<=5,"Full turn without snapping the grip or angle")
	for angle in [0,45,44,46,44,46]:
		unit.face = Vector2.RIGHT.rotated(deg_to_rad(angle))
		field.sync_figures()
		expect(character.stance==1,"A diagonal threshold does not flicker")
	unit.face = Vector2.RIGHT
	field.sync_figures()
	var side_art: Polygon2D = character.get("torso_views")[1]
	var right: Transform2D = side_art.transform
	var uv = side_art.uv
	unit.face = Vector2.LEFT
	field.sync_figures()
	var left = side_art.transform
	expect(character.stance==3 and side_art.uv==uv,"Left reuses the right atlas coordinates")
	expect(is_equal_approx(right.x.x,-left.x.x) and is_equal_approx(right.y.y,left.y.y),"Diffuse position and normal basis reflect only X")
	expect(character.scale==Vector2.ONE and character.get("guard").get_parent()==character.forearms[0],"The actor frame, armor holder and HUD are outside the side mirror")
	var player_unit = game.team[0]
	var priority: Vector2 = unit.p
	unit.p = player_unit.p+Vector2(94,0)
	field.sync_figures()
	expect(character.get("has_fill") and not rig(game.foes[0]).get("has_fill"),"Nearby ally alone can receive fill among normal foes")
	unit.p.x += 14
	field.sync_figures()
	expect(character.get("has_fill"),"Exit threshold has hysteresis")
	unit.p.x += 14
	field.sync_figures()
	expect(not character.get("has_fill"),"Distant ally loses fill")
	var prior: Vector2 = player_unit.p
	player_unit.p.x = 12
	unit.p = Vector2(-32,player_unit.p.y)
	field.sync_figures()
	expect(not character.get("has_fill"),"Near but outside arena does not receive fill")
	player_unit.p = prior
	unit.p = priority
	print("One-degree sweep: largest wrist step=",largest_step," world px, largest angular change=",rad_to_deg(largest_angle)," degrees, switches=",switches)

func percentile(samples: Array[float], pos: float) -> float:
	samples.sort()
	return samples[ceili(pos*samples.size())-1]

func alpha_count(origin: Vector2i) -> int:
	if not alpha_counts.has(origin):
		var count := 0
		for y in range(origin.y,origin.y+192):
			for x in range(origin.x,origin.x+192):
				count += int(colors.get_pixel(x,y).a>0)
		alpha_counts[origin] = count
	return alpha_counts[origin]

func compare_crowd(enemies: int, shots: int, mesh: bool) -> void:
	game.clear_battle()
	field.size = Vector2(1280,800)
	var team = ["liu","fan","xiao","han","cao","xiang"]
	for i in team.size():
		game.team.append(game.make_actor(team[i],Vector2(306+i%3*25,156+i/3*29)))
	for i in enemies:
		var at = Vector2(315,173)+Vector2.from_angle(i*TAU/enemies)*(70+i%4*27)
		game.foes.append(game.make_actor(["guard","pursuer","archer"][i%3],at,true))
	for i in shots:
		var actor = game.foes[i%enemies]
		var bearing = Vector2.from_angle(i*1.618)
		game.strikes.append({"p":actor.p-bearing*11,"origin":actor.p,"dir":bearing,"left":150.0,"actor":actor,"power":1.0,"attack_id":-1-i})
	var samples: Array[float] = []
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var calls: Array[float] = []
	var last_frame := Time.get_ticks_usec()
	var viewport := root.get_viewport_rid()
	var left_area := 0.0
	var right_area := 0.0
	var left_triangles := 0
	var right_triangles := 0
	for frame in 260:
		for unit in game.team+game.foes:
			unit.face = Vector2.RIGHT if frame<130 else Vector2.LEFT
		var start = Time.get_ticks_usec()
		field.sync_figures()
		var counted := frame%130>=10
		if counted: samples.append((Time.get_ticks_usec()-start)/1000.0)
		if profile_render:
			field.queue_redraw()
			await RenderingServer.frame_post_draw
			var now = Time.get_ticks_usec()
			if counted:
				frames.append((now-last_frame)/1000.0)
				var gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
				if gpu_ms>0.0: gpu.append(gpu_ms)
				calls.append(float(RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)))
			last_frame = now
			await process_frame
		if frame not in [129,259]: continue
		var area := 0.0
		var pigment := 0.0
		var triangles := 0
		var lit := 0
		var fill := 0
		var objects := 0
		for character in field.actors.values():
			for item in character.pieces:
				if not item.visible: continue
				objects += 1
				lit += int(item.light_mask&field.key_light.range_item_cull_mask!=0)
				fill += int(item.light_mask&field.warm_light.range_item_cull_mask!=0)
				var points: PackedVector2Array = item.polygon if mesh else PackedVector2Array([Vector2(-96,-96),Vector2(96,-96),Vector2(96,96),Vector2(-96,96)])
				var doubled := 0.0
				for j in points.size():
					doubled += points[j].cross(points[(j+1)%points.size()])
				var projection = absf(item.global_transform.determinant())
				area += absf(doubled)*projection*0.5
				var origin: Vector2i = Vector2i(item.uv[0]-points[0]-Vector2(96,96)) if mesh else Vector2i(item.region_rect.position)
				pigment += alpha_count(origin)*projection
				triangles += points.size()-2
		if frame==129:
			right_area = area
			right_triangles = triangles
		else:
			left_area = area
			left_triangles = triangles
		print(JSON.stringify({"mesh":mesh,"enemies":enemies,"shots":game.strikes.size(),"allies":team.size(),"side":"right" if frame==129 else "left",
			"width":1280,"height":800,"projected_area_px2":roundi(area),"transparent_area_px2":roundi(area-pigment),"triangles":triangles,"visible_items":objects,
			"key_receivers":lit,"fill_receivers":fill}))
		picture("crowd-%d-%s"%[enemies,"right" if frame==129 else "left"])
	expect(is_equal_approx(left_area,right_area) and left_triangles==right_triangles,"L/R mesh complexity and area match")
	print(JSON.stringify({"mesh":mesh,"enemies":enemies,"samples":samples.size(),"cpu_sync_p50_ms":percentile(samples,0.5),"cpu_sync_p95_ms":percentile(samples,0.95),
		"display":DisplayServer.get_name(),"render_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),
		"draw_calls_p50":percentile(calls,0.5) if not calls.is_empty() else null,
		"draw_calls_p95":percentile(calls,0.95) if not calls.is_empty() else null,
		"gpu_frame_p50_ms":percentile(gpu,0.5) if gpu.size()==frames.size() and not gpu.is_empty() else null,
		"gpu_frame_p95_ms":percentile(gpu,0.95) if gpu.size()==frames.size() and not gpu.is_empty() else null,
		"rendered_frame_p50_ms":percentile(frames,0.5) if not frames.is_empty() else null,
		"rendered_frame_p95_ms":percentile(frames,0.95) if not frames.is_empty() else null}))
