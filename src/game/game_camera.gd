# src/game/game_camera.gd
## Camera2D for viewing the silo cutaway.
##
## Supports mouse-wheel zoom, middle-click drag panning, WASD keyboard pan,
## smooth lerp transitions, and edge clamping within silo bounds.
## Parent scene sets [member silo_bounds] after the layout is built;
## the camera will then fit the entire silo into view automatically.
class_name GameCamera
extends Camera2D

# ── Constants ────────────────────────────────────────────────────────────────

## Minimum zoom factor — shows the whole silo at once.
const ZOOM_MIN: float = 0.08
## Maximum zoom factor — single-room detail.
const ZOOM_MAX: float = 3.0
## Multiplier applied per mouse-wheel notch.
const ZOOM_SPEED: float = 0.15
## Pixels-per-second when panning with WASD keys (at zoom 1.0).
const PAN_SPEED: float = 500.0
## Interpolation speed for smooth camera movement.
const SMOOTH_SPEED: float = 8.0
## Extra margin (in world pixels) beyond the silo bounds the camera may reach.
const BOUNDS_MARGIN: float = 100.0

# ── Public state ─────────────────────────────────────────────────────────────

## Bounding rectangle of the silo layout.
## Expected keys: x, y, width, height.  Set by the parent after layout build.
var silo_bounds: Dictionary = {}

# ── Private state ────────────────────────────────────────────────────────────

## Position the camera is lerping toward.
var _target_position: Vector2 = Vector2.ZERO
## Zoom level the camera is lerping toward (applied uniformly to x & y).
var _target_zoom: float = 1.0
## Whether the user is currently middle-click dragging.
var _is_dragging: bool = false
## Screen-space position where the drag started.
var _drag_start: Vector2 = Vector2.ZERO

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Centre the camera on origin until bounds are provided.
	position = Vector2.ZERO
	_target_position = Vector2.ZERO
	_target_zoom = 1.0
	_apply_zoom(_target_zoom)


func _process(delta: float) -> void:
	_handle_wasd_pan(delta)
	_smooth_update(delta)

# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# ── Mouse-wheel zoom ────────────────────────────────────────────────
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_toward(1.0 + ZOOM_SPEED, mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_toward(1.0 - ZOOM_SPEED, mb.position)
			get_viewport().set_input_as_handled()

		# ── Middle-click drag start / stop ──────────────────────────────
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_is_dragging = true
				_drag_start = mb.position
			else:
				_is_dragging = false
			get_viewport().set_input_as_handled()

	# ── Middle-click drag motion ────────────────────────────────────────
	if event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		# Convert screen-space delta to world-space using current zoom.
		var world_delta: Vector2 = -mm.relative / zoom
		_target_position += world_delta
		_clamp_target()
		get_viewport().set_input_as_handled()

# ── Public API ───────────────────────────────────────────────────────────────

## Smoothly pan the camera to centre on the given room position (world coords).
func focus_room(room_x: float, room_y: float) -> void:
	_target_position = Vector2(room_x, room_y)
	_clamp_target()


## Centre the camera vertically on a given silo level, keeping the current x.
func focus_level(level_y: float) -> void:
	_target_position.y = level_y
	_clamp_target()


## Adjust zoom and position so the entire silo fits in the viewport.
## [param bounds] must contain keys: x, y, width, height.
func fit_bounds(bounds: Dictionary) -> void:
	if bounds.is_empty():
		return

	var bx: float = bounds.get("x", 0.0)
	var by: float = bounds.get("y", 0.0)
	var bw: float = bounds.get("width", 1.0)
	var bh: float = bounds.get("height", 1.0)

	# Centre of the bounding rect.
	_target_position = Vector2(bx + bw * 0.5, by + bh * 0.5)

	# Determine the zoom that fits the bounds into the viewport.
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var zoom_x: float = vp_size.x / bw
	var zoom_y: float = vp_size.y / bh
	_target_zoom = clampf(minf(zoom_x, zoom_y), ZOOM_MIN, ZOOM_MAX)

	_clamp_target()

# ── Private helpers ──────────────────────────────────────────────────────────

## Apply mouse-wheel zoom centred on the pointer position.
func _zoom_toward(factor: float, screen_pos: Vector2) -> void:
	# World position under the cursor before zoom change.
	var world_before: Vector2 = _screen_to_world(screen_pos)

	_target_zoom = clampf(_target_zoom * factor, ZOOM_MIN, ZOOM_MAX)

	# World position under the cursor after zoom change.
	var world_after: Vector2 = _screen_to_world_at_zoom(screen_pos, _target_zoom)

	# Offset so the point under the cursor stays fixed.
	_target_position += world_before - world_after
	_clamp_target()


## Convert a screen-space point to world-space using the *current* zoom.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	var offset: Vector2 = (screen_pos - vp_size * 0.5) / zoom
	return position + offset


## Convert a screen-space point to world-space using an *arbitrary* zoom.
func _screen_to_world_at_zoom(screen_pos: Vector2, z: float) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom_vec: Vector2 = Vector2(z, z)
	var offset: Vector2 = (screen_pos - vp_size * 0.5) / zoom_vec
	return _target_position + offset


## Handle WASD panning each frame.  Pan speed is divided by zoom so movement
## feels consistent regardless of zoom level.
func _handle_wasd_pan(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		# Normalise so diagonals aren't faster.
		direction = direction.normalized()
		_target_position += direction * PAN_SPEED * delta / _target_zoom
		_clamp_target()


## Smoothly interpolate position and zoom toward their targets.
func _smooth_update(delta: float) -> void:
	var weight: float = clampf(SMOOTH_SPEED * delta, 0.0, 1.0)
	position = position.lerp(_target_position, weight)

	var current_z: float = zoom.x
	var new_z: float = lerpf(current_z, _target_zoom, weight)
	_apply_zoom(new_z)


## Set the Camera2D zoom uniformly.
func _apply_zoom(z: float) -> void:
	zoom = Vector2(z, z)


## Clamp [member _target_position] so the camera stays within the silo bounds
## plus a configurable margin.
func _clamp_target() -> void:
	if silo_bounds.is_empty():
		return

	var bx: float = silo_bounds.get("x", 0.0)
	var by: float = silo_bounds.get("y", 0.0)
	var bw: float = silo_bounds.get("width", 0.0)
	var bh: float = silo_bounds.get("height", 0.0)

	var min_x: float = bx - BOUNDS_MARGIN
	var max_x: float = bx + bw + BOUNDS_MARGIN
	var min_y: float = by - BOUNDS_MARGIN
	var max_y: float = by + bh + BOUNDS_MARGIN

	_target_position.x = clampf(_target_position.x, min_x, max_x)
	_target_position.y = clampf(_target_position.y, min_y, max_y)
