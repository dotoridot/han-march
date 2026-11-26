extends SubViewportContainer

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
var chapter := -1
var point := Vector2(0,4.2)
var nearby := -1
var world: Node3D
var camera: Camera3D
var rider: Node3D
var legs: Array[Node3D] = []
var pins: Array[MeshInstance3D] = []
var nameplates: Array[Label3D] = []
var water: ShaderMaterial
var viewport: SubViewport
var walk_time := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	stretch = true
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	visibility_changed.connect(func():
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)

func setup(index: int, routes: Array, supply: int) -> void:
	if chapter!=index:
		chapter = index
		if is_instance_valid(world):
			viewport.remove_child(world)
			world.queue_free()
		world = Node3D.new()
		viewport.add_child(world)
		build_world()
	reset_position(point)
	for route in pins.size():
		var locked: bool = supply+routes[route][3]<0
		pins[route].material_override = paint("774638" if locked else "f2bc68")
		nameplates[route].text = "%s%s" % [routes[route][0]," (잠김)" if locked else ""]

func paint(tint: String) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(tint)
	material.roughness = 0.94
	return material

func shape(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, tint: String) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = paint(tint)
	parent.add_child(instance)
	instance.position = at
	return instance

func box(parent: Node3D, at: Vector3, dims: Vector3, tint: String) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = dims
	return shape(parent,mesh,at,tint)

func cone(parent: Node3D, at: Vector3, width: float, height: float, tint: String, top := 0.0, sides := 5) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = width
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 0
	return shape(parent,mesh,at,tint)

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

func position_at(at: Vector2, lift := 0.0) -> Vector3:
	return Vector3(at.x,elevation(at,path_distance(at))+lift,at.y)

func build_world() -> void:
	var field: Array = FIELDS[chapter]
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("252824")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a6ac95")
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = Color("697067")
	environment.fog_density = 0.036 if chapter==0 or chapter==3 else 0.022
	var ambient = WorldEnvironment.new()
	ambient.environment = environment
	world.add_child(ambient)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-49,-35,0)
	light.light_color = Color("ffcb93")
	light.light_energy = 1.05
	light.shadow_enabled = true
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.1
	camera.position = Vector3(0,12.5,10)
	world.add_child(camera)
	camera.look_at(Vector3(0,0,-0.65))
	camera.make_current()
	build_ground(field)
	build_water(field)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7813+chapter*193
	for _i in 180:
		var at = Vector2(rng.randf_range(-8,8),rng.randf_range(-6.3,5.4))
		if path_distance(at)<0.88 or elevation(at,path_distance(at))<WATER_Y+0.06:
			continue
		var size_factor = rng.randf_range(0.52,1.18)
		var base = position_at(at)
		if rng.randf()<0.77:
			cone(world,base+Vector3.UP*0.25*size_factor,0.075*size_factor,0.50*size_factor,"4b382b",0.045)
			cone(world,base+Vector3.UP*0.65*size_factor,0.30*size_factor,0.88*size_factor,"3b4c36" if _i%3 else "526040")
			cone(world,base+Vector3.UP*0.90*size_factor,0.23*size_factor,0.65*size_factor,"4d5b40")
		else:
			cone(world,base+Vector3.UP*0.13,0.20*size_factor,0.29*size_factor,"777361",0.13*size_factor)
	pins.clear()
	nameplates.clear()
	for route in TRAILS.size():
		var base = position_at(TRAILS[route][-1])
		for i in 4:
			var offset = Vector3((i%2)*0.50-0.25,0.0,(i/2)*0.53-0.8)
			if route==0: offset.x -= 0.60
			if route==1: offset.x += 0.60
			box(world,base+offset+Vector3.UP*0.22,Vector3(0.44,0.44,0.44),"a28760")
			var roof = cone(world,base+offset+Vector3.UP*0.52,0.36,0.25,"533226",0.06,4)
			roof.rotation.y = PI/4
		cone(world,base+Vector3.UP*0.45,0.04,0.9,"2b211b",0.04)
		pins.append(box(world,base+Vector3(0.15,0.77,0),Vector3(0.28,0.25,0.055),"f2bc68"))
		var plate = Label3D.new()
		plate.font = preload("res://assets/NotoSansKR.ttf")
		plate.font_size = 36
		plate.pixel_size = 0.006
		plate.modulate = Color("ffe2ad")
		plate.outline_modulate = Color("1d1712")
		plate.outline_size = 6
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(plate)
		plate.position = base+Vector3.UP*1.13
		nameplates.append(plate)
	build_rider()

func build_ground(field: Array) -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = paint("ffffff")
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)
	for row in range(59):
		for col in range(83):
			var at = Vector2(-9.6+col*.23,-7.6+row*.23)
			for shift in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
				var point_on_ground: Vector2 = at+shift*0.23
				var dist = path_distance(point_on_ground)
				var y = elevation(point_on_ground,dist)
				var tint: Color = field[0].lerp(field[1],clampf((y-.35)*.57,0,1))
				if dist<0.46: tint = Color("b59662").lerp(tint,smoothstep(.24,.49,dist))
				if y<WATER_Y: tint = Color("595742")
				var shade = 0.88+0.12*absf(sin(point_on_ground.x*17+point_on_ground.y*11))
				surface.set_color(tint*shade)
				surface.add_vertex(Vector3(point_on_ground.x,y,point_on_ground.y))
	surface.generate_normals()
	var ground = MeshInstance3D.new()
	ground.mesh = surface.commit()
	world.add_child(ground)

func build_water(field: Array) -> void:
	var face = PlaneMesh.new()
	face.size = Vector2(20,15)
	var water_model = MeshInstance3D.new()
	water_model.mesh = face
	world.add_child(water_model)
	water_model.position.y = WATER_Y
	water = ShaderMaterial.new()
	water.shader = preload("res://assets/march_water.gdshader")
	water.set_shader_parameter("deep_tint",field[2])
	water_model.material_override = water

func build_rider() -> void:
	rider = Node3D.new()
	world.add_child(rider)
	box(rider,Vector3(0,0.47,0),Vector3(.32,.35,.72),"563027")
	var neck = box(rider,Vector3(0,.60,-.35),Vector3(.22,.42,.21),"704233")
	neck.rotation.x = .25
	box(rider,Vector3(0,.79,-.48),Vector3(.21,.19,.33),"78483a")
	for x in [-.07,.07]:
		box(rider,Vector3(x,.91,-.48),Vector3(.06,.13,.08),"3c231d")
	var tail = box(rider,Vector3(0,.40,.43),Vector3(.11,.25,.20),"322421")
	tail.rotation.x = -.47
	box(rider,Vector3(0,.68,.05),Vector3(.35,.12,.35),"b1884e")
	box(rider,Vector3(0,.90,.03),Vector3(.28,.33,.23),"93452c")
	box(rider,Vector3(0,1.11,.02),Vector3(.18,.18,.19),"c59761")
	box(rider,Vector3(0,1.22,.03),Vector3(.20,.08,.19),"291f1c")
	var banner = box(rider,Vector3(.22,1.12,.16),Vector3(.025,.63,.025),"b18d50")
	banner.rotation.z = -.18
	box(rider,Vector3(.34,1.34,.19),Vector3(.23,.16,.02),"a64228")
	legs.clear()
	for z in [-.25,.24]:
		for x in [-.11,.11]:
			var joint = Node3D.new()
			rider.add_child(joint)
			joint.position = Vector3(x,.42,z)
			box(joint,Vector3(0,-.21,0),Vector3(.075,.42,.085),"3b2a25")
			legs.append(joint)

func reset_position(at: Vector2) -> void:
	point = at if on_road(at) else TRAILS[0][0]
	nearby = -1
	ride(Vector2.ZERO,0.0,true)

func on_road(at: Vector2) -> bool:
	var dist = path_distance(at)
	return dist<=0.53 and elevation(at,dist)>WATER_Y

func ride(direction: Vector2, dt: float, reduced: bool) -> int:
	if not is_instance_valid(rider):
		return -1
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
	nearby = -1
	for route in TRAILS.size():
		if point.distance_to(TRAILS[route][-1])<0.90:
			nearby = route
	return nearby

func place_rider(next: Vector2, dt: float, reduced: bool) -> void:
	if not is_instance_valid(rider): return
	var motion = next-point
	point = next
	rider.position = position_at(point)
	if motion.length_squared()>0.00001:
		var heading = atan2(-motion.x,-motion.y)
		rider.rotation.y = heading if reduced else lerp_angle(rider.rotation.y,heading,1.0-exp(-12.0*dt))
		walk_time += dt*14
	for i in legs.size():
		legs[i].rotation.x = sin(walk_time+PI*float(i==0 or i==3))*0.43 if not reduced and motion.length_squared()>0.00001 else 0.0
	water.set_shader_parameter("flow_phase",0.0 if reduced else float(Time.get_ticks_msec()%500000)*0.001)
	camera.position.x = clampf(point.x*0.19,-0.74,0.74) if not reduced else 0.0

func travel(branch: int, progress: float, dt: float, reduced: bool) -> void:
	var trail = TRAILS[branch]
	var part = clampf(progress,0,1)*float(trail.size()-1)
	var i = mini(int(part),trail.size()-2)
	place_rider(trail[i].lerp(trail[i+1],part-i),dt,reduced)
