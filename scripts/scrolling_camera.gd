extends Camera2D

## Camera catch-up speed in px/s.
const CAMERA_SPEED := 360.0

## Ease-out factor — camera slows down as it approaches target.
## 0.15 = moves 15% of remaining gap per frame (at 60fps).
const EASE_FACTOR := 0.15

var _current_offset_x: float = 0.0

## How much the camera moved this frame — player adds this to stay in screen space.
var delta_x: float = 0.0

# True after the first frame snap has happened
var _snapped := false


func _ready() -> void:
	process_priority = 10
	make_current()
	# Start centered on the play area — no scroll-in
	_current_offset_x = ScreenBounds.max_camera_offset_x() / 2.0
	ScreenBounds.set_camera_offset_x(_current_offset_x)
	position = ScreenBounds.camera_offset + ScreenBounds.size / 2.0


func _process(delta: float) -> void:
	var target := _target_offset_x()

	if not _snapped:
		# On the very first frame, snap to wherever the player actually is
		_current_offset_x = target
		delta_x = 0.0
		_snapped = true
		ScreenBounds.set_camera_offset_x(_current_offset_x)
		position = ScreenBounds.camera_offset + ScreenBounds.size / 2.0
		return

	var prev := _current_offset_x
	var gap := target - _current_offset_x

	# Fixed speed cap + ease-out: take the smaller of the two
	var max_step := CAMERA_SPEED * delta
	var ease_step := absf(gap) * EASE_FACTOR
	var step: float = sign(gap) * minf(max_step, ease_step)
	_current_offset_x += step

	delta_x = _current_offset_x - prev

	ScreenBounds.set_camera_offset_x(_current_offset_x)
	position = ScreenBounds.camera_offset + ScreenBounds.size / 2.0


func _target_offset_x() -> float:
	var player := Player.instance
	if not player:
		return _current_offset_x
	var hw := player.get_sprite_half_width()
	var min_x := hw
	var max_x := ScreenBounds.play_size.x - hw
	if max_x <= min_x:
		return 0.0
	var t := inverse_lerp(min_x, max_x, player.position.x)
	return t * ScreenBounds.max_camera_offset_x()
