extends Skeleton2D

const PIGMENTS = preload("res://assets/illustration/pigments.png")
const NORMALS = preload("res://assets/illustration/normals.png")
const TYPES = ["liu","fan","xiao","han","cao","xiang","guard","pursuer","archer","fiction"]
const GEAR = ["sword","axe","shield","bow","bow_drawn","spear","aid","quiver","arrow"]
const BONE_MASK = 2
const CELL = 192
const BODY_PARTS = 11
const ARM = 7.6
const WRIST = 8.1
const SHIN = 7.7
const THIGH = 7.0
const MOTION = {
	"sword":[Vector3(-1.35,4,-1),Vector3(-0.85,4,-1),Vector3(0.0,15,2.5),Vector3(0.87,11,2),Vector3(0.5,7,0)],
	"axe":[Vector3(-1.55,4,-2),Vector3(-1.15,5,-2),Vector3(0.0,13,2),Vector3(0.98,10,3),Vector3(0.62,7,0)],
	"bow":[Vector3(-0.12,11,-1),Vector3(0,14,-1),Vector3(0,15,0.7),Vector3(0.06,13,0),Vector3(0.12,8,0)],
	"spear":[Vector3(-0.2,2,-2),Vector3(-0.1,3,-2),Vector3(0,15,3),Vector3(0.08,11,1),Vector3(0.2,7,0)],
	"aid":[Vector3(-0.33,5,-1),Vector3(-0.4,7,-1),Vector3(0,12,1),Vector3(0.12,10,1),Vector3(0.26,6,0)],
}
const KEY_TIMES = [0.0,0.29,0.55,0.77,1.0]
static var fabric: CanvasTexture
static var poses: AnimationLibrary

var skin_index := 0
var weapon := "sword"
var player: AnimationPlayer
var phase_motion := Vector3(0.3,7,0)
var core: Bone2D
var crown: Bone2D
var arms: Array[Bone2D] = []
var forearms: Array[Bone2D] = []
var thighs: Array[Bone2D] = []
var boots: Array[Bone2D] = []
var pieces: Array[Sprite2D] = []
var chest: Sprite2D
var face: Sprite2D
var tool: Sprite2D
var guard: Sprite2D
var arrow: Sprite2D
var gait := 0.0
var rank := -1
var stance := 0

func setup(id: String, gear_name: String) -> void:
	skin_index = maxi(0,TYPES.find("xiang" if id=="captain" else id))
	weapon = gear_name
	init_resources()
	core = link(self,"Hips",Vector2(0,-30),17)
	crown = link(core,"Head",Vector2(0,-5),6)
	for i in 2:
		var side = -1.0 if i==0 else 1.0
		var hip = link(self,"Thigh"+str(i),Vector2(side*3.5,-13),THIGH)
		thighs.append(hip)
		boots.append(link(hip,"Shin"+str(i),Vector2(0,THIGH),SHIN))
		var arm = link(core,"Shoulder"+str(i),Vector2(side*5.9,0),ARM)
		arms.append(arm)
		forearms.append(link(arm,"Forearm"+str(i),Vector2(0,ARM),WRIST))
	for i in 2:
		paint(thighs[i],8,Vector2.ZERO)
		paint(boots[i],9,Vector2.ZERO)
	var drape = paint(core,10,Vector2(-2,3))
	drape.visible = id in ["liu","xiao","xiang","captain","fiction"]
	paint(arms[0],6,Vector2.ZERO)
	paint(forearms[0],7,Vector2.ZERO)
	chest = paint(core,0,Vector2.ZERO)
	if weapon=="bow":
		paint(core,gear_cell("quiver"),Vector2(-5.4,4)).rotation = -0.38
	face = paint(crown,3,Vector2.ZERO)
	paint(arms[1],6,Vector2.ZERO)
	paint(forearms[1],7,Vector2.ZERO)
	tool = paint(forearms[1],gear_cell(weapon),Vector2(0,WRIST))
	if weapon=="axe": guard = paint(forearms[0],gear_cell("shield"),Vector2(0,WRIST))
	if weapon=="bow": arrow = paint(forearms[0],gear_cell("arrow"),Vector2(0,WRIST))
	player = AnimationPlayer.new()
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("",poses)
	add_child(player)
	player.play(weapon)
	player.advance(0)

static func init_resources() -> void:
	if fabric!=null: return
	fabric = CanvasTexture.new()
	fabric.diffuse_texture = PIGMENTS
	fabric.normal_texture = NORMALS
	fabric.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	poses = AnimationLibrary.new()
	for kind in MOTION:
		var clip = Animation.new()
		clip.length = 1.0
		var track = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,NodePath(".:phase_motion"))
		clip.track_set_interpolation_type(track,Animation.INTERPOLATION_CUBIC)
		for i in KEY_TIMES.size():
			clip.track_insert_key(track,KEY_TIMES[i],MOTION[kind][i])
		poses.add_animation(kind,clip)

func link(parent: Node2D, title: String, at: Vector2, length_value: float) -> Bone2D:
	var next_bone = Bone2D.new()
	next_bone.name = title
	next_bone.set_autocalculate_length_and_angle(false)
	next_bone.length = length_value
	next_bone.bone_angle = PI*0.5
	parent.add_child(next_bone)
	next_bone.position = at
	next_bone.rest = next_bone.transform
	return next_bone

func gear_cell(id: String) -> int:
	return TYPES.size()*BODY_PARTS+GEAR.find(id)

func paint(parent: Bone2D, part: int, at: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = fabric
	sprite.region_enabled = true
	sprite.light_mask = BONE_MASK
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_as_relative = false
	parent.add_child(sprite)
	sprite.position = at
	sprite.scale = Vector2.ONE*0.25
	assign_cell(sprite,part)
	pieces.append(sprite)
	return sprite

func assign_cell(sprite: Sprite2D, part: int) -> void:
	var column = part+skin_index*BODY_PARTS if part<BODY_PARTS else part
	sprite.region_rect = Rect2(Vector2((column%12)*CELL,floori(column/12.0)*CELL),Vector2.ONE*CELL)

func set_rank(index: int) -> void:
	if rank==index: return
	rank = index
	for i in pieces.size(): pieces[i].z_index = 16+rank*16+i

func aim_limb(start: Bone2D, elbow: Bone2D, endpoint: Vector2, upper: float, lower: float, bend: float) -> void:
	var span = endpoint-start.position
	var distance = clampf(span.length(),2.1,upper+lower-0.15)
	var direction = span.angle()
	var inner = acos(clampf((upper*upper+distance*distance-lower*lower)/(2.0*upper*distance),-1,1))
	var shoulder = direction+bend*inner
	var fore = (Vector2.from_angle(direction)*distance-Vector2.from_angle(shoulder)*upper).angle()
	start.rotation = shoulder-PI*0.5
	elbow.rotation = fore-shoulder

func present(unit: Dictionary, reduced: bool, evading: bool) -> void:
	visible = unit.hp>0
	if not visible: return
	var activity: Dictionary = unit.attack
	var facing: Vector2 = unit.face if activity.is_empty() else activity.dir
	var mirror = -1.0 if facing.x< -0.18 else 1.0
	var direction = Vector2(facing.x*mirror,facing.y)
	var view := 2 if direction.y< -0.57 else (0 if direction.y>0.57 else 1)
	if view!=stance:
		stance = view
		assign_cell(chest,view)
		assign_cell(face,3+view)
	scale = Vector2(mirror,1.0)
	var movement: bool = unit.move and not reduced
	if movement:
		gait = unit.step*0.48
	var cycle: float = sin(gait) if movement else 0.0
	var weight := cycle*0.9
	var reach := 8.5
	var angle := direction.angle()+0.43
	var lift := 0.0
	if not activity.is_empty():
		var age: float = activity.step
		var impact: float = activity.impact
		# The presentation track reaches its contact key on the existing simulation tick.
		var time = 0.55*age/impact if age<=impact else 0.55+0.45*(age-impact)/(activity.duration-impact)
		player.seek(time,true)
		angle = direction.angle()+phase_motion.x
		reach = phase_motion.y
		weight = phase_motion.z if not reduced else 0.0
		lift = 1.7 if weapon=="axe" and age<impact else 0.0
		if activity.special and not reduced: weight *= 1.18
	if evading and not reduced: weight = 3.7
	var recoil = Vector2.ZERO if reduced else Vector2(unit.recoil.x*mirror,unit.recoil.y)*clampf(unit.hit/0.17,0,1)
	core.position = Vector2(0,-29)+direction*weight+recoil
	core.rotation = clampf(direction.x*weight*0.035,-0.16,0.16)
	crown.rotation = -core.rotation*0.7
	if evading and not reduced:
		core.position.y += 4.0
		crown.rotation -= 0.16
	for i in 2:
		var foot_sign = -1.0 if i==0 else 1.0
		var stride = cycle*foot_sign*4.3
		var planted = Vector2(foot_sign*4.7,-1.0)+direction*stride
		planted.y -= maxf(0.0,stride)*0.35
		if not activity.is_empty():
			planted += direction*(1.7 if i==0 else -1.2)
		aim_limb(thighs[i],boots[i],planted,THIGH,SHIN,-foot_sign)
	var forward = Vector2.from_angle(angle)
	var hand = Vector2(2.9,5.0)+forward*reach+Vector2(0,-lift)
	var offhand = Vector2(-5.2,9.5)+Vector2(cycle*2,0)
	aim_limb(arms[1],forearms[1],hand,ARM,WRIST,1.0)
	if weapon=="axe":
		offhand = Vector2(-4,6)+direction*(6.3 if not activity.is_empty() else 2.4)
	elif weapon=="bow":
		var drawn = not activity.is_empty() and activity.step<activity.impact
		assign_cell(tool,gear_cell("bow_drawn" if drawn else "bow"))
		arrow.visible = drawn
		var grip = core.to_local(forearms[1].to_global(Vector2(0,WRIST)))
		offhand = grip-forward*(14.0 if drawn else 6.2)
	elif weapon=="spear":
		offhand = hand-forward*11
	aim_limb(arms[0],forearms[0],offhand,ARM,WRIST,-1.0)
	tool.rotation = angle-arms[1].rotation-forearms[1].rotation
	if guard!=null:
		guard.rotation = -arms[0].rotation-forearms[0].rotation+direction.x*0.2
	if arrow!=null:
		arrow.rotation = angle-arms[0].rotation-forearms[0].rotation
