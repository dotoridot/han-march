extends Control

const Run = preload("res://run.gd")
const Field = preload("res://field.gd")
const UI_FONT = preload("res://assets/NotoSansKR.ttf")
const PAPER = Color("f1e6d8")
const MUTED = Color("cdbba4")
const GOLD = Color("dfaa61")
const PANEL = Color("251b15")
const INK = Color("18120e")
var run = Run.new()
var rng = RandomNumberGenerator.new()
var field
var picture: TextureRect
var labels: Control
var name_plate: Label
var chapter: Label
var objective: Label
var details: Label
var danger: Label
var journal_button: Button
var pause_button: Button
var unit_rows: VBoxContainer
var dispatch_log: Label
var modal: ColorRect
var sheet: PanelContainer
var modal_body: VBoxContainer
var transition: ColorRect
var text_scale = 1.0
var motion_reduced = false
var sound_on = true
var pause = false
var view = ""
var heading = ""
var return_focus: Control
var last_view_phase = ""
var last_queue = 0
var last_journal = 0
var refresh_left = 0.0
var clock = 0.0
var rows: Dictionary = {}
var markers: Dictionary = {}
var reward = "guard"
var struck = 0
var hit_animation = 0.0
var store_path = "user://journal.cfg"
var audio: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
var channel = 0
var scene_theme: Theme
var large_font: FontVariation
var interactive_input = false
var click_attack = false
var mouse_here = Vector2(-1,-1)

func _ready() -> void:
	rng.randomize()
	Engine.max_fps = 60
	get_window().title = "초한: 패현의 깃발"
	get_window().min_size = Vector2i(860,590)
	if OS.has_environment("PEI_LOCAL_DATA"):
		store_path = OS.get_environment("PEI_LOCAL_DATA").path_join("journal.cfg")
	var prefs = ConfigFile.new()
	prefs.load(store_path)
	var discovered: Array = prefs.get_value("archive","records",[])
	motion_reduced = prefs.get_value("display","reduced_motion",false)
	sound_on = prefs.get_value("display","sound",true)
	run.setup(discovered.filter(func(entry): return Run.STORY.has(entry)))
	build_theme()
	build_view()
	build_audio()
	rebuild_overlay("intro")
	refresh_hud()
	last_journal = run.journal.size()

func style(color: Color, padding: int = 0, radius: int = 0) -> StyleBoxFlat:
	var skin = StyleBoxFlat.new()
	skin.bg_color = color
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_content_margin(side,padding)
	skin.set_corner_radius_all(radius)
	return skin

func build_theme() -> void:
	scene_theme = Theme.new()
	var weight_tag = TextServerManager.get_primary_interface().name_to_tag("wght")
	var reading_font = FontVariation.new()
	reading_font.base_font = UI_FONT
	reading_font.variation_opentype = {weight_tag:465}
	large_font = FontVariation.new()
	large_font.base_font = UI_FONT
	large_font.variation_opentype = {weight_tag:610}
	scene_theme.default_font = reading_font
	scene_theme.default_font_size = roundi(16*text_scale)
	scene_theme.set_color("font_color","Label",PAPER)
	scene_theme.set_color("font_color","Button",Color("fff6eb"))
	scene_theme.set_color("font_hover_color","Button",Color("fff6eb"))
	scene_theme.set_color("font_pressed_color","Button",Color("fff6eb"))
	scene_theme.set_color("font_focus_color","Button",Color("fff6eb"))
	scene_theme.set_color("font_disabled_color","Button",MUTED)
	scene_theme.set_stylebox("normal","Button",style(Color("896335"),11,3))
	scene_theme.set_stylebox("hover","Button",style(Color("98642d"),11,3))
	scene_theme.set_stylebox("pressed","Button",style(Color("a94f25"),11,3))
	scene_theme.set_stylebox("disabled","Button",style(Color("392b20"),11,3))
	scene_theme.set_stylebox("focus","Button",StyleBoxEmpty.new())
	theme = scene_theme

func label(parent: Node, title: String, font_size: int = 16, color: Color = PAPER) -> Label:
	var element = Label.new()
	element.text = title
	element.add_theme_font_size_override("font_size",roundi(font_size*text_scale))
	element.set_meta("base_size",font_size)
	element.add_theme_color_override("font_color",color)
	if font_size >= 18:
		element.add_theme_font_override("font",large_font)
	parent.add_child(element)
	return element

func paragraph(parent: Node, content: String, font_size: int = 16, color: Color = PAPER) -> Label:
	var el = label(parent, content, font_size, color)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return el

func line(parent: Node, gap: int = 10) -> BoxContainer:
	var b = HBoxContainer.new()
	b.add_theme_constant_override("separation",gap)
	parent.add_child(b)
	return b

func vertical(parent: Node, gap: int = 8) -> VBoxContainer:
	var b = VBoxContainer.new()
	b.add_theme_constant_override("separation",gap)
	parent.add_child(b)
	return b

func button(parent: Node, title: String, action: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = title
	b.accessibility_name = title
	b.custom_minimum_size.y = 39
	b.pressed.connect(action)
	if primary:
		b.add_theme_stylebox_override("normal",style(Color("ad522b"),11,3))
		b.add_theme_stylebox_override("hover",style(Color("af552c"),11,3))
		b.add_theme_stylebox_override("pressed",style(Color("a94f25"),11,3))
	var under = ColorRect.new()
	under.color = Color("fff6eb")
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(under)
	under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	under.offset_left = 9
	under.offset_right = -9
	under.offset_top = -6
	under.offset_bottom = -3
	under.hide()
	b.focus_entered.connect(func():
		if not interactive_input:
			under.show()
	)
	b.focus_exited.connect(func(): under.hide())
	b.set_meta("focus_line",under)
	parent.add_child(b)
	return b

func build_view() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = INK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(key,19)
	var shell = vertical(margin,11)
	var top = line(shell,13)
	var seal = PanelContainer.new()
	seal.add_theme_stylebox_override("panel",style(Color("8e3620"),7,3))
	top.add_child(seal)
	label(seal,"沛",23)
	label(top,"초한  패현의 깃발",24)
	top.add_spacer(false)
	journal_button = button(top,"행군 기록",func(): rebuild_overlay("journal"))
	pause_button = button(top,"일시정지",toggle_pause)
	var area = line(shell,13)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var board = PanelContainer.new()
	board.add_theme_stylebox_override("panel",style(Color("231b15"),11,3))
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(board)
	var column = vertical(board,9)
	var info = line(column,12)
	name_plate = label(info,"패현 북문",18)
	chapter = label(info,"기원전 209년",14,MUTED)
	var field_stack = Control.new()
	field_stack.custom_minimum_size = Vector2(535,340)
	field_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(field_stack)
	var map_view = SubViewport.new()
	map_view.size = Vector2i(Run.SIZE)
	map_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_view.physics_object_picking = false
	field_stack.add_child(map_view)
	field = Field.new()
	field.model = run
	map_view.add_child(field)
	picture = TextureRect.new()
	picture.texture = map_view.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_stack.add_child(picture)
	labels = Control.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_stack.add_child(labels)
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field_stack.resized.connect(func():
		var ratio = minf(field_stack.size.x / Run.SIZE.x, field_stack.size.y / Run.SIZE.y)
		picture.size = Run.SIZE * ratio
		picture.position = (field_stack.size-picture.size)*0.5
	)
	paragraph(column,"WASD 이동   마우스 조준·공격   E 길게   Q 집결   Esc 일시정지",14,MUTED)
	var hud_scroll = ScrollContainer.new()
	hud_scroll.custom_minimum_size.x = 290
	hud_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(hud_scroll)
	var hud_panel = PanelContainer.new()
	hud_panel.custom_minimum_size.x = 290
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_stylebox_override("panel",style(PANEL,12,3))
	hud_scroll.add_child(hud_panel)
	var hud = vertical(hud_panel,8)
	label(hud,"현재 목표",15,GOLD)
	objective = paragraph(hud,"패현군을 모으기",19)
	danger = paragraph(hud,"",17,Color("ef9661"))
	details = paragraph(hud,"",14,MUTED)
	hud.add_child(HSeparator.new())
	label(hud,"패현군",15,GOLD)
	unit_rows = vertical(hud,5)
	hud.add_child(HSeparator.new())
	label(hud,"전황",15,GOLD)
	dispatch_log = paragraph(hud,"",13,MUTED)

	modal = ColorRect.new()
	modal.color = Color("110b08cd")
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel",style(PANEL,20,4))
	center.add_child(sheet)
	modal.resized.connect(func(): fit_overlay())
	transition = ColorRect.new()
	transition.color = Color("17110c")
	transition.modulate.a = 0
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(transition)
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fit_overlay() -> void:
	if modal_body != null and modal_body.get_parent() is ScrollContainer:
		var box = modal_body.get_parent()
		box.custom_minimum_size = Vector2(minf(660,modal.size.x-70),minf(box.get_meta("height"),modal.size.y-73))

func rebuild_overlay(kind: String) -> void:
	var opening = view.is_empty()
	view = kind
	if opening:
		return_focus = get_viewport().gui_get_focus_owner()
	for child in sheet.get_children():
		sheet.remove_child(child)
		child.queue_free()
	var box = ScrollContainer.new()
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.set_meta("height",560 if kind == "camp" else (260 if kind in ["intro","won","lost"] else 355))
	sheet.add_child(box)
	modal_body = vertical(box,9)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.show()
	fit_overlay()
	match kind:
		"intro":
			label(modal_body,"기원전 209년  /  패현",15,GOLD)
			label(modal_body,"초한: 패현의 깃발",36)
			paragraph(modal_body,Run.STORY.intro if run.intro_card == 0 else "유방은 북문을 지키고 부상자를 데려오라는 명을 내린다. 마을 성벽의 궁수에게 엄호를 청할 수 있다.",18,MUTED)
			var bar = line(modal_body)
			if run.intro_card == 0:
				button(bar,"다음 이야기",func():
					run.intro_card += 1
					rebuild_overlay("intro")
				)
			button(bar,"패현 방어 시작",begin,true)
			paragraph(modal_body,"Enter 또는 Esc로 도입을 건너뜁니다.",14,MUTED)
		"camp":
			camp_view()
		"level":
			var u = run.level_queue[0]
			label(modal_body,"%s 강화 선택" % Run.ROSTER[u.id][0],29)
			paragraph(modal_body,"전투 XP로 레벨 %d에 도달했습니다. 이 장수에게 적용할 강화 하나를 고르세요." % u.level,16,MUTED)
			for id in Run.PERKS:
				button(modal_body,Run.PERKS[id][0] + "  /  " + Run.PERKS[id][1],func():
					run.pick_level(id)
					if run.level_queue.is_empty():
						close_overlay()
					else:
						rebuild_overlay("level")
				)
		"journal":
			label(modal_body,"행군 기록",29)
			for id in run.journal:
				paragraph(modal_body,Run.STORY[id],16,MUTED)
			button(modal_body,"닫기",back_from_overlay)
		"pause":
			label(modal_body,"일시정지",28)
			paragraph(modal_body,"전투 시간이 멈췄습니다.",16,MUTED)
			button(modal_body,"전투 계속",close_overlay,true)
			button(modal_body,"움직임 줄이기 " + ("켜짐" if motion_reduced else "꺼짐"),func():
				motion_reduced = not motion_reduced
				save()
				rebuild_overlay("pause")
			)
			button(modal_body,"효과음 " + ("켜짐" if sound_on else "꺼짐"),func():
				sound_on = not sound_on
				save()
				rebuild_overlay("pause")
			)
			button(modal_body,"글자 크기 %d%%" % int(text_scale*100),scale_text)
		"won", "lost":
			label(modal_body,"군량고의 새벽" if kind == "won" else "접힌 깃발",33)
			paragraph(modal_body,run.outcome,18)
			paragraph(modal_body,"전투 %s  /  행군 기록 %d건" % [format_time(run.elapsed),run.journal.size()],15,MUTED)
			paragraph(modal_body,"새 판에는 장수와 특기를 다시 모읍니다. 행군 기록은 이어집니다.",15,MUTED)
			var bar = line(modal_body)
			button(bar,"새 판 시작",reset_run,true)
			button(bar,"행군 기록",func(): rebuild_overlay("journal"))
	focus_first.call_deferred(modal_body)

func focus_first(container: Control) -> void:
	if not is_instance_valid(container) or modal_body != container or not container.is_visible_in_tree():
		return
	for child in container.find_children("*","Button",true,false):
		if not child.disabled:
			child.grab_focus()
			break

func begin() -> void:
	run.begin()
	close_overlay()
	cut()

func close_overlay() -> void:
	modal.hide()
	view = ""
	pause = false
	var focus = return_focus
	return_focus = null
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus()
	else:
		get_viewport().gui_release_focus()

func back_from_overlay() -> void:
	if run.phase in ["intro","camp","won","lost","level"]:
		rebuild_overlay(run.phase)
	else:
		close_overlay()

func reset_run() -> void:
	var history = run.journal.duplicate()
	run = Run.new()
	run.setup(history)
	field.model = run
	rows.clear()
	for child in unit_rows.get_children():
		unit_rows.remove_child(child)
		child.queue_free()
	reward = "guard"
	begin()

func toggle_pause() -> void:
	if not view.is_empty():
		if view == "pause":
			close_overlay()
		return
	pause = true
	rebuild_overlay("pause")

func cut() -> void:
	if motion_reduced:
		transition.modulate.a = 0
		return
	transition.modulate.a = 0.85
	create_tween().tween_property(transition,"modulate:a",0.0,0.35)

func scale_text() -> void:
	text_scale = 1.18 if text_scale == 1.0 else 1.0
	build_theme()
	for n in find_children("*","Label",true,false):
		if n.has_meta("base_size"):
			n.add_theme_font_size_override("font_size",roundi(n.get_meta("base_size")*text_scale))
	if not view.is_empty():
		rebuild_overlay(view)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse_here = event.position
	if event is InputEventMouseButton and event.pressed:
		interactive_input = true
		var active_focus = get_viewport().gui_get_focus_owner()
		if active_focus is Button and active_focus.has_meta("focus_line"):
			active_focus.get_meta("focus_line").hide()
		click_attack = event.button_index == MOUSE_BUTTON_LEFT and view.is_empty() and picture.get_global_rect().has_point(mouse_here)
	elif event is InputEventKey and event.pressed:
		interactive_input = false
		var active_focus = get_viewport().gui_get_focus_owner()
		if active_focus is Button and active_focus.has_meta("focus_line"):
			active_focus.get_meta("focus_line").show()
		if event.echo:
			return
		if event.physical_keycode == KEY_Q:
			run.last_input = "rally"
		if event.physical_keycode == KEY_F6:
			scale_text()
		if event.physical_keycode == KEY_F4:
			motion_reduced = not motion_reduced
			save()
		if event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if view == "intro":
				begin()
			elif view in ["pause","journal"]:
				back_from_overlay()
			elif view.is_empty():
				toggle_pause()
		elif view == "intro" and event.physical_keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			begin()

func update_phase() -> void:
	if last_view_phase == run.phase and last_queue == run.level_queue.size():
		return
	var changed = last_view_phase != run.phase
	last_view_phase = run.phase
	last_queue = run.level_queue.size()
	if changed and run.phase in ["camp","won","lost"]:
		rebuild_overlay(run.phase)
		cut()
	elif last_queue > 0 and view.is_empty():
		rebuild_overlay("level")

func _process(dt: float) -> void:
	if field == null:
		return
	clock += dt
	if run.phase in ["defense","assault"] and view.is_empty() and not pause and get_window().has_focus():
		advance_field(dt)
	elif not view.is_empty():
		field.pointer = Vector2(-1,-1)
	run.last_input = ""
	click_attack = false
	update_phase()
	if last_journal != run.journal.size():
		last_journal = run.journal.size()
		save()
	consume_sound()
	field.motion = motion_reduced
	if view.is_empty():
		field.stage_time = clock
	if run.strike_id != struck:
		struck = run.strike_id
		hit_animation = 0.12
	hit_animation = maxf(0,hit_animation-dt)
	var bump = Vector2(1,0)*roundf(sin(hit_animation*135)*2) if hit_animation > 0 and not motion_reduced else Vector2.ZERO
	var centered = (picture.get_parent().size-picture.size)*0.5
	picture.position = centered + bump
	field.queue_redraw()
	draw_overlay_markers()
	refresh_left -= dt
	if refresh_left <= 0:
		refresh_hud()
		refresh_left = 0.1

func advance_field(dt: float) -> void:
	var player = run.team[0]
	var direction = Vector2(
		float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var surface = picture.get_global_rect()
	var inside = surface.has_point(mouse_here)
	var aim = (mouse_here - surface.position)*Run.SIZE/surface.size if inside else player.p + player.face*42
	field.pointer = aim if inside else Vector2(-1,-1)
	var attack = click_attack or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and inside)
	if Input.is_physical_key_pressed(KEY_SPACE):
		var closest = run.nearest(player.p,run.foes,run.reach(player)+25)
		if not closest.is_empty():
			aim = closest.p
		attack = true
	run.tick(dt,direction,aim,attack,Input.is_physical_key_pressed(KEY_E),run.last_input == "rally")

func save() -> void:
	var f = ConfigFile.new()
	f.set_value("archive","records",run.journal)
	f.set_value("display","reduced_motion",motion_reduced)
	f.set_value("display","sound",sound_on)
	f.save(store_path)

func format_time(value: float) -> String:
	var seconds = maxi(0,ceili(value-0.001))
	return "%d:%02d" % [int(seconds/60.0),seconds%60]


func camp_view() -> void:
	label(modal_body,"야영지 회의",28,GOLD)
	var hurt = []
	for u in run.team:
		if u.hp < u.max_hp / 2:
			hurt.append(Run.ROSTER[u.id][0])
	var injured = " 부상: " + ", ".join(hurt) + "." if not hurt.is_empty() else ""
	paragraph(modal_body,"소하 “들것 %d개가 돌아왔소. 구조하지 못한 사람은 %d명이오.”%s" % [run.saved_wounds(),3-run.saved_wounds(),injured],16)
	var columns = line(modal_body,12)
	var left = vertical(columns,5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right = vertical(columns,5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(left,"무료 등용 1회",18,GOLD)
	var mode_names = {"steady":"균형", "breach":"돌파", "cover":"엄호"}
	if run.rolled.is_empty():
		var picks = line(left,5)
		for id in ["steady","breach","cover"]:
			button(picks,mode_names[id] + (" 선택" if run.draft_plan == id else ""),func():
				run.draft_plan = id
				rebuild_overlay("camp")
			)
	else:
		var r = run.rolled
		paragraph(left,"%d면: %s %s" % [r.face,Run.ROSTER[r.id][0],"중복" if r.duplicate else "합류"],17,GOLD)
		if r.id == "xiang":
			paragraph(left,Run.STORY.xiang,14,MUTED)
	var pitch = {"steady":"번쾌·소하 면을 유지합니다.",
		"breach":"항우 면 +3. 그만큼 번쾌·소하 면이 줄어듭니다.",
		"cover":"조참 면 +4. 항우는 나오지 않고 번쾌·소하 면도 줄어듭니다."}
	paragraph(left,pitch[run.draft_plan],14,MUTED)
	var weights = run.draft_weights()
	var total = 0
	for i in range(weights.size()):
		total += weights[i]
		label(left,"%s  %2d/18   %5.2f%%" % [Run.ROSTER[Run.DRAFT[i]][0],weights[i],100.0*weights[i]/18.0],14)
	label(left,"합계 %d/18   %.0f%%" % [total,100.0*total/18.0],14,GOLD)
	var dice_row = line(left,8)
	var Die = load("res://die.gd")
	var die = Die.new()
	die.custom_minimum_size = Vector2(68,64)
	die.face = run.rolled.get("face", 0)
	dice_row.add_child(die)
	if run.rolled.is_empty():
		button(dice_row,"18면 주사위 굴리기",func():
			run.recruit(rng)
			play_sound("bow")
			rebuild_overlay("camp")
		,true)
	else:
		label(dice_row,"등용 기회 사용",14,MUTED)
	label(right,"한 명 회복",18,GOLD)
	if run.healed.is_empty():
		var healing = GridContainer.new()
		healing.columns = 2
		healing.add_theme_constant_override("h_separation",5)
		healing.add_theme_constant_override("v_separation",4)
		right.add_child(healing)
		for u in run.team:
			button(healing,"%s  %d/%d" % [Run.ROSTER[u.id][0],u.hp,u.max_hp],func():
				run.heal(u.id)
				rebuild_overlay("camp")
			)
	else:
		label(right,Run.ROSTER[run.healed][0] + " 회복 완료",14,MUTED)
	label(right,"전투 보상 특기",18,GOLD)
	if run.bonus.is_empty():
		var powers = line(right,5)
		for id in ["guard","power",run.pending_bonus]:
			if Run.PERKS.has(id):
				button(powers,Run.PERKS[id][0] + (" 선택" if id == reward else ""),func():
					reward = id
					rebuild_overlay("camp")
				)
		paragraph(right,Run.PERKS[reward][1],14,MUTED)
		var recipients = GridContainer.new()
		recipients.columns = 2
		recipients.add_theme_constant_override("h_separation",5)
		recipients.add_theme_constant_override("v_separation",4)
		right.add_child(recipients)
		for u in run.team:
			button(recipients,Run.ROSTER[u.id][0],func():
				run.give_bonus(u.id,reward)
				rebuild_overlay("camp")
			)
	else:
		label(right,Run.ROSTER[run.bonus][0] + " 특기 적용",14,MUTED)
	var advance = button(modal_body,"진군 보급 거점으로 출정",func():
		if run.depart():
			close_overlay()
			cut()
	,true)
	advance.disabled = run.bonus.is_empty()
	if advance.disabled:
		paragraph(modal_body,"전투 특기를 한 명에게 부여하면 출정할 수 있습니다.",14,MUTED)

func refresh_hud() -> void:
	var place = {
		"intro":"패현 북문", "defense":"패현 북문", "camp":"패현군 야영지",
		"assault":"진군 보급 거점", "won":"진군 보급 거점", "lost":"패현군 철수",
	}
	name_plate.text = place[run.phase]
	chapter.text = "기원전 209년  /  " + ("첫째 전투" if run.phase in ["intro","defense"] else ("둘째 전투" if run.phase == "assault" else "행군 기록"))
	pause_button.visible = run.phase in ["defense","assault"]
	danger.hide()
	match run.phase:
		"intro":
			objective.text = "패현 성문을 지키세요"
			details.text = "유방의 이야기와 전장 조작을 확인할 수 있습니다."
		"defense":
			objective.text = "성문 방어  %d%%" % run.gate
			var when = run.next_arrival()
			details.text = "%d / %d 파상   %s\n부상자 구조 %d / 3   보강 자재 %d\nQ 집결 %s" % [
				run.wave,Run.WAVE_AT.size(),"다음 도착 "+format_time(when) if when >= 0 else "남은 적 %d명" % run.living(run.foes).size(),
				run.saved_wounds(),run.repairs,format_time(run.rally_cd) if run.rally_cd else "준비"]
			if run.wave_warning():
				danger.text = "대규모 증원 접근!"
				danger.show()
		"camp":
			objective.text = "회복, 등용, 특기 배정"
			details.text = "부상자 %d명 구조\n등용: %s" % [run.saved_wounds(),"1회 남음" if run.rolled.is_empty() else "사용함"]
		"assault":
			if run.route.is_empty():
				objective.text = "정면 합류 또는 측문 개방"
			elif run.loading < 0:
				objective.text = "군량고 봉인 해제"
			else:
				objective.text = "군량 수송  %d%%" % mini(100,int(run.loading/0.48))
			var when = maxf(0.0,run.next_patrol-run.time)
			details.text = "수송 증원 %d / 4  ·  남은 적 %d명" % [run.loading_group,run.living(run.foes).size()] if run.loading >= 0.0 else "다음 순찰 도착 %s" % format_time(when)
		_:
			objective.text = "승리" if run.phase == "won" else "패배"
			details.text = run.outcome
	dispatch_log.text = "\n".join(run.logs.slice(0,3)).left(157)
	for u in run.team:
		if not rows.has(u.id):
			var card = PanelContainer.new()
			card.add_theme_stylebox_override("panel",style(Color("18120e"),6,3))
			unit_rows.add_child(card)
			var v = vertical(card,2)
			var top = line(v,9)
			var title = label(top,"",15)
			top.add_spacer(false)
			var hp = label(top,"",13,GOLD)
			var bar = ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 4
			bar.add_theme_stylebox_override("background",style(Color("3f3025")))
			bar.add_theme_stylebox_override("fill",style(Color("b58b39")))
			v.add_child(bar)
			var sub = paragraph(v,"",12,MUTED)
			rows[u.id] = [title,hp,bar,sub]
		var parts = rows[u.id]
		parts[0].text = "%s   Lv.%d" % [Run.ROSTER[u.id][0],u.level]
		parts[1].text = "%d / %d" % [u.hp,u.max_hp]
		parts[2].max_value = u.max_hp
		parts[2].value = u.hp
		var titles = u.skills.map(func(id): return Run.PERKS[id][0])
		parts[3].text = "%s  XP %d/%d   피로 %d   사기 %d\n특기 %s" % [
			u.weapon,u.xp,run.xp_limit(u),roundi(u.fatigue),roundi(u.morale),
			", ".join(titles) if not titles.is_empty() else "없음"]
		if u.hp == 0:
			parts[3].text += "   쓰러짐"

func anchor(at: Vector2) -> Vector2:
	return picture.position + at * picture.size / Run.SIZE

func marker(key: String, caption: String, at: Vector2, font_size: int, color: Color, used: Dictionary) -> Label:
	if not markers.has(key):
		var el = label(labels,caption,font_size,color)
		el.mouse_filter = Control.MOUSE_FILTER_IGNORE
		el.add_theme_constant_override("outline_size",3)
		el.add_theme_color_override("font_outline_color",Color("251b12"))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		markers[key] = el
	var m = markers[key]
	if m.text != caption:
		m.text = caption
		m.reset_size()
	elif m.size.x == 0:
		m.reset_size()
	m.position = anchor(at) - Vector2(m.size.x/2.0,m.size.y)
	m.show()
	used[key] = true
	return m

func draw_overlay_markers() -> void:
	var used = {}
	if run.phase in ["defense","assault"]:
		for u in run.team:
			var key = u.id
			marker(key,Run.ROSTER[key][0],u.p + Vector2(0,19),13,GOLD,used)
			if u.speech > 0:
				var bubble = marker("voice-"+key,"“"+u.bubble+"”",u.p+Vector2(0,-39),14,PAPER,used)
				bubble.add_theme_stylebox_override("normal",style(Color("2e2219e7"),4,3))
		var target = run.target_at(run.team[0].p)
		if not target.is_empty():
			var tag = "E 길게  " + target.label
			var percent = 0.0
			if not run.interaction.is_empty():
				percent = run.interaction.progress
				tag = "%s  %d%%" % [target.label,int(minf(1,percent)*100)]
			marker("active-point",tag,target.p+Vector2(0,-24),15,PAPER,used)
			if not markers.has("hold-bar"):
				var progress = ProgressBar.new()
				progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
				progress.show_percentage = false
				progress.max_value = 1.0
				progress.add_theme_stylebox_override("background",style(Color("291e17"),0,3))
				progress.add_theme_stylebox_override("fill",style(Color("cb873a"),0,3))
				labels.add_child(progress)
				markers["hold-bar"] = progress
			var progress = markers["hold-bar"]
			progress.position = anchor(target.p+Vector2(0,-22))-Vector2(40,0)
			progress.size = Vector2(80,7)
			progress.value = percent
			progress.visible = percent > 0
			used["hold-bar"] = true
		if run.phase == "defense":
			for i in range(run.wounds.size()):
				var wound = run.wounds[i]
				if wound.state == "waiting" and (target.is_empty() or wound.p != target.p):
					marker("wound%d"%i,wound.name,wound.p+Vector2(0,-10),12,GOLD,used)
			if target.is_empty() or target.id != "stairs":
				marker("stairs","성벽 계단",Run.STAIR,13,GOLD,used)
		elif run.route.is_empty():
			marker("join","정면 합류",Run.FRONT,14,GOLD,used)
			marker("flank","측문",Run.SIDE,14,GOLD,used)
		elif target.is_empty() or target.id != "supply":
			marker("stock","군량고",Run.SUPPLY,14,GOLD,used)
		var i = 0
		for fx in run.effects:
			if not fx.has("label"):
				continue
			i += 1
			var dy = -13.0 if motion_reduced else -13.0 - (0.8-fx.life)*18
			var color = Color("f29257") if fx.tone == "harm" else Color("edb652")
			var floating = marker("number%d"%i,fx.label,fx.p+Vector2(0,dy),16,color,used)
			floating.add_theme_color_override("font_color",color)
	for key in markers:
		if not used.has(key):
			markers[key].hide()

func build_audio() -> void:
	var winds = {"swing":[250.0,0.09,0.17], "hit":[117.0,0.18,0.52], "bow":[583.0,0.12,0.25],
		"warning":[96.0,0.47,0.12], "march":[144.0,0.24,0.11], "complete":[528.0,0.19,0.03]}
	var noise = RandomNumberGenerator.new()
	noise.seed = 4548
	for key in winds:
		var sample = winds[key]
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var output = PackedByteArray()
		var count = int(sample[1]*wav.mix_rate)
		output.resize(count*2)
		for i in range(count):
			var t = float(i)/wav.mix_rate
			var decay = pow(1.0 - float(i)/count,2.4)
			var wave = sin(TAU*t*sample[0]*(1.0-1.5*t)) * 0.54 + sin(TAU*t*sample[0]*1.4)*0.19
			var value = (wave + noise.randf_range(-1,1)*sample[2])*decay
			output.encode_s16(i*2,roundi(value*11500))
		wav.data = output
		audio[key] = wav
	for j in range(5):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -13
		add_child(voice)
		audio_players.append(voice)

func play_sound(id: String) -> void:
	if not sound_on or audio_players.is_empty():
		return
	var voice = audio_players[channel]
	voice.stream = audio[id]
	voice.play()
	channel = (channel + 1) % audio_players.size()

func consume_sound() -> void:
	for id in run.sound_events.slice(0,5):
		play_sound(id)
	run.sound_events.clear()
