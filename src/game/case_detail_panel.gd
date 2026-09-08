class_name CaseDetailPanel
extends VBoxContainer

signal entity_requested(reference: Dictionary)
signal action_requested(case_id: String, action_id: String)

var title_label: Label
var location_badge: Label
var locate_button: Button

var vital_box: PanelContainer
var vital_card: RichTextLabel

var directive_box: PanelContainer
var action_header: Label
var choices: OptionButton
var action_explainer: RichTextLabel
var apply_button: Button

var tabs: TabContainer
var briefing_text: RichTextLabel
var evidence_text: RichTextLabel
var history_text: RichTextLabel
var technical_text: RichTextLabel

var current: Dictionary = {}
var actions: Array = []

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 3)
	
	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 12)
	add_child(title_label)
	
	location_badge = Label.new()
	location_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_badge.add_theme_font_size_override("font_size", 10)
	location_badge.add_theme_color_override("font_color", Color(0.65, 0.80, 0.95))
	add_child(location_badge)
	
	locate_button = Button.new()
	locate_button.text = "LOCATE & INSPECT AFFECTED AREA"
	locate_button.focus_mode = Control.FOCUS_NONE
	locate_button.add_theme_font_size_override("font_size", 10)
	locate_button.custom_minimum_size.y = 22
	locate_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.14, 0.22, 0.9), Color(0.25, 0.42, 0.60, 0.8)))
	locate_button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.22, 0.35, 1.0), Color(0.40, 0.65, 0.90, 1.0)))
	locate_button.add_theme_stylebox_override("pressed", _button_style(Color(0.05, 0.10, 0.18, 1.0), Color(0.20, 0.35, 0.50, 1.0)))
	locate_button.pressed.connect(func():
		if current.has("focus"): entity_requested.emit(current.focus))
	add_child(locate_button)
	
	# 1. OS Vital Signs & Telemetry Box
	vital_box = PanelContainer.new()
	vital_box.add_theme_stylebox_override("panel", _box_style(Color(0.04, 0.08, 0.14, 0.95), Color(0.18, 0.32, 0.48, 0.7), 4, 5))
	add_child(vital_box)
	
	vital_card = RichTextLabel.new()
	vital_card.bbcode_enabled = true
	vital_card.fit_content = true
	vital_card.scroll_active = false
	vital_card.add_theme_font_size_override("normal_font_size", 10)
	vital_box.add_child(vital_card)
	
	# 2. Dedicated Directive / Decision Terminal Console (Prominent Real Estate)
	directive_box = PanelContainer.new()
	directive_box.add_theme_stylebox_override("panel", _box_style(Color(0.07, 0.13, 0.22, 1.0), Color(0.28, 0.58, 0.88, 1.0), 4, 7))
	add_child(directive_box)
	
	var directive_vbox := VBoxContainer.new()
	directive_vbox.add_theme_constant_override("separation", 3)
	directive_box.add_child(directive_vbox)
	
	action_header = Label.new()
	action_header.text = "┌── DIRECTIVE CONSOLE: SELECTION & DISPATCH ──┐"
	action_header.add_theme_font_size_override("font_size", 10)
	action_header.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	directive_vbox.add_child(action_header)
	
	choices = OptionButton.new()
	choices.focus_mode = Control.FOCUS_NONE
	choices.custom_minimum_size.y = 24
	choices.add_theme_font_size_override("font_size", 11)
	choices.item_selected.connect(_choice_changed)
	directive_vbox.add_child(choices)
	
	action_explainer = RichTextLabel.new()
	action_explainer.bbcode_enabled = true
	action_explainer.fit_content = false
	action_explainer.scroll_active = true
	action_explainer.custom_minimum_size.y = 66
	action_explainer.add_theme_font_size_override("normal_font_size", 10)
	directive_vbox.add_child(action_explainer)
	
	apply_button = Button.new()
	apply_button.text = "⚡ QUEUE DIRECTIVE → ADVANCE TIME"
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.custom_minimum_size.y = 28
	apply_button.add_theme_font_size_override("font_size", 11)
	apply_button.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	apply_button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.24, 0.38, 1.0), Color(0.35, 0.75, 1.0, 1.0)))
	apply_button.add_theme_stylebox_override("hover", _button_style(Color(0.15, 0.32, 0.50, 1.0), Color(0.55, 0.90, 1.0, 1.0)))
	apply_button.add_theme_stylebox_override("pressed", _button_style(Color(0.06, 0.16, 0.28, 1.0), Color(0.25, 0.55, 0.80, 1.0)))
	apply_button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.12, 0.15, 0.6), Color(0.25, 0.30, 0.35, 0.6)))
	apply_button.pressed.connect(func():
		if not current.is_empty() and choices.selected >= 0 and choices.selected < actions.size():
			action_requested.emit(str(current.id), str(actions[choices.selected].id)))
	directive_vbox.add_child(apply_button)
	
	# 3. OS Diagnostics & Deep Dossier Tabs (Tucked underneath for deep exploration)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 80
	add_child(tabs)
	
	briefing_text = _create_rich_text("Full Dossier")
	briefing_text.meta_clicked.connect(_follow_link)
	evidence_text = briefing_text
	tabs.add_child(briefing_text)
	
	history_text = _create_rich_text("History / Log")
	tabs.add_child(history_text)
	
	technical_text = _create_rich_text("Telemetry / IDs")
	tabs.add_child(technical_text)

func _create_rich_text(tab_title: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.name = tab_title
	text.bbcode_enabled = true
	text.scroll_active = true
	text.selection_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return text

func show_case(data: Dictionary) -> void:
	var old_id := str(current.get("id", ""))
	var previous_choice := str(actions[choices.selected].id) if choices.selected >= 0 and choices.selected < actions.size() else ""
	current = data
	visible = not data.is_empty()
	if data.is_empty(): return
	
	var sev_text := str(data.get("severity_text", "Needs attention"))
	var title_text := str(data.get("title", "Operational Problem"))
	title_label.text = "%s [%s]" % [title_text.to_upper(), sev_text.to_upper()]
	location_badge.text = "%s · Status: %s · Age: %dh %02dm" % [
		data.get("location", "Level ?"),
		data.get("status_text", data.get("status", "")),
		int(data.get("age_ticks", 0)) / 6,
		(int(data.get("age_ticks", 0)) % 6) * 10
	]
	
	# 1. Render OS Vital Signs Card
	var os: Dictionary = data.get("os_telemetry", {})
	var v_text := ""
	for g in os.get("gauges", []):
		v_text += "[b]%s:[/b] [color=%s][b]%s %s[/b][/color] [color=#8da9c4](%s)[/color]\n" % [
			g.label, g.color, g.bar, g.val, g.limit
		]
	var chips: Array = os.get("chips", [])
	if not chips.is_empty():
		var chip_parts: Array[String] = []
		for ch in chips:
			chip_parts.append("%s [color=%s]%s[/color]" % [ch.icon, ch.color, ch.text])
		v_text += " · ".join(chip_parts) + "\n"
		
	var sit := str(os.get("situation", data.get("summary", "")))
	var stak := str(os.get("stakes", ""))
	if not sit.is_empty():
		v_text += "[b]Status:[/b] %s\n" % escape(sit)
	if not stak.is_empty():
		v_text += "[color=#ffd166][b]Stakes:[/b][/color] %s" % escape(stak)
		
	vital_card.text = v_text
	
	# 2. Build Action Choices (Immediately adjacent to status)
	actions = data.get("available_actions", [])
	choices.clear()
	var selected := 0
	for i in range(actions.size()):
		choices.add_item(str(actions[i].label))
		if old_id == str(data.id) and str(actions[i].id) == previous_choice: selected = i
	choices.select(selected)
	_choice_changed(selected)
	
	# 3. Render Deep Dossier (Full 7-point report in lower tab)
	var briefing: Dictionary = data.get("briefing", {})
	var b_text := ""
	
	b_text += "[b][color=#4cc9f0]WHAT'S HAPPENING[/color][/b]\n"
	b_text += escape(str(briefing.get("whats_happening", data.get("summary", "")))) + "\n\n"
	
	b_text += "[b][color=#4cc9f0]WHY? (WHY IT'S HAPPENING)[/color][/b]\n"
	b_text += escape(str(briefing.get("why", ""))) + "\n\n"
	
	b_text += "[b][color=#4cc9f0]WHY IT MATTERS[/color][/b]\n"
	b_text += escape(str(briefing.get("why_it_matters", ""))) + "\n\n"
	
	b_text += "[b][color=#4cc9f0]WHO / WHAT IS AFFECTED[/color][/b]\n"
	b_text += "[b]Currently affected:[/b]\n"
	for item in briefing.get("affected_current", []):
		b_text += "• " + escape(str(item)) + "\n"
	b_text += "[b]Potentially affected:[/b]\n"
	for item in briefing.get("affected_potential", []):
		b_text += "• " + escape(str(item)) + "\n"
	b_text += "\n"
	
	if briefing.has("root_problem"):
		b_text += "[b][color=#f72585]ROOT PROBLEM (FACILITY):[/color][/b]\n"
		b_text += escape(str(briefing.get("root_problem", ""))) + "\n\n"
		b_text += "[b][color=#f72585]INFORMATION STATUS (OFFICIAL):[/color][/b]\n"
		b_text += escape(str(briefing.get("information_problem", ""))) + "\n\n"
		b_text += "[b][color=#ffd166]YOUR AUTHORITY (HEAD OF IT):[/color][/b]\n"
		b_text += escape(str(briefing.get("player_authority", ""))) + "\n\n"
		b_text += "[b][color=#06d6a0]OUTSIDE DIRECT IT AUTHORITY:[/color][/b]\n"
		b_text += escape(str(briefing.get("outside_authority", ""))) + "\n\n"
	elif briefing.has("player_authority"):
		b_text += "[b][color=#ffd166]YOUR AUTHORITY (HEAD OF IT):[/color][/b]\n"
		b_text += escape(str(briefing.get("player_authority", ""))) + "\n\n"
		
	b_text += "[b][color=#4cc9f0]WHAT WE KNOW[/color][/b]\n"
	for item in briefing.get("what_we_know", []):
		b_text += "• " + escape(str(item)) + "\n"
	b_text += "\n"
	
	b_text += "[b][color=#4cc9f0]WHAT WE DON'T KNOW[/color][/b]\n"
	for item in briefing.get("what_we_dont_know", []):
		b_text += "• " + escape(str(item)) + "\n"
	b_text += "\n"
	
	if data.get("why", []).size() > 0:
		b_text += "[b][color=#4cc9f0]RECORDED LOCATION LINKS[/color][/b]\n"
		for ref in data.get("why", []):
			if int(ref.id) > 0 and str(ref.type) != "":
				b_text += "[url=%s:%d:%d]→ %s[/url]\n" % [ref.type, ref.id, ref.room_id, escape(ref.text)]
			else:
				b_text += "• " + escape(ref.text) + "\n"
				
	var old_scroll := briefing_text.get_v_scroll_bar().value
	briefing_text.text = b_text
	if old_id == str(data.id): briefing_text.get_v_scroll_bar().value = old_scroll
	else: briefing_text.scroll_to_line(0)
	
	# Render History / Outcomes tab
	var h_text := "[b]OUTCOME HISTORY & TIMELINE[/b]\n\n"
	if not str(data.get("pending", "")).is_empty():
		h_text += "[color=#ffd166]QUEUED DECISION: %s (executes on next tick)[/color]\n\n" % escape(str(data.pending).replace("_", " "))
		
	h_text += "[b]DIRECTIVES ISSUED[/b]\n"
	var action_history: Array = data.get("actions", [])
	if action_history.is_empty():
		h_text += "No directives issued yet for this case.\n\n"
	else:
		for dec in action_history:
			h_text += "• Hour %d · Directive: %s\n  %s\n\n" % [int(dec.tick) / 6, escape(str(dec.action).replace("_", " ")), escape(str(dec.effect))]
			
	h_text += "[b]SYSTEM LOGS & CONSEQUENCES[/b]\n"
	var history_entries: Array = data.get("history", []).duplicate()
	history_entries.reverse()
	for entry in history_entries:
		h_text += "• Hour %d: %s\n" % [int(entry.tick) / 6, escape(entry.text)]
	history_text.text = h_text
	
	# Render Technical Details tab (for advanced debugging/inspection)
	var t_text := "[b]TECHNICAL DETAILS & ENGINE IDENTIFIERS[/b]\n\n"
	var tech: Dictionary = data.get("technical_details", {})
	for k in tech:
		t_text += "[b]%s:[/b] %s\n" % [str(k), str(tech[k])]
	technical_text.text = t_text

func _choice_changed(index: int) -> void:
	if index < 0 or index >= actions.size(): return
	var action: Dictionary = actions[index]
	var text := ""
	text += "[b]Order:[/b] %s\n" % str(action.description)
	text += "[color=#4cc9f0][b]► Purpose:[/b][/color] %s  " % str(action.why_do_it)
	text += "[color=#ffd166][b]▲ Trade-off:[/b][/color] %s\n" % str(action.trade_off)
	text += "[color=#ef476f][b]⚠️ DOES NOT SOLVE:[/b][/color] %s" % str(action.does_not_do)
	if not action.enabled:
		text += "\n[color=#ef476f][b]⛔ BLOCKED:[/b] %s[/color]" % str(action.reason)
	action_explainer.text = text
	apply_button.disabled = not action.enabled

func _follow_link(meta: Variant) -> void:
	var parts := str(meta).split(":")
	if parts.size() == 3:
		entity_requested.emit({"type": parts[0], "id": parts[1].to_int(), "room_id": parts[2].to_int()})

static func escape(value: String) -> String:
	return value.replace("[", "[lb]")

static func _box_style(bg: Color, border: Color, radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb

static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb
