extends Control

var face = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark = Label.new()
	mark.text = str(face) if face else "令"
	mark.add_theme_color_override("font_color",Color("321e12"))
	mark.add_theme_font_size_override("font_size",21)
	mark.position = Vector2(7,5)
	mark.size = Vector2(52,49)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)

func facet(vertices: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(vertices),Color(color))

func _draw() -> void:
	facet([Vector2(31,3),Vector2(49,8),Vector2(61,23),Vector2(62,40),Vector2(50,53),
		Vector2(29,61),Vector2(13,53),Vector2(5,37),Vector2(8,17)],"936433")
	facet([Vector2(31,3),Vector2(17,9),Vector2(8,17),Vector2(18,24),Vector2(33,17)],"c39549")
	facet([Vector2(33,17),Vector2(49,8),Vector2(61,23),Vector2(49,27)],"b5813a")
	facet([Vector2(18,24),Vector2(33,17),Vector2(49,27),Vector2(43,43),Vector2(26,47)],"d6a65c")
	facet([Vector2(5,37),Vector2(18,24),Vector2(26,47),Vector2(13,53)],"79522c")
	facet([Vector2(43,43),Vector2(62,40),Vector2(50,53),Vector2(29,61),Vector2(26,47)],"684426")
