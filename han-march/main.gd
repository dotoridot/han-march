extends Control

const Campaign = preload("res://campaign.gd")
const Landscape = preload("res://landscape.gd")
const FONT = preload("res://assets/NotoSansKR.ttf")
const PAPER = Color("f4e6c8")
const SUBTLE = Color("c6b598")
const GOLD = Color("e3ad5e")
const NIGHT = Color("181310")
const PANEL = Color("2a201a")
const PRIMARY = Color("914420")
const IMMEDIATE = Color("facf8c")

var game = Campaign.new()
var body_font: FontVariation
var title_font: FontVariation
var landscape
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
var audio_player: AudioStreamPlayer
var sounds: Dictionary = {}
var hit_pending = false
var dodge_pending = false
var skill_pending = false
var mouse_at = Vector2(300,200)
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
	var margin = MarginContainer.new()
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
	screen_body = column(stage,8)
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
	if is_instance_valid(node) and node.is_visible_in_tree() and (not node is BaseButton or not node.disabled):
		node.grab_focus()

func note_dialogue(parent: Node, key: String) -> void:
	var label = words(parent,"",16,SUBTLE,true)
	var line_data = await manager.get_next_dialogue_line(text_data,key,[{"fantasy":game.mode=="fiction","has_xiang":"xiang" in game.hero_keys,
		"first_rescue":game.rescue_order.front() if not game.rescue_order.is_empty() else "",
		"approach":game.selected_route}])
	if line_data!=null and is_instance_valid(label):
		label.text = "%s  %s" % [line_data.character,line_data.text]

func show_phase() -> void:
	empty(screen_body)
	announced_phase = game.phase
	screen_body.size_flags_vertical = SIZE_FILL
	landscape.display = "battle" if game.phase=="battle" else ("travel" if game.phase=="travel" else "map")
	landscape.reduce_motion = motion_reduced
	landscape.text_zoom = text_zoom
	viewport_panel.visible = game.phase in ["title","map","travel","battle","ending","lost"]
	landscape.custom_minimum_size.y = 206 if game.phase=="battle" else 125
	primary_button = null
	match game.phase:
		"title":
			title_view()
		"map":
			map_view()
		"travel":
			words(screen_body,"%s으로 이동 중" % game.entry().name,22,GOLD)
			words(screen_body,"선택한 경유지  %s" % game.entry().routes[game.selected_route][0],15,SUBTLE)
			primary_button = action(screen_body,"전장으로",complete_travel,true)
		"battle":
			battle_view()
		"camp":
			camp_view()
		"ending","lost":
			result_view()
	landscape.queue_redraw()
	if primary_button!=null and not modal_active:
		defer_focus.call_deferred(primary_button)

func title_view() -> void:
	words(screen_body,"초한: 한왕의 길",41)
	words(screen_body,"기원전 206년부터 202년까지, 한중에서 즉위까지",17,GOLD)
	if introduction_open:
		note_dialogue(screen_body,"opening")
	var intro_action = "도입 접기" if introduction_open else "도입 다시 보기"
	action(screen_body,intro_action,toggle_intro)
	var controls = row(screen_body)
	primary_button = action(controls,"역사 행군 시작",start_historical,true)
	action(controls,"가상 행군 시작",start_fictional)
	run_seed = LineEdit.new()
	run_seed.placeholder_text = "시드 번호 · 비우면 무작위"
	run_seed.accessibility_name = "시드 번호"
	run_seed.max_length = 12
	run_seed.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.add_child(run_seed)
	words(screen_body,"매번 전장과 보상이 달라집니다. 패배하면 편성·보급·강화를 잃고 행군 기록을 남깁니다.",14,SUBTLE,true)
	if not checkpoint_data.is_empty() and checkpoint_data.get("phase") in ["map","travel","camp"]:
		action(controls,"이어하기",continue_run)

func toggle_intro() -> void:
	introduction_open = not introduction_open
	show_phase()

func continue_run() -> void:
	if game.restore(checkpoint_data):
		travel_time = 0.0
		show_phase()

func start_historical() -> void:
	start_run("history")

func start_fictional() -> void:
	start_run("fiction")

func start_run(mode: String) -> void:
	var value = run_seed.text.strip_edges() if is_instance_valid(run_seed) else ""
	if not value.is_empty() and not value.is_valid_int():
		run_seed.placeholder_text = "숫자로 입력하거나 모두 지우세요."
		run_seed.clear()
		run_seed.grab_focus()
		return
	game.new_run(value.to_int() if value.is_valid_int() else randi_range(100000,99999999),mode)
	show_phase()
	save()

func map_view() -> void:
	var data = game.entry()
	var headline = row(screen_body)
	words(headline,"%s  /  %s" % [data.year,data.name],23,GOLD)
	headline.add_spacer(false)
	words(headline,"보급 %d   ·   시드 %d" % [game.supply,game.seed_value],15,SUBTLE)
	note_dialogue(screen_body,data.id)
	var choices = row(screen_body)
	for i in data.routes.size():
		var path = data.routes[i]
		var choice = column(choices,4)
		choice.size_flags_horizontal = SIZE_EXPAND_FILL
		var b = action(choice,path[0],choose_route.bind(i),i==0)
		b.disabled = game.supply + path[3]<0
		if i==0: primary_button = b
		words(choice,"%s  /  %s" % [path[1],path[2]],14,SUBTLE)
		var forecast = game.preview_route(i)
		words(choice,"%s · 적 %d명%s" % [forecast.weather,forecast.opponents,"(추격대 별도)" if game.chapter==1 else ""],14,GOLD,true)
	words(screen_body,"경유지, 경로와 전장 과제는 창작입니다.",13,SUBTLE)

func choose_route(index: int) -> void:
	var before = game.checkpoint()
	if game.choose_route(index):
		if not save():
			game.restore(before)
			show_save_error()
			return
		travel_time = 0.0
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
	action_status = words(screen_body,"",15,PAPER)
	trail_status = words(screen_body,game.entry().description,14,SUBTLE)
	if game.chapter==3:
		note_dialogue(screen_body,"gaixia_route")
	field_status = words(screen_body,"",14,SUBTLE)
	words(screen_body,"WASD 이동   ·   마우스 / J 공격   ·   Space / Shift 회피   ·   E 길게   ·   F 강화 공격   ·   Esc 일시정지",14,SUBTLE)
	refresh_battle()

func refresh_battle() -> void:
	if not is_instance_valid(action_status):
		return
	var status = ["관문 주변의 적을 먼저 정리하세요.", "구출 %d/2  ·  추격대 %d/4" % [game.rescued,game.patrol], "수레 HP %d  ·  성고까지 %d%%" % [maxi(0,roundi(game.wagon_hp)),roundi((game.wagon.x-112)/444*100)], "방책 %d/2  ·  %s" % [game.gates,"적장 항우" if game.mode=="history" else "가상 지휘관"]][game.chapter]
	var evasion = "회피 준비" if game.dodge_cd<=0 else "회피 %.1f초" % game.dodge_cd
	action_status.text = "%s   /   %s   /   %s" % [status,evasion,game.tactic_name()]
	trail_status.text = "안전한 첫 예고: 좌우 방향과 함께 Space 또는 Shift로 피하세요." if game.training_ticks>0 else (last_message if last_message_left>0 else game.entry().description)
	field_status.text = scene_variant_text.get(game.field_rule,"") if game.scout_bonus.is_empty() else game.scout_bonus

func camp_view() -> void:
	words(screen_body,game.last_result,25,GOLD)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 305
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_body.size_flags_vertical = SIZE_EXPAND_FILL
	screen_body.add_child(scroll)
	var sheet = column(scroll,11)
	sheet.size_flags_horizontal = SIZE_EXPAND_FILL
	words(sheet,"야영지  /  보급 %d  /  %s" % [game.supply,game.tactic_name()],20)
	if game.chapter==1:
		note_dialogue(sheet,"rescued")
	words(sheet,"조정 전 비용과 18면 확률을 보세요. 강화를 고르면 등용 결과가 확정되고 다음 지도가 열립니다.",15,SUBTLE,true)
	var options = row(sheet)
	for option in [["balance","균형 · 무료"],["shield","방패 우대 · 보급 1"],["lance","장병기 우대 · 보급 1"]]:
		var id: String = option[0]
		var b = action(options,option[1]+(" ✓" if game.draft_plan==id else ""),change_odds.bind(id))
		b.disabled = game.draft_done or game.supply<=0 and id!="balance"
	var weights = game.draft_weights()
	var numbers: Array[String] = []
	for i in weights.size():
		numbers.append("%s %d/18 · %.1f%%" % [Campaign.HEROES[Campaign.DRAFT[i]][0],weights[i],float(weights[i])/18*100])
	words(sheet,"   /   ".join(numbers),14, GOLD,true)
	var rolls = row(sheet)
	primary_button = action(rolls,"18면 주사위 굴리기",perform_roll,true)
	primary_button.disabled = game.draft_done
	var again = action(rolls,"결과 바꾸기 · 보급 2",perform_redraw)
	again.disabled = not game.draft_done or game.rerolled or game.supply<2
	words(sheet,game.draft_result,16,PAPER)
	var choices = row(sheet)
	for id in game.hero_keys:
		var marks: Array = game.names_upgrades[id]
		var title: String = Campaign.HEROES[id][0] + " · " + Campaign.HEROES[id][2]
		var candidate = action(choices,title + (" ✓" if id==game.offered_to else ""),focus_candidate.bind(id))
		candidate.tooltip_text = "보유 특기 %d개" % marks.size()
	var active = game.names_upgrades[game.offered_to]
	var names: Array[String] = []
	for perk in Campaign.PLAN.perks:
		if perk.id in active: names.append(perk.name)
	words(sheet,"%s의 보유 특기  %s" % [Campaign.HEROES[game.offered_to][0],", ".join(names) if not names.is_empty() else "없음"],15,SUBTLE)
	for perk in game.offerings:
		var b = action(sheet,"%s  /  %s  /  %s" % [perk.name,perk.tag,perk.text],choose_perk.bind(perk.id))
		if game.draft_done and primary_button.disabled: primary_button = b
	if game.draft_done:
		words(sheet,"강화 선택 뒤 행군 지도로 돌아갑니다.",14,SUBTLE)
	else:
		words(sheet,"등용을 건너뛰려면 강화부터 고르세요.",14,SUBTLE)

func change_odds(id: String) -> void:
	if game.change_plan(id):
		save()
		show_phase()

func perform_roll() -> void:
	var before = game.checkpoint()
	if not game.roll():
		return
	if not save():
		game.restore(before)
		show_save_error()
		return
	show_phase()

func perform_redraw() -> void:
	var before = game.checkpoint()
	if game.redraw_reward():
		if not save():
			game.restore(before)
			show_save_error()
			return
		show_phase()

func focus_candidate(id: String) -> void:
	game.offer_for(id)
	save()
	show_phase()

func choose_perk(id: String) -> void:
	if game.advance(id):
		show_phase()
		save()

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

func close_modal() -> void:
	modal_active = false
	modal.hide()
	stage.show()
	if is_instance_valid(resume_control): defer_focus.call_deferred(resume_control)

func show_menu() -> void:
	activate_modal()
	words(modal_content,"일시정지" if game.phase=="battle" else "한왕의 길",28,GOLD)
	var first = action(modal_content,"돌아가기",close_modal,true)
	action(modal_content,"행군 기록",show_archive)
	action(modal_content,"움직임 줄이기  %s" % ("켜짐" if motion_reduced else "꺼짐"),toggle_motion)
	action(modal_content,"글자 크기  %d%%" % roundi(text_zoom*100),toggle_text)
	if game.phase!="title":
		action(modal_content,"시작 화면으로",confirm_end)
	action(modal_content,"종료",get_tree().quit)
	defer_focus.call_deferred(first)

func confirm_end() -> void:
	activate_modal()
	words(modal_content,"현재 행군을 끝낼까요?",26,GOLD)
	words(modal_content,"이번 편성, 보급, 강화는 초기화되고 행군 기록은 남습니다.",16,SUBTLE,true)
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
	save()
	show_menu()

func toggle_text() -> void:
	text_zoom = 1.18 if text_zoom<1.1 else 1.0
	build_theme()
	show_phase()
	save()
	show_menu()

func show_save_error() -> void:
	activate_modal()
	words(modal_content,"행군 기록을 저장할 수 없습니다.",24,GOLD)
	words(modal_content,"저장 폴더에 쓸 수 있는지 확인한 뒤 다시 시도하세요.",16,PAPER,true)
	defer_focus.call_deferred(action(modal_content,"돌아가기",close_modal,true))

func save() -> bool:
	var cfg = ConfigFile.new()
	# Mid-battle saves update options and the chronicle, not the departure snapshot.
	var data = checkpoint_data if game.phase in ["title","battle"] and not checkpoint_data.is_empty() else game.checkpoint()
	cfg.set_value("chronicle","discovered",game.record)
	cfg.set_value("options","reduced_motion",motion_reduced)
	cfg.set_value("options","text_scale",text_zoom)
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
		elif game.phase=="battle" and not modal_active:
			if event.physical_keycode in [KEY_SPACE,KEY_SHIFT]:
				dodge_pending = true
				get_viewport().set_input_as_handled()
			if event.physical_keycode==KEY_F:
				skill_pending = true

func _process(dt: float) -> void:
	if not is_instance_valid(landscape):
		return
	if game.phase=="travel" and not modal_active:
		travel_time += dt
		landscape.transfer = minf(1,travel_time/0.85)
		if travel_time>=0.85:
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
	if game.phase=="battle" and not modal_active and (get_window().has_focus() or DisplayServer.get_name()=="headless"):
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
			if event=="회피 성공":
				play("dodge")
			elif event in ["응급 처치","방패 엄호","약낭 돌파"]:
				play("support")
		game.events.clear()
	if game.traces.any(func(trace): return trace.kind=="damage" and trace.life>0.53):
		play("impact")
	hit_pending = false
	dodge_pending = false
	skill_pending = false

func build_sound() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -18
	add_child(audio_player)
	for entry in [["dodge",190.0],["support",660.0],["impact",112.0]]:
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
	audio_player.stream = sounds[which]
	audio_player.play()
