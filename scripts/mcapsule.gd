extends Area2D

## Collectible capsule that drops from the last enemy2 in a group.
## Alternates between two textures while moving left/right with a slow descent.

const SPEED := 500.0
const ACCEL := 2500.0
const FADE_IN_DELAY := 0.35
const FLASH_INTERVAL := 0.06
const CROSSFADE_DURATION := 0.08
const DESCENT_SPEED := 30.0
const CAMERA_COMPENSATION_FACTOR := 1.0
const TRAIL_MAX_POINTS := 8

const TEXTURE_1 := preload("res://sprites/mcapsule/mcapsule1.png")
const TEXTURE_2 := preload("res://sprites/mcapsule/mcapsule2.png")

var _direction: int = 0
var _velocity: float = 0.0
var _half_width: float = 0.0
var _fade_timer: float = 0.0
var _fading_in := true

var _alt := false
var _hold_timer: float = 0.0
var _crossfade_t: float = 1.0
var _trail_points: Array[Vector2] = []

static var _shared_shape: RectangleShape2D

@onready var sprite_back: Sprite2D = $SpriteBack
@onready var sprite_front: Sprite2D = $SpriteFront
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	process_priority = 20
	add_to_group("mcapsule")
	sprite_back.modulate.a = 0.0
	sprite_front.modulate.a = 0.0
	sprite_back.texture = TEXTURE_1
	sprite_front.texture = TEXTURE_1

	_half_width = sprite_back.texture.get_size().x * sprite_back.scale.x / 2.0

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		_shared_shape.size = sprite_back.texture.get_size() * sprite_back.scale * 0.5

	collision_shape.shape = _shared_shape

	position.x = ScreenBounds.clamp_visible_x(position.x, _half_width)
	var dist_left := position.x - ScreenBounds.visible_left() - _half_width
	var dist_right := ScreenBounds.visible_right() - position.x - _half_width
	_direction = 1 if dist_right > dist_left else -1

	_velocity = _direction * 150.0
	_fade_timer = FADE_IN_DELAY
	_hold_timer = FLASH_INTERVAL
	_crossfade_t = 1.0
	_add_trail_point()

	area_entered.connect(_on_area_entered)

func _on_area_entered(_area: Area2D) -> void:
	if Player.instance:
		InfoLabel.show_info("NOVA SMART BOMB MISSILE")
	GameBus.mcapsule_collected.emit()
	queue_free()


func _process(delta: float) -> void:
	var screen_size := ScreenBounds.size

	# Initial fade-in
	if _fading_in:
		_fade_timer -= delta
		if _fade_timer <= 0.0:
			_fading_in = false
			sprite_back.modulate.a = 1.0

	# Texture alternating
	if _crossfade_t < 1.0:
		_crossfade_t += delta / CROSSFADE_DURATION
		if _crossfade_t >= 1.0:
			_crossfade_t = 1.0
			sprite_back.texture = sprite_front.texture
			sprite_back.modulate.a = sprite_front.modulate.a
			sprite_front.modulate.a = 0.0
			_hold_timer = FLASH_INTERVAL
		else:
			sprite_front.modulate.a = _crossfade_t
	else:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_alt = not _alt
			var tex := TEXTURE_2 if _alt else TEXTURE_1
			sprite_front.texture = tex
			sprite_front.modulate.a = 0.0
			_crossfade_t = 0.0

	# Movement (bounce left/right + slow descent)
	var dist_left := position.x - ScreenBounds.visible_left() - _half_width
	var dist_right := ScreenBounds.visible_right() - position.x - _half_width

	if dist_right < 45.0:
		_direction = -1
	elif dist_left < 45.0:
		_direction = 1

	var target_velocity: float = _direction * SPEED
	_velocity = move_toward(_velocity, target_velocity, ACCEL * delta)

	# Smooth direction change at edge: direction flips at 45px,
	# acceleration smoothly transitions velocity to the opposite side.
	position.x += _velocity * delta + ScreenBounds.camera_delta_x * CAMERA_COMPENSATION_FACTOR
	position.x = ScreenBounds.clamp_visible_x(position.x, _half_width)

	position.y += DESCENT_SPEED * delta
	_add_trail_point()
	queue_redraw()
	if position.y > screen_size.y + 100:
		queue_free()


func _add_trail_point() -> void:
	_trail_points.append(position)
	if _trail_points.size() > TRAIL_MAX_POINTS:
		_trail_points.pop_front()


func _draw() -> void:
	var count := _trail_points.size()
	if count < 2:
		return
	for i in range(count - 1):
		var alpha := float(i + 1) / float(count) * 0.35
		var from_point := _trail_points[i] - position
		var to_point := _trail_points[i + 1] - position
		draw_line(from_point, to_point, Color(0.3, 0.8, 1.0, alpha), 10.0, true)
