extends Skeleton2D

const PIGMENTS = preload("res://assets/illustration/pigments.png")
const NORMALS = preload("res://assets/illustration/normals.png")
const TYPES = ["liu","fan","xiao","han","cao","xiang","guard","pursuer","archer","fiction"]
const GEAR = ["sword","axe","shield","bow","bow_drawn","spear","aid","quiver","arrow"]
const BONE_MASK = 2
const FILL_MASK = 4
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
const CONTOURS = "res://assets/illustration/contours.json"
const VIEW_MARGIN = 0.12
const VIEW_STEPS = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
const KEY_TIMES = [0.0,0.29,0.55,0.77,1.0]
static var fabric: CanvasTexture
static var poses: AnimationLibrary
static var outlines: Array[PackedVector2Array] = []
static var texels: Array[PackedVector2Array] = []

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
var pieces: Array[Polygon2D] = []
var torso_views: Array[Polygon2D] = []
var head_views: Array[Polygon2D] = []
var tool: Node2D
var blade: Polygon2D
var bent_bow: Polygon2D
var guard: Polygon2D
var arrow: Polygon2D
var gait := 0.0
var rank := -1
var stance := -1
var has_fill := false

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
	for part in 3: torso_views.append(paint(core,part,Vector2.ZERO))
	if weapon=="bow":
		paint(core,gear_cell("quiver"),Vector2(-5.4,4)).rotation = -0.38
	for part in 3: head_views.append(paint(crown,part+3,Vector2.ZERO))
	paint(arms[1],6,Vector2.ZERO)
	paint(forearms[1],7,Vector2.ZERO)
	tool = Node2D.new()
	forearms[1].add_child(tool)
	tool.position = Vector2(0,WRIST)
	tool.scale = Vector2.ONE*0.25
	blade = paint(tool,gear_cell(weapon),Vector2.ZERO)
	blade.scale = Vector2.ONE
	if weapon=="bow":
		bent_bow = paint(tool,gear_cell("bow_drawn"),Vector2.ZERO)
		bent_bow.scale = Vector2.ONE
		bent_bow.hide()
	if weapon=="axe": guard = paint(forearms[0],gear_cell("shield"),Vector2(0,WRIST))
	if weapon=="bow":
		arrow = paint(forearms[0],gear_cell("arrow"),Vector2(0,WRIST))
		arrow.hide()
	update_view(Vector2.DOWN)
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
	var cells: Array = JSON.parse_string(FileAccess.get_file_as_string(CONTOURS))
	for cell in cells.size():
		var outline := PackedVector2Array()
		var uv := PackedVector2Array()
		var origin := Vector2(cell%12,floori(cell/12.0))*CELL
		for i in range(0,cells[cell].size(),2):
			var point = Vector2(cells[cell][i],cells[cell][i+1])
			outline.append(point-Vector2.ONE*CELL*0.5)
			uv.append(origin+point)
		outlines.append(outline)
		texels.append(uv)
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

func paint(parent: Node2D, part: int, at: Vector2) -> Polygon2D:
	var mesh = Polygon2D.new()
	var cell = part+skin_index*BODY_PARTS if part<BODY_PARTS else part
	mesh.texture = fabric
	mesh.polygon = outlines[cell]
	mesh.uv = texels[cell]
	mesh.light_mask = BONE_MASK
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mesh.z_as_relative = false
	parent.add_child(mesh)
	mesh.position = at
	mesh.scale = Vector2.ONE*0.25
	pieces.append(mesh)
	return mesh

func update_view(direction: Vector2) -> void:
	var next := 1 if direction.x>=0.0 else 3
	if absf(direction.y)>absf(direction.x):
		next = 0 if direction.y>=0.0 else 2
	if next==stance or stance>=0 and direction.dot(VIEW_STEPS[next])-direction.dot(VIEW_STEPS[stance])<VIEW_MARGIN:
		return
	stance = next
	var original = 1 if stance==3 else stance
	var sign_x = -1.0 if stance==3 else 1.0
	for i in 3:
		torso_views[i].visible = i==original
		head_views[i].visible = i==original
	torso_views[1].scale.x = 0.25*sign_x
	head_views[1].scale.x = 0.25*sign_x
	blade.scale.y = sign_x
	if bent_bow!=null: bent_bow.scale.y = sign_x
	if guard!=null: guard.scale.x = 0.25*sign_x

func set_fill(value: bool) -> void:
	if value==has_fill: return
	has_fill = value
	var mask = BONE_MASK | FILL_MASK if value else BONE_MASK
	for piece in pieces: piece.light_mask = mask

func set_rank(index: int) -> void:
	if rank==index: return
	rank = index
	for i in pieces.size(): pieces[i].z_index = 16+rank*24+i

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
	var direction: Vector2 = facing.normalized()
	if direction.is_zero_approx(): direction = VIEW_STEPS[stance]
	update_view(direction)
	# Hand offsets use the live angle. Switching the artwork never rotates the grip.
	var side: float = smoothstep(-0.6,0.6,direction.x)*2.0-1.0
	var movement: bool = unit.move and not reduced
	if movement:
		gait = unit.step*0.48
	var cycle: float = sin(gait) if movement else 0.0
	var weight := cycle*0.9
	var reach := 8.5
	var angle := direction.angle()+0.43*side
	var lift := 0.0
	if not activity.is_empty():
		var age: float = activity.step
		var impact: float = activity.impact
		# The presentation track reaches its contact key on the existing simulation tick.
		var time = 0.55*age/impact if age<=impact else 0.55+0.45*(age-impact)/(activity.duration-impact)
		player.seek(time,true)
		angle = direction.angle()+phase_motion.x*side
		reach = phase_motion.y
		weight = phase_motion.z if not reduced else 0.0
		lift = 1.7 if weapon=="axe" and age<impact else 0.0
		if activity.special and not reduced: weight *= 1.18
	if evading and not reduced: weight = 3.7
	var recoil = Vector2.ZERO if reduced else Vector2(unit.recoil)*clampf(unit.hit/0.17,0,1)
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
	var hand = Vector2(2.9*side,5.0)+forward*reach+Vector2(0,-lift)
	var offhand = Vector2(-5.2*side,9.5)+Vector2(cycle*2,0)
	arms[1].position = Vector2(5.9*side,0)
	arms[0].position = Vector2(-5.9*side,-1.3*(1.0-absf(side)))
	aim_limb(arms[1],forearms[1],hand,ARM,WRIST,side)
	if weapon=="axe":
		offhand = Vector2(-4*side,6)+direction*(6.3 if not activity.is_empty() else 2.4)
	elif weapon=="bow":
		var drawn = not activity.is_empty() and activity.step<activity.impact
		if drawn!=bent_bow.visible:
			blade.visible = not drawn
			bent_bow.visible = drawn
		arrow.visible = drawn
		var grip = core.to_local(forearms[1].to_global(Vector2(0,WRIST)))
		offhand = grip-forward*(14.0 if drawn else 6.2)
	elif weapon=="spear":
		offhand = hand-forward*11
	aim_limb(arms[0],forearms[0],offhand,ARM,WRIST,-side)
	tool.rotation = angle-core.rotation-arms[1].rotation-forearms[1].rotation
	if guard!=null:
		guard.rotation = -arms[0].rotation-forearms[0].rotation+direction.x*0.2
	if arrow!=null:
		arrow.rotation = angle-core.rotation-arms[0].rotation-forearms[0].rotation
