extends SceneTree

func _initialize() -> void:
	var source = OS.get_environment("HAN_MARCH_ILLUSTRATION_SOURCE")
	var output = OS.get_environment("HAN_MARCH_ILLUSTRATION_OUTPUT")
	if source.is_empty() or output.is_empty():
		quit(2)
		return
	var diffuse = Image.new()
	var relief = Image.new()
	if diffuse.load_svg_from_string(FileAccess.get_file_as_string(source.path_join("pigments.svg")))!=OK or relief.load_svg_from_string(FileAccess.get_file_as_string(source.path_join("relief.svg")))!=OK:
		quit(3)
		return
	var width = diffuse.get_width()
	var height = diffuse.get_height()
	var normals = Image.create_empty(width,height,false,Image.FORMAT_RGB8)
	normals.fill(Color(0.5,0.5,1.0))
	for y in range(2,height-2):
		for x in range(2,width-2):
			if diffuse.get_pixel(x,y).a<0.10: continue
			var dx = height_at(relief,x+2,y)-height_at(relief,x-2,y)
			var dy = height_at(relief,x,y+2)-height_at(relief,x,y-2)
			var normal = Vector3(-dx*2.05,dy*2.05,1.0).normalized()
			normals.set_pixel(x,y,Color(normal.x*0.5+0.5,normal.y*0.5+0.5,normal.z*0.5+0.5))
	if diffuse.save_png(output.path_join("pigments.png"))!=OK or normals.save_png(output.path_join("normals.png"))!=OK:
		quit(4)
		return
	print("Diffuse and normal atlas ",diffuse.get_size())
	quit()

func height_at(plate: Image, x: int, y: int) -> float:
	var value = plate.get_pixel(x,y)
	return lerpf(0.46,value.r,value.a)
