extends "res://scripts/enemy_base.gd"

const SPEED := 360.0
const HITS_TO_KILL := 3
const ROTATION_SPEED := 45.0
const ENTRY_OFFSET := SPEED / (ROTATION_SPEED * PI / 180.0)
const SWAY_SPEED := 2.5
const SWAY_AMOUNT := 100.0

const TEXTURE_NORMAL := preload("res://sprites/enemies/enemy3.png")
const TEXTURE_HIT := preload("res://sprites/enemies/enemy3_hit.png")

enum Side { LEFT, RIGHT }
enum State { DESCENDING, ROTATING, FLYING, ROTATING_AGAIN, DIAGONAL }

var state: int = State.DESCENDING
var spawn_side: int = Side.LEFT
var _has_fired := false

var _target_angle: float = 0.0
var _rotation_direction: float = 0.0
var _is_far_side := false
var _sway_timer: float = 0.0
var _half_width: float = 0.0
var _spawn_visible_left: float = 0.0
var _spawn_visible_right: float = 0.0
var _spawn_visible_center_x: float = 0.0

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	hits_remaining = HITS_TO_KILL
	add_to_group("enemy3")

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		var sprite_size := sprite.texture.get_size() * sprite.scale
		_shared_shape.size = Vector2(sprite_size.x * 0.6, sprite_size.y * 0.9)

	collision_shape.shape = _shared_shape

	var screen_size := ScreenBounds.size
	var half_width := sprite.texture.get_size().x * sprite.scale.x / 2.0
	_half_width = half_width
	_spawn_visible_left = ScreenBounds.visible_left()
	_spawn_visible_right = ScreenBounds.visible_right()
	_spawn_visible_center_x = ScreenBounds.visible_center_x()
	if spawn_side == Side.LEFT:
		position.x = randf_range(_spawn_visible_left + half_width, _spawn_visible_center_x - half_width)
	else:
		position.x = randf_range(_spawn_visible_center_x + half_width, _spawn_visible_right - half_width)
	position.y = -50


func _process(delta: float) -> void:
	var player := Player.instance
	var screen_size := ScreenBounds.size

	match state:
		State.DESCENDING:
			position.y += SPEED * delta
			_sway_timer += delta
			position.x += sin(_sway_timer * SWAY_SPEED) * SWAY_AMOUNT * delta
			position.x = clamp(position.x, _half_width, ScreenBounds.play_size.x - _half_width)
			if player and position.y >= player.position.y - ENTRY_OFFSET:
				state = State.ROTATING
				if position.x > player.position.x:
					_rotation_direction = 1.0
					_target_angle = 90.0
				else:
					_rotation_direction = -1.0
					_target_angle = -90.0

		State.ROTATING:
			_rotate_toward_target(delta)

		State.FLYING:
			var forward := Vector2(0, 1).rotated(rotation)
			position += forward * SPEED * delta
			if _is_far_side:
				if (forward.x > 0 and position.x >= _spawn_visible_center_x) \
						or (forward.x < 0 and position.x <= _spawn_visible_center_x):
					_target_angle = rad_to_deg(rotation) + _rotation_direction * 45.0
					state = State.ROTATING_AGAIN

		State.ROTATING_AGAIN:
			_rotate_toward_target(delta)

		State.DIAGONAL:
			var forward := Vector2(0, 1).rotated(rotation)
			position += forward * SPEED * delta

	if not _has_fired and position.y > 50:
		_has_fired = true
		_fire_bullet()

	_process_flash(delta)

	if position.y > screen_size.y + 200 \
			or position.x < -200 \
			or position.x > ScreenBounds.play_size.x + 200:
		queue_free()


func _rotate_toward_target(delta: float) -> void:
	var forward := Vector2(0, 1).rotated(rotation)
	position += forward * SPEED * delta

	var angle_diff := _target_angle - rad_to_deg(rotation)
	angle_diff = fmod(angle_diff + 540.0, 360.0) - 180.0

	var rotate_step: float = ROTATION_SPEED * delta * sign(angle_diff)
	if abs(rotate_step) >= abs(angle_diff):
		rotation = deg_to_rad(_target_angle)
		match state:
			State.ROTATING:
				_check_side()
				if _is_far_side:
					state = State.FLYING
				else:
					_target_angle = rad_to_deg(rotation) + _rotation_direction * 45.0
					state = State.ROTATING_AGAIN
			State.ROTATING_AGAIN:
				state = State.DIAGONAL
	else:
		rotation += deg_to_rad(rotate_step)


func _check_side() -> void:
	var forward := Vector2(0, 1).rotated(rotation)

	var dist_ahead: float
	var dist_behind: float

	if forward.x > 0:
		dist_ahead = _spawn_visible_right - position.x
		dist_behind = position.x - _spawn_visible_left
	else:
		dist_ahead = position.x - _spawn_visible_left
		dist_behind = _spawn_visible_right - position.x

	_is_far_side = dist_ahead > dist_behind


func _apply_flash_color(flash: bool) -> void:
	sprite.texture = TEXTURE_HIT if flash else TEXTURE_NORMAL


func _fire_bullet() -> void:
	var player := Player.instance
	if not player:
		return
	var spawn_pos := position + Vector2(0, 50)
	var dir := (player.position - spawn_pos).normalized()
	ObjectPool.spawn_enemy_bullet(get_parent(), spawn_pos, dir)
