extends SubViewportContainer

const BASE = Vector3(-0.22,-0.43,-0.06)
const GRAINS = 760
var seal := true
var reduced := false
var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D
var intact: MeshInstance3D
var dust: MultiMeshInstance3D
var home: Array[Vector3] = []
var grain_normals: Array[Vector3] = []
var grain_noise: Array[float] = []
var faces := PackedVector3Array()
var number_frames: Array[Basis] = []
var pointer := Vector2.ZERO
var hovering := false
var grain_center := Vector3.ZERO
var exposure := 0.0
var bronze_material: ShaderMaterial
var face_target := 0
var reveal_elapsed := 0.0
var shake_yaw := 0.0
var shown_pose: Quaternion

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	stretch = true
	stretch_shrink = 1
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var studio = Node3D.new()
	viewport.add_child(studio)
	pivot = Node3D.new()
	studio.add_child(pivot)
	pivot.rotation = BASE
	shown_pose = pivot.quaternion
	var ambient = WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = Color("b7b9a1")
	ambient.environment.ambient_light_energy = 0.60
	studio.add_child(ambient)
	for lighting in [[Vector3(-38,-22,0),Color("ffcd91"),1.9],[Vector3(-24,140,0),Color("8da4a0"),1.3]]:
		var lamp = DirectionalLight3D.new()
		lamp.rotation_degrees = lighting[0]
		lamp.light_color = lighting[1]
		lamp.light_energy = lighting[2]
		studio.add_child(lamp)
	camera = Camera3D.new()
	camera.position = Vector3(0,0.38,4.6)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.05 if seal else 2.62
	studio.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	if seal:
		build_seal()
	else:
		build_die()
	mouse_entered.connect(func(): hovering = true)
	mouse_exited.connect(func(): hovering = false)
	visibility_changed.connect(func():
		hovering = false
		if not is_visible_in_tree(): exposure = 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position

func seal_part(mesh: PrimitiveMesh, at: Vector3, angle := 0.0) -> void:
	var transform = Transform3D(Basis(Vector3.UP,angle),at)
	for vertex in mesh.get_faces():
		faces.append(transform*vertex)

func metal_plate(dims: Vector3, at: Vector3, angle := 0.0) -> void:
	var plate = BoxMesh.new()
	plate.size = dims
	seal_part(plate,at,angle)

func build_seal() -> void:
	metal_plate(Vector3(1.64,.30,1.50),Vector3(0,-.61,0))
	metal_plate(Vector3(1.52,.14,1.39),Vector3(0,-.39,0))
	metal_plate(Vector3(1.36,.10,1.22),Vector3(0,-.30,0))
	var knob = CylinderMesh.new()
	knob.top_radius = .29
	knob.bottom_radius = .44
	knob.height = .48
	knob.radial_segments = 10
	seal_part(knob,Vector3(0,-.02,0))
	var arch = TorusMesh.new()
	arch.inner_radius = .15
	arch.outer_radius = .38
	arch.rings = 20
	arch.ring_segments = 8
	for vertex in arch.get_faces():
		faces.append(Basis(Vector3.RIGHT,PI/2)*vertex+Vector3(0,.38,0))
	# The border and angular marks are original relief geometry.
	for y in [-.68,-.54]:
		metal_plate(Vector3(1.45,.022,.025),Vector3(0,y,.758))
	for x in [-.66,.66]:
		metal_plate(Vector3(.024,.15,.026),Vector3(x,-.61,.758))
	for x in [-.40,-.16,.16,.40]:
		metal_plate(Vector3(.031,.13,.032),Vector3(x,-.61,.77),.19)
		metal_plate(Vector3(.14,.025,.032),Vector3(x+.05,-.59,.77))
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces:
		mesh.add_vertex(point)
	mesh.generate_normals()
	intact = MeshInstance3D.new()
	intact.mesh = mesh.commit()
	pivot.add_child(intact)
	bronze_material = ShaderMaterial.new()
	bronze_material.shader = preload("res://assets/seal_bronze.gdshader")
	intact.material_override = bronze_material
	build_grains()

func build_grains() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 3128206
	var area = PackedFloat32Array()
	var total := 0.0
	for i in range(0,faces.size(),3):
		total += (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*0.5
		area.append(total)
	var storage = MultiMesh.new()
	storage.transform_format = MultiMesh.TRANSFORM_3D
	storage.use_colors = true
	var marker = BoxMesh.new()
	marker.size = Vector3.ONE*0.027
	var sand = StandardMaterial3D.new()
	sand.albedo_color = Color("fff0c9")
	sand.vertex_color_use_as_albedo = true
	sand.roughness = 0.88
	marker.material = sand
	storage.mesh = marker
	storage.instance_count = GRAINS
	storage.visible_instance_count = 0
	dust = MultiMeshInstance3D.new()
	dust.multimesh = storage
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(dust)
	for i in GRAINS:
		var j = mini(area.bsearch(rng.randf()*total),area.size()-1)*3
		var a = faces[j]
		var b = faces[j+1]
		var c = faces[j+2]
		var u = sqrt(rng.randf())
		var v = rng.randf()
		home.append(a*(1.0-u)+b*u*(1.0-v)+c*u*v)
		grain_normals.append((c-a).cross(b-a).normalized())
		grain_noise.append(rng.randf())

func build_die() -> void:
	var border = PackedVector3Array()
	var cap := 1.0
	var ridge = cap*(1-cos(PI/9))/(1+cos(PI/9))
	for i in 18:
		var angle = TAU*i/18.0
		border.append(Vector3(cos(angle)*.91,ridge*(-1 if i%2 else 1),sin(angle)*.91))
	var stone = StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 0.61
	stone.metallic = 0.58
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(stone)
	for i in 18:
		var cap_direction = 1.0 if i%2==0 else -1.0
		var a = Vector3.UP*cap*cap_direction
		var b = border[i]
		var c = border[(i+1)%18]
		var d = border[(i+2)%18]
		var center = (a+b+c+d)/4.0
		var normal = (b-a).cross(d-a).normalized()
		if normal.dot(center)<0: normal = -normal
		var label_basis = Basis.looking_at(normal,Vector3.UP,true)
		number_frames.append(label_basis)
		var color = Color("795536").lerp(Color("423125"),(i%3)*0.20)
		for vertex in [a,b,c,a,c,d]:
			surface.set_normal(normal)
			surface.set_color(color)
			surface.add_vertex(vertex)
		var label = Label3D.new()
		label.text = str(i+1)
		label.font = preload("res://assets/NotoSansKR.ttf")
		label.font_size = 44
		label.pixel_size = 0.005
		label.modulate = Color("ffdb9d")
		label.outline_size = 0
		label.shaded = false
		pivot.add_child(label)
		label.position = a.lerp(c,.74)+normal*.006
		label.basis = label_basis
	intact = MeshInstance3D.new()
	intact.mesh = surface.commit()
	pivot.add_child(intact)

func set_face(face: int, animate: bool) -> void:
	face_target = clampi(face,0,18)
	reveal_elapsed = .0 if animate else .74

func ray_hit(at: Vector2) -> Variant:
	var origin = pivot.to_local(camera.project_ray_origin(at))
	var direction = pivot.global_basis.inverse()*camera.project_ray_normal(at)
	var hit: Variant = null
	var distance := INF
	for i in range(0,faces.size(),3):
		var candidate = Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
		if candidate is Vector3 and origin.distance_squared_to(candidate)<distance:
			hit = candidate
			distance = origin.distance_squared_to(candidate)
	return hit

func render_grains() -> void:
	var storage = dust.multimesh
	if exposure<0.008:
		storage.visible_instance_count = 0
		return
	var count := 0
	for i in home.size():
		var point = home[i]
		var grain_seed: float = grain_noise[i]
		var edge = point.distance_to(grain_center)/0.52+sin(point.x*43.0+point.y*27.0+point.z*19.0)*0.09
		var local = smoothstep(-0.08,0.20,exposure-edge)
		if local<0.01: continue
		var wind = Vector3(sin(i*2.8),0.52,cos(i*3.1))
		var offset = (wind*.25+grain_normals[i]*.17)*local*grain_seed
		storage.set_instance_transform(count,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.6+grain_seed*0.75)*local),point+offset))
		storage.set_instance_color(count,Color("ae7336").lerp(Color("f0bc66"),grain_seed))
		count += 1
	storage.visible_instance_count = count

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	var base = Basis.from_euler(BASE).get_rotation_quaternion()
	var target = base
	var revealing := false
	if face_target>0 and not seal:
		var wanted = camera.global_basis*number_frames[face_target-1].inverse()
		target = wanted.get_rotation_quaternion()
		reveal_elapsed += dt
		var keep = 1.0-smoothstep(0.0,.72,reveal_elapsed)
		revealing = not reduced and keep>0.0001
		if revealing:
			target = Quaternion(Vector3.UP,keep*TAU*1.7)*target
	if hovering and not reduced and not revealing:
		shake_yaw += dt*.58
		var turn = clampf(pointer.x/maxf(1.0,size.x)*2.0-1.0,-1,1)*.70
		target = Quaternion(Vector3.UP,turn+.14*sin(shake_yaw))*target
	var immediate = reduced
	shown_pose = target if immediate else shown_pose.slerp(target,1.0-exp(-10.0*dt))
	pivot.quaternion = shown_pose
	if not seal: return
	var hit: Variant = ray_hit(pointer) if hovering and not reduced else null
	if hit is Vector3:
		grain_center = grain_center.lerp(hit,1.0-exp(-16.0*dt)) if exposure>0.04 else hit
	exposure = 0.0 if reduced else lerpf(exposure,1.0 if hit!=null else 0.0,1.0-exp(-(8.0 if hit!=null else 4.0)*dt))
	bronze_material.set_shader_parameter("rest_center",grain_center)
	bronze_material.set_shader_parameter("exposure",exposure)
	render_grains()
