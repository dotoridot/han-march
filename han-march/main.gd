extends Control

const Campaign = preload("res://campaign.gd")
const Landscape = preload("res://landscape.gd")
const MountedMap = preload("res://mounted_map.gd")
const FeatureModel = preload("res://feature_model.gd")
const FONT = preload("res://assets/NotoSansKR.ttf")
const PAPER = Color("f4e6c8")
const SUBTLE = Color("c6b598")
const GOLD = Color("e3ad5e")
const RECRUIT_GREEN = Color("86d8ab")
const PROMOTION_BLUE = Color("9acaff")
const NIGHT = Color("181310")
const PANEL = Color("2a201a")
const PRIMARY = Color("914420")
const IMMEDIATE = Color("facf8c")
const MAP_INK = Color("222120f0")
const MAP_SECONDARY = Color("ddd4c5")
const MAP_ICONS = preload("res://assets/strategy_routes.svg")
const AUDIO_SLOTS = 4
const CUE_PITCHES = [1.0,0.97,1.03,0.99,1.02]

var game = Campaign.new()
var body_font: FontVariation
var title_font: FontVariation
var landscape
var mounted_map: MountedMap
var seal_view: FeatureModel
var dice_view: FeatureModel
var map_prompt: Label
var map_overlay: MarginContainer
var map_choices: Array[Button] = []
var map_prompt_index := -2
var skill_status: Label
var confirmed_draft: Dictionary = {}
var draft_resolution := ""
var march_at := Vector2(0,4.2)
var marching := false
var travel_from := 0.0
var stage: VBoxContainer
var screen_body: VBoxContainer
var viewport_panel: PanelContainer
var modal: ColorRect
var modal_content: VBoxContainer
var resume_control: Control
var history_label: Label
var objective: Label
var action_status: Label
var trail_status: Label
var field_status: Label
var header_title: Label
var menu_button: Button
var primary_button: Button
var run_seed: LineEdit
var manager
var text_data: DialogueResource
var modal_active = false
var motion_reduced = false
var text_zoom = 1.0
var travel_time = 0.0
var announced_phase = ""
var last_message = ""
var last_message_left = 0.0
var saved_count = 0
var checkpoint_data: Dictionary = {}
var save_error = false
var introduction_open = false
var store_path = "user://campaign.cfg"
var audio_players: Array[AudioStreamPlayer] = []
var audio_started: Array[int] = []
var audio_next := 0
var audio_sequence := 0
var sounds: Dictionary = {}
var impacts: Dictionary = {}
var recorded_impacts := true
var hit_pending = false
var dodge_pending = false
var skill_pending = false
var mouse_at = Vector2(300,200)
var inspected_ally := -1
var scene_variant_text = {
	"안개":"안개: 활 사거리 감소","진흙":"진흙: 남쪽 이동 느림","고지":"고지: 낮은 곳의 적 이동이 느림"
}

func _ready() -> void:
	Engine.max_fps = 60
	if OS.get_environment("HAN_MARCH_MUTE")=="1":
		AudioServer.set_bus_mute(0,true)
	get_window().title = "초한: 한왕의 길"
	get_window().min_size = Vector2i(760,544)
	if OS.has_environment("HAN_MARCH_PROFILE"):
		store_path = OS.get_environment("HAN_MARCH_PROFILE").path_join("campaign.cfg")
	var cfg = ConfigFile.new()
	cfg.load(store_path)
	game.record.assign(cfg.get_value("chronicle","discovered",[]))
	motion_reduced = cfg.get_value("options","reduced_motion",false)
	recorded_impacts = cfg.get_value("options","recorded_impacts",true)
	text_zoom = cfg.get_value("options","text_scale",1.0)
	saved_count = game.record.size()
	introduction_open = not "opening" in game.record
	checkpoint_data = cfg.get_value("checkpoint","state",{})
	game.mount(self)
	manager = preload("res://addons/dialogue_manager/dialogue_manager.gd").new()
	add_child(manager)
	manager.include_dialogue_resource_as_self = false
	text_data = manager.create_resource_from_text(FileAccess.get_file_as_string("res://assets/chronicle.dialogue.txt"))
	build_theme()
	build_shell()
	build_sound()
	show_phase()

func _exit_tree() -> void:
	if text_data != null:
		text_data.lines.clear()
		text_data = null
	if Engine.has_singleton("DialogueManager") and Engine.get_singleton("DialogueManager")==manager:
		Engine.unregister_singleton("DialogueManager")

func skin(color: Color, pad: int = 0) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		box.set_content_margin(side,pad)
	return box

func build_theme() -> void:
	var theme_data = Theme.new()
	var weight = TextServerManager.get_primary_interface().name_to_tag("wght")
	body_font = FontVariation.new()
	body_font.base_font = FONT
	body_font.variation_opentype = {weight:475}
	title_font = FontVariation.new()
	title_font.base_font = FONT
	title_font.variation_opentype = {weight:675}
	theme_data.default_font = body_font
	theme_data.default_font_size = roundi(16*text_zoom)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		theme_data.set_color(state,"Button",PAPER)
	theme_data.set_color("font_color","Label",PAPER)
	theme_data.set_color("font_color","LineEdit",PAPER)
	theme_data.set_color("font_placeholder_color","LineEdit",SUBTLE)
	theme_data.set_stylebox("normal","LineEdit",skin(Color("392a20"),8))
	theme_data.set_stylebox("focus","LineEdit",skin(Color("503722"),8))
	for state in [["normal","624626"],["hover","765433"],["pressed","4f351f"],["disabled","3a2d22"]]:
		theme_data.set_stylebox(state[0],"Button",skin(Color(state[1]),9))
	theme_data.set_stylebox("focus","Button",StyleBoxEmpty.new())
	theme = theme_data

func row(parent: Node, gap: int = 10) -> HBoxContainer:
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation",gap)
	parent.add_child(layout)
	return layout

func flow(parent: Node, gap: int = 8) -> HFlowContainer:
	var layout = HFlowContainer.new()
	layout.add_theme_constant_override("h_separation",gap)
	layout.add_theme_constant_override("v_separation",gap)
	parent.add_child(layout)
	return layout

func column(parent: Node, gap: int = 9) -> VBoxContainer:
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation",gap)
	parent.add_child(layout)
	return layout

func words(parent: Node, copy: String, size_px: int = 16, color: Color = PAPER, wrap: bool = false) -> Label:
	var value = Label.new()
	value.text = copy
	if size_px>=21:
		value.add_theme_font_override("font",title_font)
	value.add_theme_color_override("font_color",color)
	value.add_theme_font_size_override("font_size",roundi(size_px*text_zoom))
	value.add_theme_constant_override("line_spacing",4)
	if wrap:
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(value)
	return value

func action(parent: Node, copy: String, callback: Callable, main: bool = false) -> Button:
	var b = Button.new()
	b.text = copy
	b.accessibility_name = copy
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	if main:
		b.add_theme_stylebox_override("normal",skin(PRIMARY,9))
		b.add_theme_stylebox_override("hover",skin(Color("a24c25"),9))
		b.add_theme_stylebox_override("pressed",skin(Color("763b25"),9))
	parent.add_child(b)
	var focus = ColorRect.new()
	focus.mouse_filter = MOUSE_FILTER_IGNORE
	focus.color = IMMEDIATE
	b.add_child(focus)
	focus.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	focus.offset_left = 8
	focus.offset_right = -8
	focus.offset_top = -5
	focus.offset_bottom = -2
	focus.hide()
	b.focus_entered.connect(focus.show)
	b.focus_exited.connect(focus.hide)
	return b

func full(parent: Control, child: Control) -> void:
	parent.add_child(child)
	child.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func build_shell() -> void:
	var background = ColorRect.new()
	background.color = NIGHT
	background.mouse_filter = MOUSE_FILTER_IGNORE
	full(self,background)
	mounted_map = MountedMap.new()
	full(self,mounted_map)
	mounted_map.hide()
	mounted_map.route_pressed.connect(choose_route)
	mounted_map.route_hovered.connect(set_map_hover)

	var margin = MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(edge,18)
	full(self,margin)
	stage = column(margin,10)
	var bar = row(stage)
	var seal = PanelContainer.new()
	seal.add_theme_stylebox_override("panel",skin(Color("753921"),6))
	bar.add_child(seal)
	words(seal,"漢",24)
	header_title = words(bar,"한왕의 길",22)
	header_title.size_flags_horizontal = SIZE_EXPAND_FILL
	menu_button = action(bar,"메뉴",show_menu)
	viewport_panel = PanelContainer.new()
	viewport_panel.size_flags_vertical = SIZE_EXPAND_FILL
	viewport_panel.add_theme_stylebox_override("panel",skin(PANEL,8))
	stage.add_child(viewport_panel)
	landscape = Landscape.new()
	landscape.custom_minimum_size.y = 134
	landscape.game = game
	viewport_panel.add_child(landscape)
	seal_view = FeatureModel.new()
	seal_view.custom_minimum_size.y = 125
	viewport_panel.add_child(seal_view)
	seal_view.hide()
	screen_body = column(stage,8)
	map_overlay = MarginContainer.new()
	map_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
		map_overlay.add_theme_constant_override(edge,16)
	full(self,map_overlay)
	map_overlay.hide()
	modal = ColorRect.new()
	modal.color = Color("15100edc")
	full(self,modal)
	var center = CenterContainer.new()
	full(modal,center)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel",skin(PANEL,17))
	center.add_child(card)
	var scroller = ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(560,385)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroller)
	modal_content = column(scroller,10)
	modal_content.size_flags_horizontal = SIZE_EXPAND_FILL
	modal.hide()

func empty(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func defer_focus(node: Control) -> void:
	if node==primary_button and game.phase=="camp":
		await get_tree().process_frame
	if is_instance_valid(node) and node.is_visible_in_tree() and (not node is BaseButton or not node.disabled):
		node.grab_focus()

func note_dialogue(parent: Control, key: String, tooltip := false) -> void:
	var label = words(parent,"",16,SUBTLE,true) if not tooltip else null
	var line_data = await manager.get_next_dialogue_line(text_data,key,[{"fantasy":game.mode=="fiction","has_xiang":"xiang" in game.hero_keys,
		"first_rescue":game.rescue_order.front() if not game.rescue_order.is_empty() else "",
		"approach":game.selected_route}])
	if line_data==null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var line = "%s  %s" % [line_data.character,line_data.text]
	if tooltip:
		parent.tooltip_text = line
	elif is_instance_valid(label):
		label.text = line

func show_phase(reveal_draft := false) -> void:
	var old_phase = announced_phase
	empty(screen_body)
	announced_phase = game.phase
	if game.phase!="camp" or old_phase!="camp":
		draft_resolution = ""
	if game.phase!="map" or old_phase not in ["camp","map"]:
		confirmed_draft.clear()
	if game.phase=="battle" and old_phase!="battle":
		inspected_ally = -1
	var on_map: bool = game.phase in ["map","travel"]
	var body_parent: Control = map_overlay if on_map else stage
	if screen_body.get_parent()!=body_parent:
		screen_body.reparent(body_parent,false)
		if not on_map:
			stage.move_child(screen_body,-1)
	screen_body.mouse_filter = MOUSE_FILTER_IGNORE if on_map else MOUSE_FILTER_PASS
	screen_body.size_flags_vertical = SIZE_EXPAND_FILL if on_map else SIZE_FILL
	stage.visible = not (on_map or modal_active)
	map_overlay.visible = on_map and not modal_active
	landscape.display = "battle" if game.phase=="battle" else "map"
	landscape.reduce_motion = motion_reduced
	landscape.text_zoom = text_zoom
	viewport_panel.visible = game.phase in ["title","battle","ending","lost"]
	mounted_map.visible = on_map
	seal_view.visible = game.phase=="title"
	seal_view.reduced = motion_reduced
	landscape.visible = game.phase in ["battle","ending","lost"]
	landscape.custom_minimum_size.y = 206 if game.phase=="battle" else 125
	if mounted_map.visible:
		if old_phase=="camp" and game.phase=="map": march_at = MountedMap.TRAILS[0][0]
		mounted_map.point = march_at
		if old_phase not in ["map","travel"]:
			mounted_map.fit_routes(0.0,0.0)
		var branch: int = game.selected_route if game.phase=="travel" else -1
		mounted_map.setup(game.chapter,game.entry().routes,game.supply,text_zoom,branch)
	primary_button = null
	match game.phase:
		"title":
			title_view()
		"map":
			map_view(reveal_draft)
		"travel":
			map_header(game.entry())
			screen_body.add_spacer(false).mouse_filter = MOUSE_FILTER_IGNORE
			var strip = row(screen_body)
			var destination = column(strip,3)
			destination.size_flags_horizontal = SIZE_EXPAND_FILL
			var approach: String = game.entry().routes[game.selected_route][0]
			var panel = PanelContainer.new()
			panel.add_theme_stylebox_override("panel",skin(MAP_INK,10))
			destination.add_child(panel)
			words(panel,"%s 선택 / %s 이동 중" % [approach,game.entry().name],17,PAPER,true)
			primary_button = action(strip,"전장으로",complete_travel)
			map_button_skin(primary_button)
		"battle":
			battle_view()
		"camp":
			camp_view(reveal_draft)
		"ending","lost":
			result_view()
	landscape.queue_redraw()
	if primary_button!=null and not modal_active:
		var focus = map_choices[1] if game.phase=="map" and primary_button.disabled else primary_button
		defer_focus.call_deferred(focus)

func title_view() -> void:
	words(screen_body,"초한: 한왕의 길",41)
	words(screen_body,"한중에서 즉위까지, 기원전 206년부터 202년",17,GOLD)
	if introduction_open:
		note_dialogue(screen_body,"opening")
	var intro_action = "도입 접기" if introduction_open else "도입 다시 보기"
	action(screen_body,intro_action,toggle_intro)
	var controls = row(screen_body)
	primary_button = action(controls,"역사 행군 시작",start_historical,true)
	action(controls,"가상 행군 시작",start_fictional)
	run_seed = LineEdit.new()
	run_seed.placeholder_text = "예: 12345"
	run_seed.accessibility_name = "시드 번호"
	run_seed.max_length = 12
	run_seed.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.add_child(run_seed)
	words(screen_body,"시드 번호를 비우면 무작위로 시작합니다. 패배하면 편성, 보급, 강화가 초기화되고 행군 기록은 남습니다.",14,SUBTLE,true)
	if not checkpoint_data.is_empty() and checkpoint_data.get("phase") in ["map","travel","camp"]:
		action(controls,"이어하기",continue_run)

func toggle_intro() -> void:
	introduction_open = not introduction_open
	show_phase()

func continue_run() -> void:
	if game.restore(checkpoint_data):
		confirmed_draft.clear()
		march_at = checkpoint_data.get("march_at",MountedMap.TRAILS[0][0])
		travel_time = 0.0
		travel_from = 0.0
		show_phase()

func start_historical() -> void:
	start_run("history")

func start_fictional() -> void:
	start_run("fiction")

func start_run(mode: String) -> void:
	var value = run_seed.text.strip_edges() if is_instance_valid(run_seed) else ""
	if not value.is_empty() and not value.is_valid_int():
		run_seed.placeholder_text = "숫자만 입력하세요. 무작위 행군은 칸을 비우세요."
		run_seed.clear()
		run_seed.grab_focus()
		return
	march_at = MountedMap.TRAILS[0][0]
	game.new_run(value.to_int() if value.is_valid_int() else randi_range(100000,99999999),mode)
	show_phase()
	save()

func map_button_skin(button: Button) -> void:
	for state in [["normal","262320ed"],["hover","6d2921f5"],["pressed","912c22"],
			["disabled","36312def"]]:
		var surface = skin(Color(state[1]),11)
		surface.shadow_color = Color("1b151447")
		surface.shadow_size = 5
		surface.shadow_offset = Vector2(0,3)
		button.add_theme_stylebox_override(state[0],surface)
	button.mouse_default_cursor_shape = CURSOR_ARROW if button.disabled else CURSOR_POINTING_HAND

func map_header(data: Dictionary) -> void:
	var headline = row(screen_body,8)
	var heading = PanelContainer.new()
	heading.add_theme_stylebox_override("panel",skin(MAP_INK,9))
	headline.add_child(heading)
	var headings = row(heading,11)
	words(headings,data.name,25,PAPER)
	var date = words(headings,data.year,14,MAP_SECONDARY)
	date.size_flags_vertical = SIZE_SHRINK_CENTER
	heading.tooltip_text = "지형과 경유지는 창작입니다."
	headline.add_spacer(false)
	var logistics = PanelContainer.new()
	logistics.add_theme_stylebox_override("panel",skin(MAP_INK,9))
	headline.add_child(logistics)
	var counts = row(logistics,10)
	var supply = words(counts,"보급 %d" % game.supply,17,GOLD)
	supply.size_flags_vertical = SIZE_SHRINK_CENTER
	var seed = words(counts,"시드 %d" % game.seed_value,14,MAP_SECONDARY)
	seed.size_flags_vertical = SIZE_SHRINK_CENTER
	var menu = action(headline,"메뉴",show_menu)
	map_button_skin(menu)

func map_view(reveal_draft: bool) -> void:
	var data: Dictionary = game.entry()
	var orders: Array = game.names_upgrades["liu"]
	map_header(data)
	var upper = row(screen_body,12)
	var notes = PanelContainer.new()
	notes.add_theme_stylebox_override("panel",skin(MAP_INK,6))
	var has_draft = not confirmed_draft.is_empty()
	notes.custom_minimum_size.x = 290 if has_draft else 380
	notes.size_flags_vertical = SIZE_SHRINK_BEGIN
	upper.add_child(notes)
	var story = column(notes,1)
	story.size_flags_horizontal = SIZE_EXPAND_FILL
	var names: Array[String] = []
	for hero in game.hero_keys:
		names.append(Campaign.HEROES[hero][0])
	words(story,"유방의 군세 / %s" % "  ".join(names),14,PAPER,true)
	note_dialogue(notes if has_draft else story,data.id,has_draft)
	upper.add_spacer(false)
	if not game.ration_hero.is_empty():
		words(story,"군량 순환 / %s 최대 및 시작 MP +4, 첫 공격 또는 응급 처치 시 피로 최대 -10" %
			Campaign.HEROES[game.ration_hero][0],14,GOLD,true)
	if has_draft:
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel",skin(MAP_INK,7))
		panel.custom_minimum_size.x = 400
		panel.size_flags_vertical = SIZE_SHRINK_BEGIN
		upper.add_child(panel)
		var result = row(panel,6)
		dice_view = FeatureModel.new()
		dice_view.seal = false
		dice_view.reduced = motion_reduced
		dice_view.custom_minimum_size = Vector2(56,52)
		result.add_child(dice_view)
		dice_view.set_face(confirmed_draft.face,reveal_draft,confirmed_draft.color)
		var details = column(result,2)
		details.size_flags_horizontal = SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		words(details,"18면 대길" if confirmed_draft.face==18 else "%d면" % confirmed_draft.face,15,GOLD,true)
		words(details,confirmed_draft.text,16,confirmed_draft.color,true)

	screen_body.add_spacer(false).mouse_filter = MOUSE_FILTER_IGNORE
	var choices = row(screen_body,12)
	map_choices.clear()
	for i in data.routes.size():
		var path: Array = data.routes[i]
		var forecast: Dictionary = game.preview_route(i)
		var locked: bool = game.supply + path[3]<0
		var b = action(choices,"",choose_route.bind(i))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.disabled = locked
		if locked:
			b.focus_mode = FOCUS_NONE
		map_button_skin(b)
		var content = MarginContainer.new()
		content.mouse_filter = MOUSE_FILTER_IGNORE
		for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
			content.add_theme_constant_override(edge,10)
		full(b,content)
		var card = row(content,8)
		card.mouse_filter = MOUSE_FILTER_IGNORE
		var icon = TextureRect.new()
		var route_icon = AtlasTexture.new()
		route_icon.atlas = MAP_ICONS
		route_icon.region = Rect2((game.chapter*2+i)*48,0,48,48)
		icon.texture = route_icon
		icon.custom_minimum_size = Vector2(36,36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = SIZE_SHRINK_CENTER
		icon.modulate = Color("b1a39d") if locked else Color.WHITE
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var details = column(card,2)
		details.mouse_filter = MOUSE_FILTER_IGNORE
		details.size_flags_horizontal = SIZE_EXPAND_FILL
		var title = words(details,"%s%s" % [path[0]," / 보급 부족" if locked else ""],21,PAPER,true)
		var summary = "%s / 적 %d명%s / %s" % [
			forecast.weather,forecast.opponents,"(추격대 별도)" if game.chapter==1 else "",path[2]]
		words(details,summary,14,GOLD,true)
		words(details,path[1],14,MAP_SECONDARY,true)
		if "last_stand" in orders and game.supply+path[3]==0:
			words(details,"배수진 적용 / 공격 피해 +30%, 특기 대기 -25%",14,GOLD,true)
		b.accessibility_name = title.text
		b.accessibility_description = "%s / %s" % [summary,path[1]]
		content.minimum_size_changed.connect(func(): b.custom_minimum_size = content.get_combined_minimum_size())
		b.custom_minimum_size = content.get_combined_minimum_size()
		b.mouse_entered.connect(set_map_hover.bind(i))
		b.mouse_exited.connect(set_map_hover.bind(-1))
		b.focus_entered.connect(set_map_focus.bind(i))
		b.focus_exited.connect(set_map_focus.bind(-1))
		map_choices.append(b)
		if i==0: primary_button = b

	var help = PanelContainer.new()
	help.add_theme_stylebox_override("panel",skin(MAP_INK,8))
	screen_body.add_child(help)
	map_prompt = words(help,"",14,PAPER,true)
	map_prompt_index = -2
	refresh_map_prompt(mounted_map.nearby)
	var fit = fit_map_routes.bind(upper,choices)
	upper.item_rect_changed.connect(fit.call_deferred)
	choices.item_rect_changed.connect(fit.call_deferred)
	fit.call_deferred()

func fit_map_routes(upper: Control, choices: Control) -> void:
	if game.phase=="map" and is_instance_valid(upper) and upper.is_inside_tree() and choices.is_inside_tree():
		mounted_map.fit_routes(upper.get_global_rect().end.y+54,choices.global_position.y-18)

func set_map_hover(index: int) -> void:
	mounted_map.hovered_route = index
	mounted_map.queue_redraw()

func set_map_focus(index: int) -> void:
	mounted_map.focused_route = index
	mounted_map.queue_redraw()

func refresh_map_prompt(index: int) -> void:
	if not is_instance_valid(map_prompt) or map_prompt_index==index: return
	map_prompt_index = index
	if index<0:
		map_prompt.text = "WASD 또는 방향키로 이동 / 깃발 근처에서 E 출정 / 깃발이나 카드 선택"
	else:
		var path: Array = game.entry().routes[index]
		var suffix = "보급 부족으로 출발할 수 없습니다." if game.supply+path[3]<0 else "E로 출발"
		map_prompt.text = "%s / %s / %s" % [path[0],game.entry().goal,suffix]

func choose_route(index: int) -> void:
	var before = game.checkpoint()
	if game.choose_route(index):
		if not save():
			game.restore(before)
			show_save_error()
			return
		travel_time = 0.0
		travel_from = 1.0 if mounted_map.nearby==index else 0.0
		show_phase()
		if motion_reduced:
			complete_travel()

func complete_travel() -> void:
	game.enter_battle()
	if game.phase=="battle":
		if game.chapter==0 and not "dodge_lesson" in game.record:
			game.training_ticks = 54
			game.training_at = game.team[0].p
		show_phase()

func battle_view() -> void:
	objective = words(screen_body,game.entry().goal,21,GOLD)
	action_status = words(screen_body,"",15,PAPER,true)
	trail_status = words(screen_body,game.entry().description,14,SUBTLE)
	if game.chapter==3:
		note_dialogue(screen_body,"gaixia_route")
	field_status = words(screen_body,"",14,SUBTLE,true)
	skill_status = words(screen_body,"",14,PAPER,true)
	words(screen_body,"WASD 이동 / 마우스 또는 J 공격 / Space 또는 Shift 회피 / E 길게 상호작용 / C 동료 확인 / Esc 일시정지",14,SUBTLE,true)
	refresh_battle()

func refresh_battle() -> void:
	if not is_instance_valid(action_status) or game.team.is_empty():
		return
	var status = ["관문 주변의 적을 먼저 정리하세요.", "구출 %d/2  ·  추격대 %d/4" % [game.rescued,game.patrol], "수레 HP %d  ·  성고까지 %d%%" % [maxi(0,roundi(game.wagon_hp)),roundi((game.wagon.x-112)/444*100)], "방책 %d/2  ·  %s" % [game.gates,"적장 항우" if game.mode=="history" else "가상 지휘관"]][game.chapter]
	var evasion = "회피 준비" if game.dodge_cd<=0 else "회피 %.1f초" % game.dodge_cd
	action_status.text = "%s   /   %s   /   %s" % [status,evasion,game.tactic_name()]
	if game.last_stand:
		action_status.text += " / 배수진"
	if game.counter_until>0 and game.counter_until>=game.step_number:
		action_status.text += " / 기습 반격 %.1f초" % ((game.counter_until-game.step_number+1)*Campaign.STEP)
	trail_status.text = "예고가 보이면 좌우로 움직이며 Space 또는 Shift를 누르세요." if game.training_ticks>0 else (last_message if last_message_left>0 else game.entry().description)
	var field_note: String = scene_variant_text.get(game.field_rule,"") if game.scout_bonus.is_empty() else game.scout_bonus
	var allies = game.alive(game.team)
	if not allies.is_empty():
		var index = allies.find_custom(func(unit): return unit.uid==inspected_ally)
		var ally: Dictionary = allies[maxi(0,index)]
		inspected_ally = ally.uid
		landscape.inspected_uid = inspected_ally
		var detail = "%s  HP %d/%d  MP %d/%d  피로 %d/100" % [
			Campaign.HEROES[ally.id][0],ceili(ally.hp),ally.max_hp,floori(ally.mp),ally.max_mp,roundi(ally.fatigue)]
		field_status.text = detail if field_note.is_empty() else detail+"  /  "+field_note
	else:
		inspected_ally = -1
		landscape.inspected_uid = -1
		field_status.text = field_note
	var id: String = game.player_skill
	var player: Dictionary = game.team[0]
	var cooldown: float = player.cool.get(id,0.0)
	var cost: int = Campaign.ABILITIES[id][0]
	var availability = "%.1f초 후" % cooldown if cooldown>0 else ("MP 부족" if player.mp<cost else "사용 가능")
	skill_status.text = "F %s / %s / MP %d/%d, 소모 %d / %s%s" % [
		Campaign.SKILL_INFO[id][0],Campaign.SKILL_INFO[id][1],floori(player.mp),player.max_mp,cost,availability,
		" / R 특기 전환" if game.player_skills().size()>1 else ""]

func camp_view(reveal_draft: bool) -> void:
	words(screen_body,game.last_result,16,SUBTLE,true)
	var next_chapter: int = game.chapter+1
	var next: Dictionary = Campaign.PLAN.chapters[next_chapter]
	words(screen_body,"다음 전장 / %s" % next.name,18,GOLD,true)
	var threat: String = {
		1:"시간이 지나면 추격병이 합류합니다.",
		2:"수레가 전진하면 매복한 적이 나타납니다.",
		3:"두 방책을 열기 전에는 지휘관에게 피해를 줄 수 없습니다.",
	}[next_chapter]
	words(screen_body,"%s %s" % [threat,next.description],14,PAPER,true)
	var routes: Array = next.routes
	var departure_supply: int = game.supply
	var projected_draft: Dictionary = game.project_candidate(game.draft_candidate,draft_resolution)
	if not projected_draft.is_empty():
		departure_supply = projected_draft.supply_after
	var route_notes: Array[String] = []
	var force = "매복병이" if next_chapter==2 else "초기 적이"
	for i in routes.size():
		var route: Array = routes[i]
		var note: String
		if departure_supply+route[3]<0:
			note = "보급 부족, %d 필요" % -route[3]
		else:
			var other: Array = routes[1-i]
			note = "%s %s" % [force,"적음" if route[4]<other[4] else "많음"]
		route_notes.append("%s (%s)" % [route[0],note])
	words(screen_body,"경유지 선택 전 / %s. 지형은 경유지에 따라 달라집니다." % ", ".join(route_notes),14,SUBTLE,true)
	var reward_notes = {}
	if game.golden_refund():
		var id: String = game.draft_candidate
		var resolutions = ["promote","supply"] if id in game.hero_keys else [""]
		for resolution in resolutions:
			var projected: Dictionary = game.project_candidate(id,resolution)
			if projected.is_empty():
				continue
			var choice: String = {"promote":"승급","supply":"보급 전환","":"합류"}[resolution]
			reward_notes[resolution] = "%s 시 보급 %d → %d / 전환 +%d / 황금 눈 +%d (상한 %d)" % [
				choice,game.supply,projected.supply_after,projected.gain,projected.refund,Campaign.SUPPLY_CAP]
		var lines = [reward_notes[draft_resolution]] if reward_notes.has(draft_resolution) else reward_notes.values()
		words(screen_body,"\n".join(lines),14,GOLD,true)
	var columns = row(screen_body,12)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 185
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_body.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_child(scroll)
	var sheet = column(scroll,11)
	sheet.size_flags_horizontal = SIZE_EXPAND_FILL
	words(sheet,"야영지 / 보급 %d / %s" % [game.supply,"역사 행군" if game.mode=="history" else "가상 행군"],20,PAPER,true)
	var current: String = game.tactic_effects(game.tactics)
	words(sheet,"현재 진법: "+current,16,GOLD,true)
	var orders = Campaign.PLAN.perks.filter(func(perk):
		return perk.tag=="군령" and perk.id in game.names_upgrades["liu"])
	for order in orders:
		words(sheet,"%s / %s" % [order.name,order.text],14,SUBTLE,true)
	if game.chapter==1:
		note_dialogue(sheet,"rescued")
	if not game.draft_done:
		words(sheet,"균형은 무료, 우대는 굴릴 때 보급 1을 씁니다.",15,SUBTLE,true)
		if game.first_free_recruit():
			words(sheet,"첫 야영지의 균형 굴림은 미보유 장수가 나옵니다.",15,GOLD,true)
	var die_column = column(columns,5)
	die_column.custom_minimum_size.x = 155
	dice_view = FeatureModel.new()
	dice_view.seal = false
	dice_view.reduced = motion_reduced
	dice_view.custom_minimum_size = Vector2(155,120)
	die_column.add_child(dice_view)
	var number = game.draft_result.get_slice("면",0).to_int() if not game.draft_candidate.is_empty() else 0
	dice_view.set_face(number,reveal_draft)
	var face_label = words(die_column,"눈 %d / 18" % number if number>0 else "18면 등용 주사위",15,GOLD)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if number==18:
		words(die_column,"18면 대길",16,GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not game.draft_done:
		var options = flow(sheet)
		for option in [["balance","균형 / 무료"],["shield","방패 우대 / 보급 1"],["lance","장병기 우대 / 보급 1"]]:
			var id: String = option[0]
			var b = action(options,option[1]+(" ✓" if game.draft_plan==id else ""),change_odds.bind(id))
			b.disabled = game.supply<=0 and id!="balance"
		var weights = game.draft_weights()
		var supply_gain: int = game.duplicate_supply_gain(0 if game.draft_plan=="balance" else 1)
		primary_button = action(sheet,"18면 주사위 굴리기",perform_roll,true)
		for i in weights.size():
			var id: String = Campaign.DRAFT[i]
			var after := ""
			if weights[i]==0:
				after = "역사 행군에서는 등용할 수 없습니다." if id=="xiang" and game.mode=="history" else "이번 굴림에서는 나오지 않습니다."
			elif id not in game.hero_keys:
				after = draft_tactic_line(id,"","합류",current)
			elif game.promotion_level(id)<Campaign.PROMOTION_CAP:
				after = draft_tactic_line(id,"promote","승급",current)
				after += " / 보급 +%d 전환 시 현재 진법 유지" % supply_gain
			else:
				after = draft_tactic_line(id,"supply","승급 상한 / 보급 +%d 전환" % supply_gain,current)
			words(sheet,"%s %d/18 | %s" % [Campaign.HEROES[id][0],weights[i],after],14,PAPER,true)
	else:
		var id: String = game.draft_candidate
		if id.is_empty():
			words(sheet,"저장된 굴림의 등용 후보를 확인할 수 없습니다.",16,SUBTLE,true)
		elif id in game.hero_keys:
			var level: int = game.promotion_level(id)
			var gain: int = game.project_candidate(id,"supply").gain
			var capped = level>=Campaign.PROMOTION_CAP
			words(sheet,"%d면 / %s 중복 / 현재 승급 %d/%d" % [number,Campaign.HEROES[id][0],level,Campaign.PROMOTION_CAP],17,GOLD,true)
			if draft_resolution=="promote":
				words(die_column,"%s 승급 예정\n%d단계" % [Campaign.HEROES[id][0],level+1],15,PROMOTION_BLUE,true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elif draft_resolution=="supply":
				words(die_column,"보급 +%d 전환 예정" % gain,15,PAPER,true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if not capped:
				words(sheet,draft_tactic_line(id,"promote","승급",current),15,PAPER,true)
			words(sheet,draft_tactic_line(id,"supply","보급 +%d 전환" % gain,current),15,PAPER,true)
			var rewards = flow(sheet)
			var promote_label = "승급 상한 도달" if capped else "승급 %d → %d%s" % [level,level+1," ✓" if draft_resolution=="promote" else ""]
			var promote = action(rewards,promote_label,choose_draft_resolution.bind("promote"))
			promote.disabled = capped
			var stores = action(rewards,"보급 +%d%s" % [gain," ✓" if draft_resolution=="supply" else ""],
				choose_draft_resolution.bind("supply"))
			promote.accessibility_description = reward_notes.get("promote","")
			stores.accessibility_description = reward_notes.get("supply","")
			if draft_resolution.is_empty(): primary_button = stores if promote.disabled else promote
			words(sheet,"승급 단계마다 %s. 승급 상한 %d단계 / 보급 상한 %d, 전환 시 최대 +%d" % [
				Campaign.PROMOTION[id][0],Campaign.PROMOTION_CAP,Campaign.SUPPLY_CAP,Campaign.DUPLICATE_SUPPLY],15,SUBTLE,true)
		else:
			words(sheet,"%d면 / %s 합류 예정" % [number,Campaign.HEROES[id][0]],17,GOLD,true)
			words(sheet,draft_tactic_line(id,"","합류",current),15,PAPER,true)
		var again = action(sheet,"후보 버리고 다시 굴리기 / 보급 2",perform_redraw)
		again.disabled = game.rerolled or game.supply<2
		if not reward_notes.is_empty():
			again.tooltip_text = "후보를 버리면 이 눈의 환급도 사라집니다."
			again.accessibility_description = again.tooltip_text
	words(sheet,"주 진법은 방패 엄호 > 약낭 돌파, 보조 진법은 왕의 신호 > 방패와 장창 순으로 각각 하나까지 적용됩니다.",14,SUBTLE,true)
	words(sheet,"유방과 한신은 한신 1단계부터 왕의 신호가 열립니다. 번쾌와 조참은 합류 즉시 방패와 장창을 쓰며, 조참의 승급과 한신의 2단계 이후 승급마다 해당 피해 증가량이 10%p 오릅니다.",14,SUBTLE,true)
	var choices = flow(sheet)
	for id in game.hero_keys:
		var marks: Array = game.names_upgrades[id]
		var title: String = Campaign.HEROES[id][0] + " · " + Campaign.HEROES[id][2]
		var candidate = action(choices,title + (" ✓" if id==game.offered_to else ""),focus_candidate.bind(id))
		candidate.tooltip_text = "고른 강화 %d개" % (marks.size()-(orders.size() if id=="liu" else 0))
		if Campaign.PROMOTION.has(id):
			candidate.tooltip_text += " / 승급 %d/%d" % [game.promotion_level(id),Campaign.PROMOTION_CAP]
	var active = game.names_upgrades[game.offered_to]
	var names: Array[String] = []
	for perk in Campaign.PLAN.perks:
		if perk.tag!="군령" and perk.id in active: names.append(perk.name)
	words(sheet,"%s의 강화 %s" % [Campaign.HEROES[game.offered_to][0],", ".join(names) if not names.is_empty() else "없음"],15,SUBTLE,true)
	var role_skill: String = {"fan":"shield","xiao":"heal","han":"cover","xiang":"pierce","cao":"pierce"}.get(game.offered_to,"command")
	var sheet_skills: Array = game.player_skills() if game.offered_to=="liu" else [role_skill]
	for skill in sheet_skills:
		var info: Array = Campaign.SKILL_INFO[skill]
		var price: Array = Campaign.ABILITIES[skill]
		words(sheet,"%s / %s / MP %d, 재사용 %.1f초" % [info[0],info[1],price[0],price[1]],14,SUBTLE,true)
	if game.draft_done:
		words(sheet,"강화를 고르면 등용 보상을 확정하고 출발합니다.",15,SUBTLE,true)
		if draft_resolution=="promote" and "ration_cycle" in game.names_upgrades["liu"]:
			words(sheet,"군량 순환 / 승급 확정 시 다음 전투에서 최대 및 시작 MP +4, 첫 공격 또는 응급 처치 시 피로 최대 -10",15,GOLD,true)
		if not game.draft_candidate.is_empty() and (game.draft_candidate not in game.hero_keys or not draft_resolution.is_empty()):
			var projected: Dictionary = game.project_candidate(game.draft_candidate,draft_resolution)
			words(sheet,"출발 후 진법: "+game.tactic_effects(projected.tactics),15,GOLD,true)
	else:
		words(sheet,"등용을 건너뛰려면 바로 강화를 고르세요.",15,SUBTLE,true)
	var needs_resolution = game.draft_candidate in game.hero_keys and draft_resolution.is_empty()
	for perk in game.offerings:
		var upgrade = column(sheet,3)
		var b = action(upgrade,"%s / %s" % [perk.name,perk.tag],choose_perk.bind(perk.id))
		words(upgrade,perk.text,14,SUBTLE,true)
		b.disabled = needs_resolution
		b.accessibility_description = reward_notes.get(draft_resolution,"")
		if primary_button==null and not needs_resolution: primary_button = b

func draft_tactic_line(id: String, resolution: String, label: String, current: String) -> String:
	var projected: Dictionary = game.project_candidate(id,resolution)
	var after: String = game.tactic_effects(projected.tactics)
	return "%s: %s (유지)" % [label,after] if current==after else "%s: %s → %s" % [label,current,after]

func change_odds(id: String) -> void:
	var plan = game.draft_plan
	if game.change_plan(id):
		if not save():
			game.draft_plan = plan
			show_save_error()
			return
		show_phase()

func perform_roll() -> void:
	var before = game.checkpoint()
	if not game.roll():
		return
	if not save():
		game.restore(before)
		show_save_error()
		return
	show_phase(true)

func perform_redraw() -> void:
	var before = game.checkpoint()
	if game.redraw_reward():
		if not save():
			game.restore(before)
			show_save_error()
			return
		draft_resolution = ""
		show_phase()

func choose_draft_resolution(id: String) -> void:
	draft_resolution = id
	show_phase()

func focus_candidate(id: String) -> void:
	game.offer_for(id)
	save()
	show_phase()

func choose_perk(id: String) -> void:
	var before = game.checkpoint()
	var before_record = game.record.duplicate()
	var before_position = march_at
	if not game.advance(id,draft_resolution):
		return
	march_at = MountedMap.TRAILS[0][0]
	if not save():
		game.restore(before)
		game.record = before_record
		march_at = before_position
		show_save_error()
		return
	var candidate: String = before.draft_candidate
	if not candidate.is_empty():
		var face: int = before.draft_result.get_slice("면",0).to_int()
		var hero: String = Campaign.HEROES[candidate][0]
		var outcome = "%s 중복, 보급 전환 확정" % hero
		var color = PAPER
		if candidate not in before.heroes:
			outcome = "%s 합류 확정" % hero
			color = RECRUIT_GREEN
			play("recruit")
		elif game.promotion_level(candidate)>before.promotions.get(candidate,0):
			outcome = "%s 승급 확정 / %d단계" % [hero,game.promotion_level(candidate)]
			color = PROMOTION_BLUE
			play("promotion")
		if face==18:
			play("great_fortune")
		confirmed_draft = {"face":face,"text":outcome,"color":color}
	show_phase(not confirmed_draft.is_empty())

func result_view() -> void:
	words(screen_body,"한의 건국" if game.phase=="ending" else "행군 중단",35,GOLD)
	words(screen_body,game.last_result,17,PAPER)
	if game.phase=="ending":
		note_dialogue(screen_body,"ending")
	words(screen_body,"완료 전장 %d/4  ·  시드 %d  ·  %s" % [game.completed.size(),game.seed_value,"역사 행군" if game.mode=="history" else "가상 행군"],15,SUBTLE)
	var controls = row(screen_body)
	primary_button = action(controls,"새 행군 시작",back_to_title,true)
	action(controls,"행군 기록",show_archive)

func back_to_title() -> void:
	close_modal()
	game.clear_battle()
	game.phase = "title"
	game.chapter = 0
	game.completed.clear()
	introduction_open = not "opening" in game.record
	game.selected_route = -1
	checkpoint_data = {}
	save()
	show_phase()

func activate_modal() -> void:
	if not modal_active:
		resume_control = get_viewport().gui_get_focus_owner()
	modal_active = true
	hit_pending = false
	dodge_pending = false
	skill_pending = false
	empty(modal_content)
	modal.show()
	stage.hide()
	map_overlay.hide()

func close_modal() -> void:
	modal_active = false
	modal.hide()
	var on_map: bool = game.phase in ["map","travel"]
	stage.visible = not on_map
	map_overlay.visible = on_map
	if is_instance_valid(resume_control):
		defer_focus.call_deferred(resume_control)
	elif on_map and is_instance_valid(primary_button):
		defer_focus.call_deferred(map_choices[1] if game.phase=="map" and primary_button.disabled else primary_button)

func show_menu() -> void:
	activate_modal()
	words(modal_content,"일시정지" if game.phase=="battle" else "한왕의 길",28,GOLD)
	var first = action(modal_content,"돌아가기",close_modal,true)
	action(modal_content,"행군 기록",show_archive)
	action(modal_content,"움직임 줄이기  %s" % ("켜짐" if motion_reduced else "꺼짐"),toggle_motion)
	action(modal_content,"글자 크기  %d%%" % roundi(text_zoom*100),toggle_text)
	action(modal_content,"충돌음  %s" % ("녹음" if recorded_impacts else "합성"),toggle_impacts)
	if game.phase!="title":
		action(modal_content,"시작 화면으로",confirm_end)
	action(modal_content,"종료",get_tree().quit)
	defer_focus.call_deferred(first)

func confirm_end() -> void:
	activate_modal()
	words(modal_content,"이번 행군을 끝낼까요?",26,GOLD)
	words(modal_content,"이번 편성, 보급, 강화는 잃습니다. 행군 기록은 남습니다.",16,SUBTLE,true)
	var first = action(modal_content,"행군 계속",close_modal,true)
	action(modal_content,"행군 끝내고 시작 화면으로",back_to_title)
	defer_focus.call_deferred(first)

func show_archive() -> void:
	activate_modal()
	words(modal_content,"행군 기록",26,GOLD)
	var catalog = {"opening":"206년 제후 분봉과 한중","guanzhong":"관중과 삼진","pengcheng":"팽성 패전","xingyang":"형양과 성고","gaixia":"해하 전투","ending":"202년 즉위와 한 건국","lost":"행군 중단","fantasy":"가상 항우 합류","pengcheng_scout":"팽성, 척후병을 먼저 구조","pengcheng_supply":"팽성, 수송병을 먼저 구조"}
	if game.record.is_empty():
		words(modal_content,"아직 기록이 없습니다. 새 행군에서 첫 사건을 만나세요.",16,SUBTLE,true)
	else:
		for key in game.record:
			if catalog.has(key): words(modal_content,catalog[key],16,PAPER)
	var first = action(modal_content,"기록 닫기",close_modal,true)
	defer_focus.call_deferred(first)

func toggle_motion() -> void:
	motion_reduced = not motion_reduced
	landscape.reduce_motion = motion_reduced
	seal_view.reduced = motion_reduced
	if is_instance_valid(dice_view): dice_view.reduced = motion_reduced
	save()
	show_menu()

func toggle_text() -> void:
	text_zoom = 1.18 if text_zoom<1.1 else 1.0
	build_theme()
	show_phase()
	save()
	show_menu()

func toggle_impacts() -> void:
	recorded_impacts = not recorded_impacts
	save()
	show_menu()

func show_save_error() -> void:
	activate_modal()
	words(modal_content,"행군을 저장하지 못했습니다.",24,GOLD)
	words(modal_content,"저장 폴더의 쓰기 권한과 남은 공간을 확인한 뒤 다시 시도하세요.",16,PAPER,true)
	defer_focus.call_deferred(action(modal_content,"돌아가기",close_modal,true))

func save() -> bool:
	var cfg = ConfigFile.new()
	# Mid-battle saves update options and the chronicle, not the departure snapshot.
	var data = checkpoint_data if game.phase in ["title","battle"] and not checkpoint_data.is_empty() else game.checkpoint()
	cfg.set_value("chronicle","discovered",game.record)
	cfg.set_value("options","reduced_motion",motion_reduced)
	cfg.set_value("options","recorded_impacts",recorded_impacts)
	cfg.set_value("options","text_scale",text_zoom)
	if game.phase=="map":
		data["march_at"] = march_at
	cfg.set_value("checkpoint","state",data)
	var temporary = store_path+".tmp"
	var code = cfg.save(temporary)
	if code==OK:
		code = DirAccess.rename_absolute(temporary,store_path)
	if code!=OK:
		save_error = true
		return false
	checkpoint_data = data
	saved_count = game.record.size()
	save_error = false
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse_at = event.position
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and game.phase=="battle" and not modal_active:
			if Rect2(Vector2.ZERO,Campaign.WORLD).has_point(landscape.to_world(mouse_at)):
				hit_pending = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if modal_active:
				close_modal()
			else:
				show_menu()
		elif game.phase=="map" and not modal_active and event.physical_keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			get_viewport().set_input_as_handled()
		elif game.phase=="map" and not modal_active and event.physical_keycode==KEY_E:
			get_viewport().set_input_as_handled()
			if mounted_map.nearby>=0:
				choose_route(mounted_map.nearby)
		elif game.phase=="battle" and not modal_active:
			if event.physical_keycode in [KEY_SPACE,KEY_SHIFT]:
				dodge_pending = true
				get_viewport().set_input_as_handled()
			if event.physical_keycode==KEY_F:
				skill_pending = true
			if event.physical_keycode==KEY_R and not skill_pending:
				game.cycle_skill()
				get_viewport().set_input_as_handled()
			if event.physical_keycode==KEY_C:
				var allies = game.alive(game.team)
				if not allies.is_empty():
					var index = allies.find_custom(func(unit): return unit.uid==inspected_ally)
					inspected_ally = allies[(index+1)%allies.size()].uid
				get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not is_instance_valid(landscape):
		return
	if game.phase=="travel" and not modal_active:
		travel_time += dt
		var duration = 0.40 if travel_from>=1.0 else 1.10
		mounted_map.travel(game.selected_route,lerpf(travel_from,1.0,minf(1,travel_time/duration)),dt,motion_reduced)
		if travel_time>=duration:
			complete_travel()
	if game.phase!=announced_phase:
		show_phase()
		save()
	elif game.record.size()!=saved_count and not save_error:
		save()
	if game.phase=="battle":
		refresh_battle()
	landscape.queue_redraw()

func _physics_process(dt: float) -> void:
	if not is_instance_valid(landscape):
		return
	var focused = get_window().has_focus() or DisplayServer.get_name()=="headless"
	if game.phase=="map" and not modal_active and focused:
		var direction = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		refresh_map_prompt(mounted_map.ride(direction,dt,motion_reduced))
		march_at = mounted_map.point
		if marching and direction.is_zero_approx(): save()
		marching = not direction.is_zero_approx()
	if game.phase=="battle" and not modal_active and focused:
		combat_input(dt)
	else:
		hit_pending = false
		dodge_pending = false
		skill_pending = false

func combat_input(dt: float) -> void:
	var movement = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var aim = landscape.to_world(mouse_at)
	var mouse_attack = hit_pending or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Rect2(Vector2.ZERO,Campaign.WORLD).has_point(aim)
	var hold = Input.is_physical_key_pressed(KEY_E)
	var key_attack = Input.is_physical_key_pressed(KEY_J)
	if key_attack:
		var close = game.nearest(game.team[0].p,game.foes)
		if not close.is_empty(): aim = close.p
	game.step(movement,aim,mouse_attack or key_attack,dodge_pending,hold,skill_pending)
	landscape.pointer = mouse_at
	last_message_left = maxf(0,last_message_left-dt)
	if not game.events.is_empty():
		last_message = game.events.back()
		last_message_left = 2.0
		for event in game.events:
			if event in ["응급 처치","방패 엄호","약낭 돌파","왕의 신호","방패와 장창","굳건한 자세","숨 고르기","지원 사격","돌파 찌르기"]:
				game.queue_cue("support",2)
		game.events.clear()
	if not game.sound_cue.is_empty():
		play(game.sound_cue)
	hit_pending = false
	dodge_pending = false
	skill_pending = false

func build_sound() -> void:
	for i in AUDIO_SLOTS:
		var player = AudioStreamPlayer.new()
		player.volume_db = -18
		add_child(player)
		audio_players.append(player)
		audio_started.append(0)
	impacts = {
		"block":preload("res://assets/audio/impactMetal_heavy_000.ogg"),
		"sword_impact":preload("res://assets/audio/impactPlate_medium_000.ogg"),
		"axe_impact":preload("res://assets/audio/impactPunch_medium_000.ogg"),
		"bow_impact":preload("res://assets/audio/impactPlank_medium_000.ogg"),
		"spear_impact":preload("res://assets/audio/impactPlank_medium_000.ogg"),
	}
	for entry in [["dodge",190.0],["support",660.0],["impact",112.0],["whiff",78.0],["loose",305.0],
		["recruit",523.25],["promotion",783.99],["great_fortune",1318.51]]:
		var sound = AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = 22050
		var data = PackedByteArray()
		data.resize(4400)
		for i in range(2200):
			var wave = sin(TAU*entry[1]*i/22050.0)*(1.0-float(i)/2200)
			data.encode_s16(2*i,roundi(wave*9000))
		sound.data = data
		sounds[entry[0]] = sound

func play(which: String) -> void:
	if AudioServer.is_bus_mute(0): return
	var slot = audio_next
	for offset in AUDIO_SLOTS:
		var candidate = (audio_next+offset)%AUDIO_SLOTS
		if not audio_players[candidate].playing:
			slot = candidate
			break
		if audio_started[candidate]<audio_started[slot]:
			slot = candidate
	var player = audio_players[slot]
	player.stream = impacts[which] if recorded_impacts and impacts.has(which) else sounds.get(which,sounds["impact"])
	player.pitch_scale = CUE_PITCHES[audio_sequence%CUE_PITCHES.size()]
	player.play()
	audio_sequence += 1
	audio_started[slot] = audio_sequence
	audio_next = (slot+1)%AUDIO_SLOTS
