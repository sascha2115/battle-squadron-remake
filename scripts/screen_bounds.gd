extends Node

## Cached viewport size — updated on resize. Use instead of get_viewport_rect().size.
var size: Vector2 = Vector2(2800, 1684)
var play_size: Vector2 = size
var camera_offset: Vector2 = Vector2.ZERO
var camera_delta_x: float = 0.0

const PLAY_AREA_WIDTH_FACTOR := 1.3333


func _ready() -> void:
	_update_size()
	var viewport := get_viewport()
	if viewport:
		viewport.size_changed.connect(_update_size)
	# Debug: print playfield width after initialization
	print("DEBUG: Virtual playfield width = ", play_size.x, " pixels")
	print("DEBUG: Viewport size = ", size, " pixels")
	print("DEBUG: Max camera offset X = ", max_camera_offset_x(), " pixels")


func _update_size() -> void:
	var viewport := get_viewport()
	if viewport:
		size = viewport.get_visible_rect().size
		play_size = Vector2(round(size.x * PLAY_AREA_WIDTH_FACTOR), size.y)
		set_camera_offset_x(camera_offset.x)


func set_camera_offset_x(value: float) -> void:
	var previous_x := camera_offset.x
	camera_offset.x = clampf(value, 0.0, max_camera_offset_x())
	camera_offset.y = 0.0
	camera_delta_x = camera_offset.x - previous_x


func max_camera_offset_x() -> float:
	return maxf(play_size.x - size.x, 0.0)


func visible_left() -> float:
	return camera_offset.x


func visible_right() -> float:
	return camera_offset.x + size.x


func visible_center_x() -> float:
	return camera_offset.x + size.x / 2.0


func clamp_visible_x(x: float, half_width: float = 0.0) -> float:
	return clampf(x, visible_left() + half_width, visible_right() - half_width)


func random_visible_x(half_width: float = 0.0) -> float:
	var left := visible_left() + half_width
	var right := visible_right() - half_width
	if right <= left:
		return (left + right) / 2.0
	return randf_range(left, right)
