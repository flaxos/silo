# src/game/hud.gd
## CanvasLayer-based HUD for the silo viewer.
## Dynamically creates all UI nodes in _ready() — no .tscn dependency.
## Provides clock display, population count, speed controls, water reservoir bar,
## and alert count in a top-bar layout.
class_name SiloHUD
extends CanvasLayer

# ── Signals ──────────────────────────────────────────────────────────────────
## Emitted when the player changes simulation speed via button or keyboard.
signal speed_changed(new_speed: int)

# ── UI node references (created in _ready) ───────────────────────────────────
var _clock_label: Label
var _pop_label: Label
var _water_bar: ProgressBar
var _water_label: Label
var _speed_buttons: Array[Button] = []
var _alert_label: Label

## Current simulation speed: 0 = paused, 1 = 1×, 2 = 2×, 4 = 4×, 8 = 8×.
var current_speed: int = 1

# Valid speed steps for cycling / button mapping.
const _SPEED_STEPS: Array[int] = [0, 1, 2, 4, 8]

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Ensure HUD renders on its own canvas layer above the game.
	layer = 10

	# ── Root PanelContainer (full-width bar at top of screen) ────────────
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_bottom = 40.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Dark semi-transparent panel style.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	# ── Main HBoxContainer ──────────────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.name = "MainHBox"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# ── Left side: Clock + Population ───────────────────────────────────
	_clock_label = _make_label("Year 1, Day 001, 08:00")
	_clock_label.name = "ClockLabel"
	_clock_label.custom_minimum_size.x = 200.0
	hbox.add_child(_clock_label)

	var sep1 := VSeparator.new()
	sep1.modulate = Color(1.0, 1.0, 1.0, 0.3)
	hbox.add_child(sep1)

	_pop_label = _make_label("Pop: 0 / 0")
	_pop_label.name = "PopLabel"
	_pop_label.custom_minimum_size.x = 100.0
	hbox.add_child(_pop_label)

	# ── Left spacer ────────────────────────────────────────────────────
	var spacer_left := Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_left)

	# ── Center: Speed controls ──────────────────────────────────────────
	var speed_container := HBoxContainer.new()
	speed_container.name = "SpeedControls"
	speed_container.add_theme_constant_override("separation", 4)
	hbox.add_child(speed_container)

	var speed_labels: Array[String] = ["⏸", "1×", "2×", "4×", "8×"]
	for i: int in range(speed_labels.size()):
		var btn := Button.new()
		btn.text = speed_labels[i]
		btn.custom_minimum_size = Vector2(36, 0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# Style the button: flat with subtle background.
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		btn_normal.corner_radius_top_left = 3
		btn_normal.corner_radius_top_right = 3
		btn_normal.corner_radius_bottom_left = 3
		btn_normal.corner_radius_bottom_right = 3
		btn_normal.content_margin_left = 4.0
		btn_normal.content_margin_right = 4.0
		btn_normal.content_margin_top = 2.0
		btn_normal.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover := btn_normal.duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(0.25, 0.25, 0.35, 0.9)
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
		btn_pressed.bg_color = Color(0.1, 0.4, 0.8, 0.9)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)

		var speed_value: int = _SPEED_STEPS[i]
		btn.pressed.connect(_on_speed_button_pressed.bind(speed_value))

		speed_container.add_child(btn)
		_speed_buttons.append(btn)

	# ── Right spacer ───────────────────────────────────────────────────
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_right)

	# ── Right side: Water bar + Alert count ────────────────────────────
	var water_container := HBoxContainer.new()
	water_container.name = "WaterContainer"
	water_container.add_theme_constant_override("separation", 6)
	hbox.add_child(water_container)

	var water_icon_label := _make_label("💧")
	water_icon_label.name = "WaterIcon"
	water_container.add_child(water_icon_label)

	_water_bar = ProgressBar.new()
	_water_bar.name = "WaterBar"
	_water_bar.custom_minimum_size = Vector2(120, 16)
	_water_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_water_bar.min_value = 0.0
	_water_bar.max_value = 100.0
	_water_bar.value = 100.0
	_water_bar.show_percentage = false

	# Style the water bar with a blue fill on dark background.
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_water_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.5, 0.9, 0.9)
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_water_bar.add_theme_stylebox_override("fill", bar_fill)

	water_container.add_child(_water_bar)

	_water_label = _make_label("100%")
	_water_label.name = "WaterLabel"
	_water_label.custom_minimum_size.x = 48.0
	water_container.add_child(_water_label)

	var sep2 := VSeparator.new()
	sep2.modulate = Color(1.0, 1.0, 1.0, 0.3)
	hbox.add_child(sep2)

	_alert_label = _make_label("⚠ 0")
	_alert_label.name = "AlertLabel"
	_alert_label.custom_minimum_size.x = 50.0
	hbox.add_child(_alert_label)

	# Highlight the default speed (1×).
	set_speed_highlight(current_speed)


# ── Public API ───────────────────────────────────────────────────────────────

## Update the clock display with a pre-formatted time string.
func update_clock(time_str: String) -> void:
	_clock_label.text = time_str


## Update the population readout.
func update_population(alive: int, total: int) -> void:
	_pop_label.text = "Pop: %d / %d" % [alive, total]


## Update the water reservoir bar and percentage label.
func update_water(current: float, capacity: float) -> void:
	if capacity <= 0.0:
		_water_bar.value = 0.0
		_water_label.text = "N/A"
		return
	var pct: float = clampf((current / capacity) * 100.0, 0.0, 100.0)
	_water_bar.value = pct
	_water_label.text = "%d%%" % int(pct)

	# Tint the bar fill red when water is critically low.
	var fill_style := _water_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if pct < 20.0:
			fill_style.bg_color = Color(0.9, 0.2, 0.2, 0.9)
		elif pct < 50.0:
			fill_style.bg_color = Color(0.9, 0.7, 0.2, 0.9)
		else:
			fill_style.bg_color = Color(0.2, 0.5, 0.9, 0.9)


## Update the alert indicator with a count of active alerts.
func update_alerts(count: int) -> void:
	_alert_label.text = "⚠ %d" % count
	if count > 0:
		_alert_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_alert_label.add_theme_color_override("font_color", Color.WHITE)


## Visually highlight the button corresponding to the given speed.
func set_speed_highlight(speed: int) -> void:
	for i: int in range(_speed_buttons.size()):
		var btn: Button = _speed_buttons[i]
		var is_active: bool = (_SPEED_STEPS[i] == speed)
		var style: StyleBoxFlat
		if is_active:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.5, 0.9, 0.95)
			style.corner_radius_top_left = 3
			style.corner_radius_top_right = 3
			style.corner_radius_bottom_left = 3
			style.corner_radius_bottom_right = 3
			style.content_margin_left = 4.0
			style.content_margin_right = 4.0
			style.content_margin_top = 2.0
			style.content_margin_bottom = 2.0
		else:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
			style.corner_radius_top_left = 3
			style.corner_radius_top_right = 3
			style.corner_radius_bottom_left = 3
			style.corner_radius_bottom_right = 3
			style.content_margin_left = 4.0
			style.content_margin_right = 4.0
			style.content_margin_top = 2.0
			style.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", style)


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_SPACE:
			# Toggle pause: if currently paused resume to 1×, otherwise pause.
			if current_speed == 0:
				_set_speed(1)
			else:
				_set_speed(0)
			get_viewport().set_input_as_handled()
		KEY_1:
			_set_speed(1)
			get_viewport().set_input_as_handled()
		KEY_2:
			_set_speed(2)
			get_viewport().set_input_as_handled()
		KEY_3:
			_set_speed(4)
			get_viewport().set_input_as_handled()
		KEY_4:
			_set_speed(8)
			get_viewport().set_input_as_handled()


# ── Internals ────────────────────────────────────────────────────────────────

## Apply a new speed, update highlight, and emit signal.
func _set_speed(speed: int) -> void:
	current_speed = speed
	set_speed_highlight(speed)
	speed_changed.emit(speed)


## Callback wired to each speed button's pressed signal.
func _on_speed_button_pressed(speed: int) -> void:
	_set_speed(speed)


## Helper: create a Label with white text and monospace font settings.
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Request a monospace system font via theme font override.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace", "Courier New", "Courier"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)

	return label
