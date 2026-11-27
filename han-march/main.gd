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
var dismiss_map_detail: Callable
var skill_status: Label
var confirmed_draft: Dictionary = {}
var draft_resolution := ""
var march_at := Vector2(0,4.2)
var marching := false
var travel_from := 0.0
var stage: VBoxContainer
var camp_backdrop: TextureRect
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

	camp_backdrop = TextureRect.new()
	camp_backdrop.texture = preload("res://assets/night_camp.webp")
	camp_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camp_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	camp_backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	full(self,camp_backdrop)
	camp_backdrop.hide()

	var margin = MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(edge,18)
	full(self,margin)
	stage = column(margin,10)
	var bar = row(stage)
	bar.name = "StageHeader"
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
	var modal_stack = column(card,6)
	var scroller = ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(560,385)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_stack.add_child(scroller)
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

func note_dialogue(parent: Control, key: String, size_px := 16) -> void:
	var label = words(parent,"",size_px,SUBTLE,true)
	var line_data = await manager.get_next_dialogue_line(text_data,key,[{"fantasy":game.mode=="fiction","has_xiang":"xiang" in game.hero_keys,
		"first_rescue":game.rescue_order.front() if not game.rescue_order.is_empty() else "",
		"approach":game.selected_route}])
	if line_data==null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	if is_instance_valid(label):
		label.text = "%s  %s" % [line_data.character,line_data.text]

func show_phase(reveal_draft := false) -> void:
	var old_phase = announced_phase
	dismiss_map_detail = Callable()
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
	camp_backdrop.visible = game.phase=="camp"
	stage.get_node("StageHeader").visible = not camp_backdrop.visible
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
	var briefing = column(screen_body,4)
	var upper = row(briefing,8)
	upper.mouse_filter = MOUSE_FILTER_IGNORE
	briefing.mouse_filter = MOUSE_FILTER_IGNORE
	var notes = PanelContainer.new()
	notes.add_theme_stylebox_override("panel",skin(Color("283737ed"),6))
	notes.size_flags_vertical = SIZE_SHRINK_BEGIN
	upper.add_child(notes)
	var story = column(notes,1)
	story.size_flags_horizontal = SIZE_EXPAND_FILL
	var names: Array[String] = []
	for hero in game.hero_keys:
		names.append(Campaign.HEROES[hero][0])
	words(story,"유방의 군세 / %s" % "  ".join(names),14,PAPER,true)
	note_dialogue(story,data.id,14 if not confirmed_draft.is_empty() else 16)
	upper.add_spacer(false).mouse_filter = MOUSE_FILTER_IGNORE

	var badges: Array[Dictionary] = []
	if not confirmed_draft.is_empty():
		var roll = "18면 대길" if confirmed_draft.face==18 else "%d면" % confirmed_draft.face
		var short_roll = "대길" if confirmed_draft.face==18 else "등용"
		badges.append({"draft":true,"title":"%s %s" % [short_roll,confirmed_draft.get("kind","결과")],
			"detail":"등용 확정 / %s / %s" % [roll,confirmed_draft.text]})
	if not game.ration_hero.is_empty():
		badges.append({"title":"군량 순환","detail":"군령 / 군량 순환 / %s 최대 및 시작 MP +4, 첫 공격 또는 응급 처치 시 피로 최대 -10" %
			Campaign.HEROES[game.ration_hero][0]})
	var last_stand_routes: Array[String] = []
	if "last_stand" in orders:
		for path in data.routes:
			if game.supply+path[3]==0:
				last_stand_routes.append(path[0])
	var last_stand_effect = "배수진 / 공격 피해 +30%, 특기 대기 -25%"
	if not last_stand_routes.is_empty():
		badges.append({"title":"배수진","detail":"군령 / %s / %s" %
			[last_stand_effect,", ".join(last_stand_routes)]})

	notes.custom_minimum_size.x = 380 if badges.is_empty() else 310
	if not badges.is_empty():
		var status = column(upper,0)
		status.mouse_filter = MOUSE_FILTER_IGNORE
		status.size_flags_vertical = SIZE_SHRINK_BEGIN
		var controls = row(status,4)
		controls.mouse_filter = MOUSE_FILTER_IGNORE
		controls.alignment = BoxContainer.ALIGNMENT_END
		var preview_panel = PanelContainer.new()
		preview_panel.mouse_filter = MOUSE_FILTER_PASS
		preview_panel.add_theme_stylebox_override("panel",skin(Color("efe2c5"),6))
		status.add_child(preview_panel)
		var preview = words(preview_panel,"",14,Color("283737"),true)
		preview.mouse_filter = MOUSE_FILTER_IGNORE
		preview_panel.hide()
		var buttons: Array[Button] = []
		var dismissed: Array[Button] = []
		var modal_focus: Array[Button] = []
		var refresh_detail = func(prefer_hover: bool):
			if not is_instance_valid(preview) or not preview.is_inside_tree(): return
			var hovered := get_viewport().gui_get_hovered_control() if prefer_hover else null
			if hovered==preview_panel: return
			var current := hovered as Button
			if current not in buttons:
				current = get_viewport().gui_get_focus_owner() as Button
			preview_panel.visible = current in buttons and current not in dismissed
			if preview_panel.visible:
				preview.text = current.accessibility_description
		var dismiss_detail = func() -> bool:
			if not is_instance_valid(preview_panel) or not preview_panel.is_visible_in_tree(): return false
			for button in buttons:
				if preview.text==button.accessibility_description:
					dismissed.assign([button])
					var focused := get_viewport().gui_get_focus_owner() as Button
					if focused in buttons and focused!=button:
						dismissed.append(focused)
					preview_panel.hide()
					return true
			return false
		dismiss_map_detail = dismiss_detail
		var toggle_detail = func():
			var focused := get_viewport().gui_get_focus_owner() as Button
			if focused not in buttons: return
			if preview_panel.visible and preview.text==focused.accessibility_description:
				dismiss_detail.call()
			else:
				dismissed.erase(focused)
				refresh_detail.call(false)
		preview_panel.mouse_exited.connect(func(): refresh_detail.call_deferred(true))
		for badge in badges:
			var draft: bool = badge.get("draft",false)
			var button = action(controls,badge.title,toggle_detail)
			button.accessibility_name = badge.title if draft else "%s 군령" % badge.title
			button.accessibility_description = badge.detail
			button.add_theme_font_size_override("font_size",roundi(14*text_zoom))
			button.custom_minimum_size.y = 36
			button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			for state in [["normal","654039" if draft else "344748"],["hover","873d31"],["pressed","a13b2c"]]:
				var surface = skin(Color(state[1]),5)
				surface.content_margin_left = 33
				surface.content_margin_right = 8
				button.add_theme_stylebox_override(state[0],surface)
			if draft:
				dice_view = FeatureModel.new()
				dice_view.seal = false
				dice_view.reduced = motion_reduced
				button.add_child(dice_view)
				dice_view.position = Vector2(3,3)
				dice_view.size = Vector2(29,27)
				dice_view.mouse_filter = MOUSE_FILTER_IGNORE
				dice_view.set_face(confirmed_draft.face,reveal_draft,confirmed_draft.color)
			else:
				var icon = TextureRect.new()
				icon.texture = MountedMap.FLAG
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.mouse_filter = MOUSE_FILTER_IGNORE
				button.add_child(icon)
				icon.position = Vector2(4,4)
				icon.size = Vector2(26,28)
			buttons.append(button)
			button.mouse_entered.connect(func():
				dismissed.erase(button)
				refresh_detail.call_deferred(true))
			button.mouse_exited.connect(func(): refresh_detail.call_deferred(true))
			button.focus_entered.connect(func():
				if button not in modal_focus: dismissed.erase(button)
				modal_focus.clear()
				refresh_detail.call_deferred(false))
			button.focus_exited.connect(func():
				if modal_active: modal_focus.assign([button])
				refresh_detail.call_deferred(false))
		status.custom_minimum_size.x = maxf(300,controls.get_combined_minimum_size().x)

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
		var card_content = column(content,2)
		card_content.mouse_filter = MOUSE_FILTER_IGNORE
		var card = row(card_content,8)
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
		b.accessibility_name = title.text
		b.accessibility_description = "%s / %s" % [summary,path[1]]
		if path[0] in last_stand_routes:
			b.accessibility_description += " / "+last_stand_effect
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
	var fit = fit_map_routes.bind(briefing,choices)
	briefing.item_rect_changed.connect(fit.call_deferred)
	choices.item_rect_changed.connect(fit.call_deferred)
	fit.call_deferred()

func fit_map_routes(briefing: Control, choices: Control) -> void:
	if game.phase=="map" and is_instance_valid(briefing) and briefing.is_inside_tree() and choices.is_inside_tree():
		mounted_map.fit_routes(briefing.get_global_rect().end.y+54,choices.global_position.y)

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
		map_prompt.text = "WASD 또는 방향키로 이동 / 깃발 근처 E 출정 / 카드 이동 Tab, 확정 Enter / 마우스로 선택"
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
	screen_body.size_flags_vertical = SIZE_EXPAND_FILL
	var headline = row(screen_body,8)
	var heading = PanelContainer.new()
	heading.add_theme_stylebox_override("panel",skin(MAP_INK,9))
	headline.add_child(heading)
	words(heading,"야영지",25,PAPER)
	headline.add_spacer(false)
	var logistics = PanelContainer.new()
	logistics.add_theme_stylebox_override("panel",skin(MAP_INK,9))
	headline.add_child(logistics)
	words(logistics,"보급 %d" % game.supply,17,GOLD)
	map_button_skin(action(headline,"메뉴",show_menu))
	var scenery = Control.new()
	scenery.mouse_filter = MOUSE_FILTER_IGNORE
	screen_body.add_child(scenery)
	var next_chapter: int = game.chapter+1
	var next: Dictionary = Campaign.PLAN.chapters[next_chapter]
	var threat: String = {
		1:"추격병이 뒤늦게 합류",
		2:"수레 전진 시 매복병 출현",
		3:"방책 두 곳을 열어야 지휘관 공격 가능",
	}[next_chapter]
	var briefing = PanelContainer.new()
	briefing.add_theme_stylebox_override("panel",skin(MAP_INK,8))
	screen_body.add_child(briefing)
	var forecast = row(briefing,6)
	words(forecast,"다음 전장 / %s / %s" % [next.name,threat],17,PAPER,true)
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
	var scroll = ScrollContainer.new()
	scroll.name = "CampScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_body.add_child(scroll)
	var sheet = column(scroll,10)
	sheet.size_flags_horizontal = SIZE_EXPAND_FILL
	sheet.size_flags_vertical = SIZE_EXPAND_FILL
	var reward_notes = {}
	if not game.draft_candidate.is_empty():
		var id: String = game.draft_candidate
		var resolutions = ["promote","supply"] if id in game.hero_keys else [""]
		for resolution in resolutions:
			var projected: Dictionary = game.project_candidate(id,resolution)
			if projected.is_empty():
				continue
			var choice: String = {"promote":"승급","supply":"보급 전환","":"합류"}[resolution]
			if projected.supply_after==game.supply:
				continue
			var note = "%s 시 보급 %d → %d" % [choice,game.supply,projected.supply_after]
			if projected.refund>0:
				note += " / 황금 눈 +%d" % projected.refund
			reward_notes[resolution] = note
	var columns = GridContainer.new()
	columns.name = "CampColumns"
	columns.add_theme_constant_override("h_separation",10)
	columns.add_theme_constant_override("v_separation",10)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	sheet.add_child(columns)
	var sections: Array[VBoxContainer] = []
	for title in ["아군 진영","18면 등용","진법 미리보기"]:
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel",skin(Color("212830e8"),11))
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.size_flags_vertical = SIZE_SHRINK_BEGIN
		columns.add_child(panel)
		var section = column(panel,5)
		words(section,title,21,PAPER,true)
		sections.append(section)
	var roster = sections[0]
	var die_column = sections[1]
	var tactics = sections[2]
	var current: String = game.tactic_effects(game.tactics)
	words(tactics,"현재 진법: "+game.tactic_name(),15,GOLD,true)
	var orders = Campaign.PLAN.perks.filter(func(perk):
		return perk.tag=="군령" and perk.id in game.names_upgrades["liu"])
	var choices = GridContainer.new()
	choices.add_theme_constant_override("v_separation",4)
	roster.add_child(choices)
	var figure = Landscape.Figure
	for id in game.hero_keys:
		var level = " / 승급 %d/%d" % [game.promotion_level(id),Campaign.PROMOTION_CAP] if Campaign.PROMOTION.has(id) else ""
		var title: String = "%s / %s%s" % [Campaign.HEROES[id][0],Campaign.HEROES[id][2],level]
		var candidate = action(choices,title+(" ✓" if id==game.offered_to else ""),focus_candidate.bind(id))
		map_button_skin(candidate)
		if id==game.offered_to:
			candidate.accessibility_name += " 선택됨"
		candidate.size_flags_horizontal = SIZE_EXPAND_FILL
		candidate.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var head = figure.TYPES.find(id)*figure.BODY_PARTS+3
		var portrait = AtlasTexture.new()
		portrait.atlas = figure.PIGMENTS
		portrait.region = Rect2(Vector2(head%12,floori(head/12.0))*figure.CELL,Vector2.ONE*figure.CELL).grow(-65)
		candidate.icon = portrait
		candidate.add_theme_constant_override("icon_max_width",34)
		candidate.add_theme_font_override("font",title_font)
		candidate.add_theme_stylebox_override("normal",skin(Color("70342b" if id==game.offered_to else "262320ed"),6))
	var active = game.names_upgrades[game.offered_to]
	var names: Array[String] = []
	for perk in Campaign.PLAN.perks:
		if perk.tag!="군령" and perk.id in active: names.append(perk.name)
	words(roster,"%s의 강화 %s" % [Campaign.HEROES[game.offered_to][0],", ".join(names) if not names.is_empty() else "없음"],14,MAP_SECONDARY,true)
	var role_skill: String = {"fan":"shield","xiao":"heal","han":"cover","xiang":"pierce","cao":"pierce"}.get(game.offered_to,"command")
	var sheet_skills: Array = game.player_skills() if game.offered_to=="liu" else [role_skill]
	for skill in sheet_skills:
		var info: Array = Campaign.SKILL_INFO[skill]
		var price: Array = Campaign.ABILITIES[skill]
		words(roster,"%s / %s / MP %d, 재사용 %.1f초" % [info[0],info[1],price[0],price[1]],14,MAP_SECONDARY,true)
	dice_view = FeatureModel.new()
	dice_view.seal = false
	dice_view.reduced = motion_reduced
	dice_view.custom_minimum_size = Vector2(0,110)
	die_column.add_child(dice_view)
	var number = game.draft_result.get_slice("면",0).to_int() if not game.draft_candidate.is_empty() else 0
	dice_view.set_face(number,reveal_draft)
	var face_label = words(die_column,"눈 %d / 18" % number if number>0 else "",15,GOLD)
	face_label.visible = number>0
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if number==18:
		face_label.text += " / 18면 대길"
	var pending := ""
	var pending_result = words(die_column,"",16,GOLD,true)
	pending_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not game.draft_done:
		if game.first_free_recruit():
			words(die_column,"첫 야영지의 균형 굴림은 미보유 장수가 나옵니다.",14,GOLD,true)
		words(die_column,"우대를 골라 굴리면 보급 1을 씁니다.",14,MAP_SECONDARY,true)
		var options = flow(die_column,4)
		for option in [["balance","균형 / 무료"],["shield","방패 우대"],["lance","장병기 우대"]]:
			var id: String = option[0]
			var b = action(options,option[1]+(" ✓" if game.draft_plan==id else ""),change_odds.bind(id))
			b.disabled = game.supply<=0 and id!="balance"
			map_button_skin(b)
			if id!="balance": b.accessibility_description = "굴리면 보급 1을 씁니다."
			if game.draft_plan==id: b.add_theme_stylebox_override("normal",skin(Color("70342b"),11))
		var weights = game.draft_weights()
		var faces: int = 0
		for weight in weights:
			faces += weight
		primary_button = action(die_column,"18면 주사위 굴리기",perform_roll,true)
		primary_button.add_theme_stylebox_override("normal",skin(Color("8b3226"),9))
		primary_button.add_theme_stylebox_override("hover",skin(Color("a24030"),9))
		words(tactics,"등용 후보",15,PAPER,true)
		var candidates = flow(tactics,5)
		var changes: Array[String] = []
		for i in weights.size():
			if weights[i]==0:
				continue
			var id: String = Campaign.DRAFT[i]
			var detail := ""
			if id not in game.hero_keys:
				detail = draft_tactic_line(id,"","합류",true)
			elif game.promotion_level(id)<Campaign.PROMOTION_CAP:
				detail = draft_tactic_line(id,"promote","승급",true)
			var odds = "%s %d/%d" % [Campaign.HEROES[id][0],weights[i],faces]
			var badge = PanelContainer.new()
			badge.add_theme_stylebox_override("panel",skin(Color("273743"),6))
			candidates.add_child(badge)
			words(badge,odds,15,PAPER)
			if not detail.is_empty():
				changes.append("%s %s" % [Campaign.HEROES[id][0],detail])
		for change in changes:
			words(tactics,change,14,MAP_SECONDARY,true)
	else:
		var id: String = game.draft_candidate
		if id.is_empty():
			words(die_column,"저장된 굴림의 등용 후보를 확인할 수 없습니다.",16,SUBTLE,true)
		elif id in game.hero_keys:
			var level: int = game.promotion_level(id)
			var gain: int = game.project_candidate(id,"supply").gain
			var capped = level>=Campaign.PROMOTION_CAP
			words(die_column,"%s 중복 / 현재 승급 %d/%d" % [Campaign.HEROES[id][0],level,Campaign.PROMOTION_CAP],16,GOLD,true)
			if draft_resolution=="promote":
				pending = "%s 승급 예정 / %d단계" % [Campaign.HEROES[id][0],level+1]
			elif draft_resolution=="supply":
				pending = "보급 +%d 전환 예정" % gain
			if draft_resolution.is_empty():
				if not capped:
					var advance = draft_tactic_line(id,"promote","승급")
					if not advance.is_empty(): words(tactics,advance,15,GOLD,true)
				for note in reward_notes.values(): words(die_column,note,14,GOLD,true)
			var rewards = flow(die_column,4)
			var promote_label = "승급 상한 도달" if capped else "승급 %d → %d%s" % [level,level+1," ✓" if draft_resolution=="promote" else ""]
			var promote = action(rewards,promote_label,choose_draft_resolution.bind("promote"))
			promote.disabled = capped
			var stores = action(rewards,"보급 +%d%s" % [gain," ✓" if draft_resolution=="supply" else ""],
				choose_draft_resolution.bind("supply"))
			map_button_skin(promote)
			map_button_skin(stores)
			promote.accessibility_description = reward_notes.get("promote","")
			stores.accessibility_description = reward_notes.get("supply","")
			if draft_resolution.is_empty(): primary_button = stores if promote.disabled else promote

		else:
			pending = "%s 합류 예정" % Campaign.HEROES[id][0]
			if reward_notes.has(""): words(die_column,reward_notes[""],14,GOLD,true)
			var arrival = draft_tactic_line(id,"","합류")
			if not arrival.is_empty(): words(tactics,arrival,15,GOLD,true)
		var again = action(die_column,"후보 버리고 다시 굴리기 / 보급 2",perform_redraw)
		again.disabled = game.rerolled or game.supply<2
		map_button_skin(again)
		if game.golden_refund():
			words(die_column,"후보를 버리면 이 눈의 환급도 사라집니다.",14,MAP_SECONDARY,true)
	pending_result.text = pending
	pending_result.visible = not pending.is_empty()
	if draft_resolution=="promote": pending_result.add_theme_color_override("font_color",PROMOTION_BLUE)
	var needs_resolution = game.draft_candidate in game.hero_keys and draft_resolution.is_empty()
	var more = action(tactics,"진법 규칙과 적용 중인 군령",func():
		var detail_size = Vector2(minf(710,size.x-76),minf(437,size.y-169))
		activate_modal(detail_size)
		var scroller: ScrollContainer = modal_content.get_parent()
		var stack = scroller.get_parent()
		var header = row(stack)
		stack.move_child(header,0)
		words(header,"진법과 군령",24,GOLD)
		header.add_spacer(false)
		var back = action(header,"닫기",close_modal)
		map_button_skin(back)
		stack.get_parent().add_theme_stylebox_override("panel",skin(Color("20252cf7"),14))
		scroller.scroll_vertical = 0
		var tabs = row(stack,6)
		stack.move_child(tabs,1)
		var offered_orders = game.offerings.filter(func(perk): return perk.tag=="군령" and perk not in orders)
		var show_details = func(tab_index: int):
			for tab in tabs.get_children():
				var selected: bool = tab.get_index()==tab_index
				tab.text = tab.accessibility_name+(" ✓" if selected else "")
				tab.accessibility_description = "선택됨" if selected else ""
				map_button_skin(tab)
				if selected: tab.add_theme_stylebox_override("normal",skin(Color("5a3631"),9))
			empty(modal_content)
			scroller.set_deferred("scroll_vertical",0)
			if tab_index==0:
				for order in orders+offered_orders:
					var panel = PanelContainer.new()
					panel.add_theme_stylebox_override("panel",skin(Color("303640"),8))
					modal_content.add_child(panel)
					var item = column(panel,2)
					var state = "선택 가능"
					if order in orders:
						state = "적용 중"
					elif needs_resolution:
						state = "등용 보상 선택 필요"
					words(item,"⚑  "+order.name+" / "+state,16,Color("ffb09c"))
					var limits: String = {
						"ambush_counter":"회피마다 1회 / 1초 안",
						"golden_eye":"야영지 1회 / 최대 %d" % Campaign.SUPPLY_CAP,
						"ration_cycle":"전투마다 장수 1명 / 1회",
						"last_stand":"출정 후 보급 0 / 이번 전투",
					}.get(order.id,"")
					var effect: String = order.text
					if order.id in ["golden_eye","ration_cycle"]:
						effect = effect.get_slice(". ",0)+"."
					words(item,effect,14,PAPER,true)
					words(item,limits,13,MAP_SECONDARY,true)
				if orders.is_empty() and offered_orders.is_empty():
					words(modal_content,"획득하거나 선택할 수 있는 군령이 없습니다.",15,MAP_SECONDARY,true)
				else:
					words(modal_content,"군령은 종류마다 한 번 획득할 수 있습니다.",13,MAP_SECONDARY,true)
			elif tab_index==1:
				words(modal_content,"주 진법과 보조 진법은 각각 위에서부터 하나씩 적용됩니다.",14,MAP_SECONDARY,true)
				for rule in [
					["shield_cover",["han","fan"],"주 진법 / 한신과 번쾌",{}],
					["medicine_advance",["xiao","cao"],"주 진법 / 소하와 조참 또는 항우",{}],
					["royal_signal",["liu","han"],"보조 진법 / 유방과 한신 1단계 이상",{"han":1}],
					["shield_spear",["fan","cao"],"보조 진법 / 번쾌와 조참",{}],
				]:
					var rule_id: String = rule[0]
					var tactic: Array = Campaign.TACTICS[rule_id]
					var panel = PanelContainer.new()
					panel.add_theme_stylebox_override("panel",skin(Color("303640"),6))
					modal_content.add_child(panel)
					var item = column(panel,1)
					var label: String = tactic[0]+" / "+rule[2]
					var effect: String = tactic[1]
					var is_current: bool = rule_id in [game.tactics.lead,game.tactics.support]
					var upcoming: bool = not projected_draft.is_empty() and rule_id in [projected_draft.tactics.lead,projected_draft.tactics.support]
					if is_current: label += " / 적용 중"
					if upcoming and not is_current: label += " / 적용 예정"
					if rule[2].begins_with("보조"):
						var base: Dictionary = game.resolve_tactics(rule[1],rule[3])
						effect = "기본 "+(effect % base.bonus)
						if is_current: effect += " / 현재 +%d%%" % game.tactics.bonus
						if upcoming and (not is_current or projected_draft.tactics.bonus!=game.tactics.bonus):
							effect += " / 예정 +%d%%" % projected_draft.tactics.bonus
					words(item,label,15,GOLD,true)
					words(item,effect,14,PAPER,true)
				words(modal_content,"조참과 한신은 후속 승급마다 해당 피해 +10%p.",13,MAP_SECONDARY,true)
			else:
				if Campaign.PROMOTION.has(game.draft_candidate):
					words(modal_content,"승급 단계마다 "+Campaign.PROMOTION[game.draft_candidate][0],14,MAP_SECONDARY,true)
				words(modal_content,"◇  등용과 보급",17,GOLD)
				words(modal_content,"우대 보급 1 / 다시 굴리기 보급 2, 야영지 1회 / 중복 전환 최대 +%d / 승급 최대 %d단계 / 보급 최대 %d" % [Campaign.DUPLICATE_SUPPLY,Campaign.PROMOTION_CAP,Campaign.SUPPLY_CAP],14,PAPER,true)
				words(modal_content,"경유지 선택 전 / %s" % ", ".join(route_notes),14,MAP_SECONDARY,true)
		action(tabs,"군령",show_details.bind(0))
		action(tabs,"진법",show_details.bind(1)).name = "CampTactics"
		action(tabs,"등용과 보급",show_details.bind(2)).name = "CampRules"
		show_details.call(1 if orders.is_empty() and offered_orders.is_empty() else 0)
		defer_focus.call_deferred(back))
	map_button_skin(more)
	if game.chapter==1:
		note_dialogue(roster,"rescued",14)
	var card_strip = PanelContainer.new()
	card_strip.add_theme_stylebox_override("panel",skin(Color("212830e8"),7))
	sheet.add_child(card_strip)
	var card_heading = column(card_strip,3)
	if game.draft_done:
		var instruction = "승급 또는 보급 전환을 먼저 고르세요." if needs_resolution else "선택하면 등용 보상을 확정하고 출발합니다."
		words(card_heading,"강화와 군령 / "+instruction,16,PAPER,true)
		if draft_resolution=="promote":
			var delta = draft_tactic_line(game.draft_candidate,"promote","진법 변화")
			if not delta.is_empty(): words(tactics,delta,15,GOLD,true)
			if "ration_cycle" in game.names_upgrades["liu"]:
				words(tactics,"군량 순환 적용 예정",14,MAP_SECONDARY,true)
	else:
		words(card_heading,"강화와 군령 / 등용을 건너뛰려면 바로 고르세요.",16,PAPER,true)
	var confirmation = words(card_heading,pending,16,PROMOTION_BLUE if draft_resolution=="promote" else GOLD,true)
	if reward_notes.has(draft_resolution) and not draft_resolution.is_empty():
		words(card_heading,reward_notes[draft_resolution],14,GOLD,true)
	var cards = GridContainer.new()
	cards.name = "CampCards"
	cards.add_theme_constant_override("h_separation",10)
	cards.add_theme_constant_override("v_separation",8)
	sheet.add_child(cards)
	for perk in game.offerings:
		var b = action(cards,"",choose_perk.bind(perk.id))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.disabled = needs_resolution
		map_button_skin(b)
		var content = MarginContainer.new()
		content.mouse_filter = MOUSE_FILTER_IGNORE
		for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
			content.add_theme_constant_override(edge,10)
		full(b,content)
		var card_row = row(content,11)
		card_row.mouse_filter = MOUSE_FILTER_IGNORE
		var marker: String = {"군령":"⚑","방패":"◆","지원":"✚","전위":"▲","기동":"➜"}.get(perk.tag,"◇")
		var tag_color = Color("ffb09c") if perk.tag=="군령" else GOLD
		var emblem = PanelContainer.new()
		emblem.mouse_filter = MOUSE_FILTER_IGNORE
		emblem.size_flags_vertical = SIZE_SHRINK_BEGIN
		emblem.add_theme_stylebox_override("panel",skin(Color("552f2c" if perk.tag=="군령" else "393232"),9))
		card_row.add_child(emblem)
		words(emblem,marker,23,tag_color).mouse_filter = MOUSE_FILTER_IGNORE
		var copy = column(card_row,4)
		copy.size_flags_horizontal = SIZE_EXPAND_FILL
		copy.mouse_filter = MOUSE_FILTER_IGNORE
		words(copy,perk.tag,14,tag_color)
		words(copy,perk.name,20,PAPER,true)
		words(copy,perk.text,14,MAP_SECONDARY,true)
		b.accessibility_name = "%s / %s" % [perk.name,perk.tag]
		b.accessibility_description = "%s / %s" % [reward_notes[draft_resolution],perk.text] if reward_notes.has(draft_resolution) else perk.text
		content.minimum_size_changed.connect(func(): b.custom_minimum_size = content.get_combined_minimum_size().max(Vector2(0,120)))
		b.custom_minimum_size = content.get_combined_minimum_size().max(Vector2(0,120))
		if primary_button==null and not needs_resolution: primary_button = b
	var roster_jump = action(forecast,"장수",func(): choices.get_child(0).grab_focus())
	var cards_jump = action(forecast,"강화",func():
		var first: Button = cards.get_child(0)
		if first.disabled:
			scroll.scroll_vertical = roundi(card_strip.position.y)
		else:
			first.grab_focus())
	for jump in [roster_jump,cards_jump]:
		map_button_skin(jump)
	var reflow = func():
		var count = 3 if scroll.size.x>=1000.0 else 1
		roster_jump.visible = count==1
		cards_jump.visible = count==1
		columns.columns = count
		if count==3:
			var available = scroll.size.y+scenery.custom_minimum_size.y
			scenery.custom_minimum_size.y = clampf(available-sheet.get_combined_minimum_size().y-2,0,128)
		else:
			scenery.custom_minimum_size.y = 18
		var die_panel = die_column.get_parent()
		var roster_panel = roster.get_parent()
		if count==3:
			columns.move_child(roster_panel,0)
			columns.move_child(die_panel,1)
		else:
			columns.move_child(die_panel,0)
			columns.move_child(roster_panel,2)
		cards.columns = count
		choices.columns = 1 if count==3 else 2
		confirmation.visible = count==1 and not pending.is_empty()
	scroll.resized.connect(reflow)
	sheet.minimum_size_changed.connect(reflow,CONNECT_DEFERRED)
	reflow.call()

func draft_tactic_line(id: String, resolution: String, label: String, names_only := false) -> String:
	var projected: Dictionary = game.project_candidate(id,resolution)
	var tactics: Dictionary = projected.tactics
	var changes: Array[String] = []
	if tactics.lead!=game.tactics.lead:
		var lead: Array = Campaign.TACTICS.get(tactics.lead,["기본 대열",""])
		changes.append(lead[0] if names_only or lead[1].is_empty() else "%s (%s)" % [lead[0],lead[1]])
	if tactics.support!=game.tactics.support:
		var support: Array = Campaign.TACTICS.get(tactics.support,["보조 진법 해제",""])
		changes.append(support[0] if names_only or support[1].is_empty() else "%s (%s)" % [support[0],support[1] % tactics.bonus])
	elif tactics.bonus!=game.tactics.bonus:
		var effect: Array = Campaign.TACTICS[tactics.support]
		var bonus = "+%d%% → +%d%%" % [game.tactics.bonus,tactics.bonus]
		changes.append(effect[0]+" "+bonus if names_only else (effect[1] % game.tactics.bonus).get_slice(" +",0)+" "+bonus)
	return "" if changes.is_empty() else "%s: %s" % [label," / ".join(changes)]

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
		var kind = "환전"
		var color = PAPER
		if candidate not in before.heroes:
			outcome = "%s 합류 확정" % hero
			kind = "합류"
			color = RECRUIT_GREEN
			play("recruit")
		elif game.promotion_level(candidate)>before.promotions.get(candidate,0):
			outcome = "%s 승급 확정 / %d단계" % [hero,game.promotion_level(candidate)]
			kind = "승급"
			color = PROMOTION_BLUE
			play("promotion")
		if face==18:
			play("great_fortune")
		confirmed_draft = {"face":face,"kind":kind,"text":outcome,"color":color}
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

func activate_modal(content_size := Vector2(560,385)) -> void:
	if not modal_active:
		resume_control = get_viewport().gui_get_focus_owner()
	modal_active = true
	hit_pending = false
	dodge_pending = false
	skill_pending = false
	empty(modal_content)
	var scroller: ScrollContainer = modal_content.get_parent()
	scroller.custom_minimum_size = content_size
	var stack = scroller.get_parent()
	for child in stack.get_children():
		if child!=scroller:
			stack.remove_child(child)
			child.queue_free()
	stack.get_parent().add_theme_stylebox_override("panel",skin(PANEL,17))
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
	elif game.phase=="camp" and is_instance_valid(primary_button):
		defer_focus.call_deferred(primary_button)

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
		if modal_active and game.phase=="camp" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			var scroller: ScrollContainer = modal_content.get_parent()
			var stack = scroller.get_parent()
			if stack.get_child_count()>1 and not stack.get_parent().get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
				if event.pressed:
					close_modal()
				return
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and game.phase=="battle" and not modal_active:
			if Rect2(Vector2.ZERO,Campaign.WORLD).has_point(landscape.to_world(mouse_at)):
				hit_pending = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if modal_active:
				close_modal()
			elif not (game.phase=="map" and dismiss_map_detail.is_valid() and dismiss_map_detail.call()):
				show_menu()
		elif game.phase=="camp" and (event.physical_keycode in [KEY_PAGEUP,KEY_PAGEDOWN] or
				(modal_active and modal_content.get_parent().get_parent().get_child_count()>1 and event.physical_keycode in [KEY_UP,KEY_DOWN])):
			var scroll: ScrollContainer = modal_content.get_parent() if modal_active else screen_body.get_node("CampScroll")
			if scroll.get_v_scroll_bar().visible:
				var step = 40 if event.physical_keycode in [KEY_UP,KEY_DOWN] else roundi(scroll.size.y*0.8)
				scroll.scroll_vertical += step if event.physical_keycode in [KEY_PAGEDOWN,KEY_DOWN] else -step
				get_viewport().set_input_as_handled()
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
