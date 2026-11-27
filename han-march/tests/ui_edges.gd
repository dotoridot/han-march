extends SceneTree

const Campaign = preload("res://campaign.gd")
const Scene = preload("res://main.tscn")
const Pilot = preload("res://tests/pilot.gd")
var ui
var directory: String
var status = 0

func _initialize() -> void:
	call_deferred("verify")

func snap(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()=="headless":
		await process_frame
		return
	await RenderingServer.frame_post_draw
	if directory:
		root.get_texture().get_image().save_png(directory.path_join(name+".png"))

func camp_labels(container: Control = null) -> String:
	var lines: Array[String] = []
	for label in (ui.screen_body if container==null else container).find_children("*","Label",true,false):
		lines.append(label.text)
	return "\n".join(lines)

func map_badge(name: String) -> Button:
	for button in ui.screen_body.find_children("*","Button",true,false):
		if button.accessibility_name==name:
			return button
	return null

func check_map_badge(name: String, detail: String) -> void:
	var badge = map_badge(name)
	if badge==null or not root.get_visible_rect().encloses(badge.get_global_rect()) or detail not in badge.accessibility_description:
		push_error("The map badge must identify the confirmed result or order: %s" % name)
		status = 1
		return
	for label in ui.screen_body.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and detail in label.text:
			push_error("Map details should start collapsed: %s" % name)
			status = 1
	var tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	for step in 8:
		if badge.has_focus(): break
		tab.pressed = true
		root.push_input(tab)
		tab = tab.duplicate()
		tab.pressed = false
		root.push_input(tab)
		tab = tab.duplicate()
		await process_frame
	if not badge.has_focus():
		push_error("Tab must reach the map badge: %s" % name)
		status = 1
		return
	await snap("map-badge-"+name)
	for label in ui.screen_body.find_children("*","Label",true,false):
		if label.text==badge.accessibility_description and label.is_visible_in_tree() and root.get_visible_rect().encloses(label.get_global_rect()) and label.get_visible_line_count()==label.get_line_count():
			confirm_with_enter()
			await process_frame
			if label.is_visible_in_tree() or not badge.has_focus():
				push_error("Enter must close the map detail without moving focus: %s" % name)
				status = 1
			return
	push_error("Focusing the map badge must show its full detail: %s" % name)
	status = 1

func check_camp_layout() -> void:
	var sections = ui.screen_body.find_child("CampColumns",true,false)
	var cards = ui.screen_body.find_child("CampCards",true,false)
	var scroll = ui.screen_body.find_child("CampScroll",true,false)
	if sections==null or cards==null or scroll==null:
		push_error("Camp must group the forecast, three sections and offered cards")
		status = 1
		return
	var wide = root.size.x==1280
	var expected_columns = 3 if wide else 1
	var frame: Rect2 = scroll.get_global_rect()
	var checks = sections.get_child_count()==3 and sections.columns==expected_columns and cards.columns==expected_columns
	checks = checks and cards.get_child_count()==ui.game.offerings.size()
	if wide:
		var forecast: Array[String] = []
		for label in ui.screen_body.find_children("*","Label",true,false):
			var bounds: Rect2 = label.get_global_rect()
			if root.get_visible_rect().encloses(bounds) and (not scroll.is_ancestor_of(label) or frame.encloses(bounds)):
				forecast.append(label.text)
		checks = checks and forecast.any(func(copy): return copy.begins_with("다음 전장 / "))
		checks = checks and forecast.has("보급 %d" % ui.game.supply)
		checks = checks and scroll.scroll_vertical==0 and not scroll.get_v_scroll_bar().visible
		checks = checks and frame.encloses(sections.get_global_rect()) and frame.encloses(cards.get_global_rect())
	for i in cards.get_child_count():
		var button: Button = cards.get_child(i)
		var perk: Dictionary = ui.game.offerings[i]
		var effect: Label = button.find_children("*","Label",true,false).back()
		checks = checks and effect.text==perk.text and perk.text in button.accessibility_description
		checks = checks and button.get_global_rect().encloses(effect.get_global_rect()) and effect.get_visible_line_count()==effect.get_line_count()
		if i>0:
			var first: Button = cards.get_child(0)
			checks = checks and (button.position.y==first.position.y if wide else button.position.y>first.position.y)
	if not checks:
		push_error("Camp layout clips at %s: scroll %s, bar %s, sections %s, cards %s" % [root.size,frame,scroll.get_v_scroll_bar().visible,sections.get_global_rect(),cards.get_global_rect()])
		status = 1

func camp_edges() -> void:
	ui.text_zoom = 1.18
	ui.build_theme()
	ui.complete_travel()
	Pilot.pilot(ui.game,5000)
	if ui.game.phase!="camp":
		push_error("Narrow-window run did not reach the first camp")
		status = 1
		return
	var before: Dictionary = ui.game.checkpoint()
	ui.show_phase()
	if ui.game.checkpoint()!=before:
		push_error("First camp forecast changed checkpoint or RNG state")
		status = 1
	ui.show_phase()
	await snap("narrow-first-camp")
	check_camp_layout()
	var table = camp_labels()
	if "다음 전장 / 팽성 / 추격병" not in table or "Page Up" in table or "한왕의 길" in table:
		push_error("Camp should show a concise battlefield forecast")
		status = 1
	if ui.game.checkpoint()!=before:
		push_error("Camp forecast changed checkpoint or RNG state")
		status = 1
	if "조참 8/18" not in table or "조참 합류: 약낭 돌파" not in table or " 0/18" in table:
		push_error("Odds should show eligible faces and a concise change in tactics")
		status = 1
	var roll: Button = ui.primary_button
	if not root.get_visible_rect().encloses(roll.get_global_rect()) or not roll.has_focus() or roll.accessibility_name!=roll.text:
		push_error("Free roll is not visible and focused at 760x544")
		status = 1
	var scroll: ScrollContainer = ui.screen_body.find_child("CampScroll",true,false)
	if scroll!=null:
		var previous = scroll.scroll_vertical
		if previous!=0 or not scroll.get_global_rect().encloses(ui.dice_view.get_global_rect()):
			push_error("The entire die must be visible with the initial keyboard focus")
			status = 1
		var page = InputEventKey.new()
		page.physical_keycode = KEY_PAGEDOWN
		page.pressed = true
		root.push_input(page)
		await process_frame
		if scroll.scroll_vertical<=previous:
			push_error("Page Down must scroll the narrow camp without a pointer")
			status = 1
		scroll.scroll_vertical = previous
	var key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	await snap("narrow-first-recruit")
	check_camp_layout()
	if "합류 예정" not in camp_labels() or "합류 확정" in camp_labels():
		push_error("The rolled recruit must remain pending")
		status = 1
	if ui.game.draft_candidate not in ["han","cao"] or ui.game.supply!=before.supply:
		status = 1
	var recruit: String = ui.game.draft_candidate
	ui.motion_reduced = true
	ui.continue_run()
	await snap("narrow-reopened-roll")
	var settled: float = ui.dice_view.get("reveal_elapsed")
	if settled<.74 or "합류 예정" not in camp_labels():
		push_error("Restoring a saved roll should show the pending result without motion")
		status = 1
	ui.choose_perk(ui.game.offerings[0].id)
	await snap("narrow-recruit-confirmed")
	var recruit_name = "대길 합류" if ui.confirmed_draft.get("face",0)==18 else "등용 합류"
	await check_map_badge(recruit_name,Campaign.HEROES[recruit][0]+" 합류 확정")
	if recruit not in ui.game.hero_keys or ui.audio_sequence!=0:
		push_error("The saved recruit must be announced on the map")
		status = 1
	ui.continue_run()
	await process_frame
	if map_badge(recruit_name)!=null or ui.audio_sequence!=0:
		push_error("Reloading a map checkpoint must not replay the confirmed result")
		status = 1
	# The imported pending result exercises a duplicate even if the normal roll is a recruit.
	before.heroes.append_array(["han","cao"])
	before.perks["han"] = []
	before.perks["cao"] = []
	before["rolled"] = true
	before["draft_candidate"] = "han"
	before["draft_result"] = "1면 · 한신"
	ui.game.restore(before)
	ui.show_phase()
	await snap("narrow-duplicate")
	var options = camp_labels()
	if "왕의 신호 (유방의 기세 베기 피해 +25%)" not in options or "보급 전환 시 보급" not in options:
		push_error("Duplicate options omit the upgrade and conversion previews")
		status = 1
	var promote: Button = ui.primary_button
	if not promote.text.begins_with("승급") or not promote.has_focus() or not root.get_visible_rect().encloses(promote.get_global_rect()):
		push_error("Promotion choice is not visible and focused at 760x544")
		status = 1
	var click = InputEventMouseButton.new()
	click.position = promote.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await snap("narrow-promote-preview")
	var confirm: Button = ui.primary_button
	if ui.draft_resolution!="promote" or ui.game.promotion_level("han")!=0 or not confirm.has_focus() or not root.get_visible_rect().encloses(confirm.get_global_rect()) or "진법 변화: 왕의 신호 (유방의 기세 베기 피해 +25%)" not in camp_labels():
		push_error("Confirmation is not visible or the preview already applied its reward")
		status = 1
	key = key.duplicate()
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	if ui.game.phase!="map" or ui.game.promotion_level("han")!=1 or ui.game.tactics.support!="royal_signal":
		status = 1
	print("Narrow camp 760x544 (118%): keyboard roll, mouse promotion choice, keyboard confirmation")
	for supply in [0,1]:
		var route_camp = before.duplicate(true)
		route_camp.rolled = false
		route_camp.draft_result = ""
		route_camp.draft_candidate = ""
		route_camp.supply = supply
		ui.game.restore(route_camp)
		ui.show_phase()
		var can_depart: bool = supply==1
		map_badge("진법 규칙과 적용 중인 군령").pressed.emit()
		var rules = ui.modal.find_child("CampRules",true,false)
		if rules!=null: rules.pressed.emit()
		var forecast: String = camp_labels(ui.modal_content)
		ui.close_modal()
		ui.choose_perk(ui.game.offerings[0].id)
		var choice: Button = ui.primary_button
		ui.choose_route(0)
		var departed: bool = ui.game.phase=="battle" and ui.checkpoint_data.get("phase")=="travel"
		if ("수변 나루 (보급 부족, 1 필요)" in forecast)==can_depart or ("수변 나루 (초기 적이 적음)" in forecast)!=can_depart or choice.disabled==can_depart or departed!=can_depart:
			push_error("Camp, map and departure disagree on the ferry at supply %d" % supply)
			status = 1
		print("Ferry supply ",supply," / disabled ",choice.disabled," / departed ",departed)
	var conversion = before.duplicate(true)
	conversion.supply = 0
	ui.game.restore(conversion)
	ui.show_phase()
	ui.choose_draft_resolution("supply")
	map_badge("진법 규칙과 적용 중인 군령").pressed.emit()
	var rules = ui.modal.find_child("CampRules",true,false)
	if rules!=null: rules.pressed.emit()
	var available: bool = "수변 나루 (초기 적이 적음)" in camp_labels(ui.modal_content)
	ui.close_modal()
	ui.choose_perk(ui.game.offerings[0].id)
	ui.choose_route(0)
	if not available or ui.game.phase!="battle" or ui.game.supply!=1:
		push_error("The ferry forecast must use supply from the pending conversion")
		status = 1
	print("Ferry projected conversion 0 → 2 / departure supply ",ui.game.supply)
	var convoy = before.duplicate(true)
	convoy.chapter = 1
	ui.game.restore(convoy)
	ui.show_phase()
	map_badge("진법 규칙과 적용 중인 군령").pressed.emit()
	rules = ui.modal.find_child("CampRules",true,false)
	if rules!=null: rules.pressed.emit()
	if "오창 보급길 (매복병이 많음)" not in camp_labels(ui.modal_content) or "성고 산등성이 (매복병이 적음)" not in camp_labels(ui.modal_content):
		push_error("The convoy forecast must describe the route-dependent ambush")
		status = 1
	ui.close_modal()

func order_edges() -> void:
	ui.complete_travel()
	Pilot.pilot(ui.game,5000)
	if ui.game.phase!="camp":
		push_error("Orders UI fixture did not reach camp")
		status = 1
		return
	var camp: Dictionary = ui.game.checkpoint()
	camp.heroes.append("cao")
	camp.perks["cao"] = []
	camp.perks.liu.append_array(["golden_eye","ration_cycle"])
	camp.supply = 3
	var rng = RandomNumberGenerator.new()
	for seed_value in range(1,100):
		rng.seed = seed_value
		var state = rng.state
		if rng.randi_range(1,18)==18:
			camp.streams[2] = state
			break
	for example in [[3,"promote",3], [9,"supply",9], [9,"promote",9]]:
		camp.supply = example[0]
		ui.game.restore(camp)
		ui.show_phase()
		var streams: Array = ui.game.checkpoint().streams
		await snap("orders-unrolled")
		check_camp_layout()
		if ui.game.checkpoint().streams!=streams:
			status = 1
		ui.change_odds("lance")
		ui.perform_roll()
		await snap("orders-golden-%d" % example[0])
		check_camp_layout()
		if "18면 대길" not in camp_labels() or "조참 승급 확정" in camp_labels():
			push_error("18 must be visible alongside the pending duplicate reward")
			status = 1
		var before: Dictionary = ui.game.checkpoint()
		var rolled: int = example[0]-1
		var promote = "승급 시 보급 %d → %d / 황금 눈 +1" % [rolled,rolled+1]
		var conversion: int = mini(2,9-rolled)
		var supply = "보급 전환 시 보급 %d → %d" % [rolled,mini(9,rolled+conversion+1)]
		if rolled+conversion<9: supply += " / 황금 눈 +1"
		if not "눈 18 / 18" in camp_labels():
			push_error("Camp labels omit the final face")
			status = 1
		if example[0]==3:
			await check_camp_orders()
		if directory and example[0]==3:
			DirAccess.copy_absolute(ui.store_path,directory.path_join("camp.cfg"))
		check_reward_view(promote, "승급")
		if not supply in camp_labels():
			push_error("Both choices must show their separate supply outcomes before selection")
			status = 1
		confirm_with_enter()
		await snap("orders-promotion-%d" % example[0])
		check_camp_layout()
		check_reward_view(promote,"강화")
		if example[0]==3:
			await check_camp_orders(true)
		var pending_visible = false
		for label in ui.screen_body.find_children("*","Label",true,false):
			if label.text.begins_with("조참 승급 예정") and label.is_visible_in_tree() and root.get_visible_rect().encloses(label.get_global_rect()):
				pending_visible = true
		if not pending_visible:
			push_error("The pending promotion must stay visible when focus scrolls to the perk")
			status = 1
		if example[0]==9:
			ui.choose_draft_resolution("supply")
			await snap("orders-cap-conversion")
			check_reward_view(supply,"강화")
			if example[1]=="promote":
				ui.choose_draft_resolution("promote")
				await snap("orders-cap-promotion")
				check_reward_view(promote,"강화")
		if ui.game.checkpoint()!=before or ui.game.supply!=rolled:
			push_error("Preview changed the rolled checkpoint")
			status = 1
		if example[0]==3:
			var path: String = ui.store_path
			ui.store_path = path.path_join("unwritable.cfg")
			ui.choose_perk(ui.game.offerings[0].id)
			var failed: Dictionary = ui.game.checkpoint()
			if failed.streams!=before.streams or failed.phase!="camp" or failed.promotions!=before.promotions or failed.supply!=before.supply or failed.draft_candidate!=before.draft_candidate or not ui.save_error or "조참 승급 확정" in camp_labels() or ui.audio_sequence!=0:
				print("Save failure state: ",failed.phase," / ",failed.promotions," / ",failed.supply," / ",failed.draft_candidate," / ",ui.save_error," / muted cues ",ui.audio_sequence)
				push_error("Save failure must leave the promotion and its presentation pending")
				status = 1
			ui.store_path = path
			ui.close_modal()
			await process_frame
			await process_frame
		confirm_with_enter()
		await snap("orders-map-%d-%s" % [example[0],example[1]])
		var saved = ConfigFile.new()
		var saved_ok = saved.load(ui.store_path)==OK
		var state: Dictionary = saved.get_value("checkpoint","state",{}) if saved_ok else {}
		var promoted: bool = example[1]=="promote"
		var outcome = "조참 승급 확정" if promoted else "조참 중복, 보급 전환 확정"
		if not root.get_visible_rect().encloses(ui.map_prompt.get_global_rect()) or not root.get_visible_rect().encloses(ui.primary_button.get_global_rect()):
			push_error("The confirmed result must leave the map controls and prompt visible")
			status = 1
		var badge_name = "대길 승급" if promoted else "대길 환전"
		await check_map_badge(badge_name,"등용 확정 / 18면 대길 / "+outcome)
		var has_ration = map_badge("군량 순환 군령")!=null
		if promoted:
			await check_map_badge("군량 순환 군령","군령 / 군량 순환 / 조참 최대 및 시작 MP +4")
		ui.show_phase()
		await check_map_badge(badge_name,"등용 확정 / 18면 대길 / "+outcome)
		if ui.dice_view.get("reveal_elapsed")<.74 or ui.audio_sequence!=0:
			push_error("Rebuilding the map must preserve the result without replaying it")
			status = 1
		if has_ration!=promoted:
			push_error("Only a promotion with ration cycle must add its order badge")
			status = 1
		if ui.game.phase!="map" or ui.game.supply!=example[2] or state.get("supply")!=example[2] or state.get("streams")!=before.streams or ui.game.promotion_level("cao")!=int(promoted):
			push_error("Saved supply, rank or RNG differs from the forecast")
			status = 1
	var convoy = camp.duplicate(true)
	convoy.chapter = 1
	convoy.rolled = true
	convoy.draft_candidate = "cao"
	convoy.draft_result = "18면 / 조참"
	ui.game.restore(convoy)
	ui.show_phase()
	if directory and ui.save():
		DirAccess.copy_absolute(ui.store_path,directory.path_join("convoy-camp.cfg"))
	ui.choose_draft_resolution("supply")
	ui.choose_perk(ui.game.offerings[0].id)
	await snap("orders-convoy-confirmed")
	for index in [-1,0,1]:
		ui.refresh_map_prompt(index)
		await process_frame
		await process_frame
		for control in ui.screen_body.find_children("*","Control",true,false):
			if (control is Label or control is Button) and control.is_visible_in_tree() and not root.get_visible_rect().encloses(control.get_global_rect()):
				push_error("The confirmed convoy route or prompt is clipped: %s" % control.text)
				status = 1
	print("Convoy map / all labels and buttons inspected in ",root.size)
	await ration_heal(camp)
	var late = camp.duplicate(true)
	late.chapter = 2
	late.heroes.append("han")
	late.perks.han = []
	late.mode = "fiction"
	ui.game.restore(late)
	ui.show_phase()
	await snap("orders-late-odds")
	check_camp_layout()
	late.draft_plan = "lance"
	late.rolled = true
	late.draft_candidate = "cao"
	late.draft_result = "18면 / 조참"
	ui.game.restore(late)
	ui.show_phase()
	ui.choose_draft_resolution("promote")
	await snap("orders-late-promotion")
	check_camp_layout()
	if OS.get_environment("HAN_MARCH_FORECAST_AUDIO_TEST")=="1":
		check_draft_audio(camp)
	print("Orders UI ",root.size," / text scale ",ui.text_zoom," / result ",status)

func check_draft_audio(camp: Dictionary) -> void:
	if DisplayServer.get_name()!="headless" or AudioServer.get_driver_name()!="Dummy" or not AudioServer.is_bus_mute(0) or not OS.has_environment("HAN_MARCH_PROFILE"):
		push_error("Draft audio probe requires a muted, isolated headless Dummy run")
		status = 1
		return
	print("Draft audio driver: ",AudioServer.get_driver_name(),", initially muted")
	AudioServer.set_bus_mute(0,false)
	for example in [
		[18,"cao","promote",["promotion","great_fortune"]],
		[18,"cao","",["recruit","great_fortune"]],
		[9,"han","",["recruit"]],
		[1,"fan","promote",["promotion"]],
		[18,"cao","supply",["great_fortune"]],
	]:
		for player in ui.audio_players:
			player.stop()
		var pending = camp.duplicate(true)
		if example[2]=="":
			pending.heroes.erase(example[1])
			pending.perks.erase(example[1])
		pending.rolled = true
		pending.draft_candidate = example[1]
		pending.draft_result = "%d면 / %s" % [example[0],Campaign.HEROES[example[1]][0]]
		var first: int = ui.audio_sequence
		var slot: int = ui.audio_next
		ui.game.restore(pending)
		ui.show_phase()
		ui.perform_redraw()
		ui.game.restore(pending)
		ui.show_phase()
		ui.choose_draft_resolution(example[2])
		var path: String = ui.store_path
		ui.store_path = path.path_join("unwritable.cfg")
		var perk: String = ui.game.offerings[0].id
		ui.choose_perk(perk)
		if not ui.save_error or ui.audio_sequence!=first:
			push_error("Pending, redrawn or failed draft played a cue")
			status = 1
		ui.store_path = path
		ui.close_modal()
		ui.choose_perk(perk)
		var expected: Array = example[3]
		var played: Array[String] = []
		for i in expected.size():
			var index = (slot+i)%4
			var player: AudioStreamPlayer = ui.audio_players[index]
			if player.playing and player.stream==ui.sounds.get(expected[i]) and ui.audio_started[index]==first+i+1:
				played.append(expected[i])
		if ui.game.phase!="map" or ui.audio_players.size()!=4 or ui.audio_sequence!=first+expected.size() or played!=expected:
			push_error("Saved draft did not play each expected cue once in the four-slot pool")
			status = 1
		var committed: int = ui.audio_sequence
		ui.choose_perk(perk)
		ui.show_phase()
		ui.continue_run()
		if ui.audio_sequence!=committed:
			push_error("Repeat confirmation, redraw or checkpoint resume replayed a saved cue")
			status = 1
		print("Draft audio ",example[0],"/",example[1],"/",example[2],": ",played," / first slot ",slot," / total ",ui.audio_sequence-first)
	AudioServer.set_bus_mute(0,true)

func check_camp_orders(resolved := false) -> void:
	var details = map_badge("진법 규칙과 적용 중인 군령")
	if details==null:
		push_error("Camp is missing its order details control")
		status = 1
		return
	var primary: Button = ui.primary_button
	var click_position = Vector2(3,root.size.y-3)
	if resolved and root.size.x==1280:
		click_position = Vector2(primary.get_global_rect().get_center().x,primary.get_global_rect().end.y-4)
	var before: Dictionary = ui.game.checkpoint()
	details.grab_focus()
	confirm_with_enter()
	await snap("orders-detail")
	var scroller: ScrollContainer = ui.modal_content.get_parent()
	var effects: String = camp_labels(ui.modal_content)
	var close: Control = root.gui_get_focus_owner()
	if not "첫 공격 또는 응급 처치의 피로 증가량 최대 10 감소" in effects or not "야영지 1회 / 최대 9" in effects or close==null or close.accessibility_name!="닫기":
		push_error("The details must show the active effects and named close control")
		status = 1
	if root.size.x==760 and scroller.get_v_scroll_bar().visible:
		push_error("All three order entries and their limits should fit the 118% detail viewport")
		status = 1
	if scroller.get_v_scroll_bar().visible:
		var page = InputEventKey.new()
		page.physical_keycode = KEY_PAGEDOWN
		page.pressed = true
		root.push_input(page)
		await process_frame
		if scroller.scroll_vertical<=0 or not root.get_visible_rect().encloses(close.get_global_rect()):
			push_error("Details must scroll with the keyboard while Close stays visible")
			status = 1
	var cards = ui.screen_body.find_child("CampCards",true,false)
	for card in cards.get_children():
		if not card.accessibility_name.ends_with(" / 군령"): continue
		var rule_name: String = card.accessibility_name.get_slice(" / ",0)
		var expected = "선택 가능" if resolved else "등용 보상 선택 필요"
		if card.disabled==resolved or not (rule_name+" / "+expected) in effects:
			push_error("The offered order must describe the same availability as its card")
			status = 1
	var tactics = ui.modal.find_child("CampTactics",true,false)
	if tactics==null:
		push_error("The detail view needs a keyboard-accessible tactics control")
		status = 1
	else:
		tactics.grab_focus()
		confirm_with_enter()
		await process_frame
		var rules: String = camp_labels(ui.modal_content)
		for text in ["방패 엄호 / 주 진법 / 한신과 번쾌","약낭 돌파 / 주 진법 / 소하와 조참 또는 항우","유방의 기세 베기 피해 +25%","조참의 공격 피해 +20%"]:
			if not text in rules:
				push_error("Missing tactics detail: "+text)
				status = 1
		if resolved and not "현재 +20% / 예정 +30%" in rules:
			push_error("Tactics details must show the actual projected bonus")
			status = 1
	if resolved and root.size.x==1280:
		var modal_card: Control = scroller.get_parent().get_parent()
		if primary.disabled or not primary.get_global_rect().has_point(click_position) or modal_card.get_global_rect().has_point(click_position):
			push_error("The outside-click test must overlap the active perk button")
			status = 1
	var click = InputEventMouseButton.new()
	click.position = click_position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame
	if ui.modal_active:
		push_error("An outside click must close the camp details")
		status = 1
		ui.close_modal()
	await process_frame
	if not details.has_focus() or ui.game.checkpoint()!=before:
		push_error("Closing the order details must restore focus without changing phase, supply or RNG")
		status = 1
	primary.grab_focus()
	await process_frame

func check_reward_view(note: String, stage: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	var bounds = Rect2()
	for label in ui.screen_body.find_children("*","Label",true,false):
		if note in label.text and label.is_visible_in_tree():
			bounds = label.get_global_rect()
			break
	var desc: String = focus.accessibility_description if focus!=null else ""
	print(stage," ",note," / label ",bounds," / viewport ",root.get_visible_rect()," / AX ",desc)
	if not bounds.has_area() or not root.get_visible_rect().encloses(bounds) or focus==null or focus!=ui.primary_button or not root.get_visible_rect().encloses(focus.get_global_rect()) or (desc!=note and not desc.begins_with(note+" / ")):
		push_error("Refund summary and accessible description are required at the focused decision")
		status = 1

func confirm_with_enter() -> void:
	var key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)

func ration_heal(camp: Dictionary) -> void:
	var fixture = camp.duplicate(true)
	fixture.rolled = true
	fixture.draft_candidate = "xiao"
	fixture.draft_result = "6면 · 소하"
	fixture.perks.xiao.append("reserve")
	ui.game.restore(fixture)
	ui.show_phase()
	ui.choose_draft_resolution("promote")
	await snap("orders-heal-preview")
	if not "군량 순환 적용 예정" in camp_labels():
		status = 1
	confirm_with_enter()
	await snap("orders-heal-map")
	await check_map_badge("군량 순환 군령","소하 최대 및 시작 MP +4, 첫 공격 또는 응급 처치 시 피로 최대 -10")
	ui.choose_route(0)
	ui.complete_travel()
	var game = ui.game
	var player: Dictionary = game.team[0]
	var medic: Dictionary = game.team[2]
	var ready: bool = medic.mp==36.0 and medic.max_mp==36.0 and medic.get("ration_credit",0)==10
	game.clear_battle()
	game.team.append_array([player,medic])
	game.barrier.clear()
	player.p = Vector2(200,200)
	player.hp = 40.0
	medic.p = Vector2(200,205)
	for frame in 100:
		game.step(Vector2.ZERO,Vector2.RIGHT,false,false,false,false)
		if game.events.has("응급 처치"):
			break
	if not ready or player.hp!=61.0 or medic.fatigue!=0.0 or medic.has("ration_credit"):
		push_error("Xiao's first heal must spend the ration and keep its usual healing amount")
		status = 1
	print("Ration heal / ",ready," / HP ",player.hp," / fatigue ",medic.fatigue," / credit ",medic.get("ration_credit",0))

func verify() -> void:
	directory = OS.get_environment("HAN_MARCH_CAPTURE")
	var orders = OS.get_environment("HAN_MARCH_ORDERS_UI")
	root.size = Vector2i(1280,800) if orders=="wide" else Vector2i(760,544)
	ui = Scene.instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	ui.text_zoom = 1.0 if orders=="wide" else 1.18
	ui.introduction_open = true
	ui.build_theme()
	ui.show_phase()
	await snap("narrow-title")
	var clipped: Array[String] = []
	for button in ui.screen_body.find_children("*","Button",true,false):
		if not root.get_visible_rect().encloses(button.get_global_rect()):
			clipped.append(button.text)
	print("Title clipped: ",clipped)
	ui.run_seed.text="12345"
	ui.start_historical()
	await snap("narrow-route-12345")
	var state: int = ui.game.field_rng.state
	ui.show_menu()
	await snap("narrow-options")
	print("Menu focus: ",root.gui_get_focus_owner()!=null," settings pause: ",ui.modal_active)
	ui.close_modal()
	ui.choose_route(0)
	ui.complete_travel()
	ui.save()
	var serialized: Dictionary = ui.checkpoint_data
	ui.queue_free()
	await process_frame
	ui = Scene.instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	ui.continue_run()
	await snap("narrow-reopened-checkpoint")
	print("Reopen: ",ui.game.seed_value," / ",ui.game.selected_route," / ",ui.game.battle_seed)
	if not clipped.is_empty() or state==ui.game.field_rng.state or serialized.version!=2 or serialized.board_seed!=ui.game.battle_seed or ui.game.seed_value!=12345:
		status = 1
	if orders.is_empty():
		await camp_edges()
	else:
		await order_edges()
	ui.queue_free()
	await process_frame
	await process_frame
	quit(status)
