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

func _initialize() -> void:
	call_deferred("verify")

func expect(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failed += 1
		printerr(description)

func rig(unit: Dictionary) -> Figure:
	return field.actors[unit.uid]

func bounds(sprite: Sprite2D) -> Rect2i:
	var origin = sprite.get_global_transform()
	var corners = [origin*Vector2(-96,-96),origin*Vector2(96,-96),origin*Vector2(-96,96),origin*Vector2(96,96)]
	var area = Rect2(corners[0],Vector2.ZERO)
	for corner in corners.slice(1): area = area.expand(corner)
	return Rect2i(area.position.floor(),area.size.ceil()+Vector2.ONE)

func paint_sprite(picture: Image, sprite: Sprite2D, lit: bool) -> void:
	if not sprite.visible: return
	var region = bounds(sprite).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
	var transform = sprite.get_global_transform()
	var inverse = transform.affine_inverse()
	var atlas = sprite.region_rect
	var direction = Vector3(-0.52,-0.42,0.74).normalized()
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var point: Vector2 = inverse*Vector2(x+0.5,y+0.5)+atlas.get_center()
			if not atlas.has_point(point): continue
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
	if out.is_empty(): return
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
			expect(absf(wrapf(tool.global_rotation,-PI,PI))<0.17,"Weapon agrees with horizontal attack direction")
			expect(tool.global_position.distance_to(character.forearms[1].to_global(Vector2(0,Figure.WRIST)))<0.01,"Weapon is attached to the gripping wrist")
			if id=="han":
				expect(game.strikes.size()==1 and field.visible_arrow(game.strikes[0]).y<game.strikes[0].p.y-8,"Bolt origin follows the illustrated bow without changing rules coordinates")
	expect(opponent.hp<opponent.max_hp,"Target receives damage from existing rules")
	print(id," contact=",impact," recovery=",duration-impact," paired_samples=",frame_count+1," target_hp=",opponent.hp)

func verify() -> void:
	expect(DisplayServer.get_name()=="headless","No desktop display backend")
	out = OS.get_environment("HAN_MARCH_RIG_DIAGNOSTICS")
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
	expect(field.key_light.range_item_cull_mask==Figure.BONE_MASK and field.warm_light.range_item_cull_mask==Figure.BONE_MASK,"Lights affect the figure mask")
	expect(field.overlay.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"HUD and response layer are not lit")
	for id in ["liu","fan","han"]: weapon_proof(id)
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
			expect(character.get_bone_count()==10 and character.tool.texture is CanvasTexture,"Every heading uses the articulated illustration")
			expect(is_finite(character.tool.global_position.x) and is_finite(character.tool.global_position.y),"No invalid pose")
	picture("company-diffuse",false,false)
	picture("company-normal")
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
	print("Illustration checks ",checks-failed,"/",checks)
	field.queue_free()
	game.clear_battle()
	game.host.queue_free()
	await process_frame
	await process_frame
	quit(failed)
