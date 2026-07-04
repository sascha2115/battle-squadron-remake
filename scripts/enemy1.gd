extends "res://scripts/enemy_base.gd"

const SPEED := 360.0
const X_SPEED_BASE := 150.0
const X_SPEED_MAX := 400.0
const HITS_TO_KILL := 3

const TILT_SPEED := 180.0
const TILT_AMOUNT := 25.0

const TEXTURE_NORMAL := preload("res://sprites/enemies/enemy1.png")
const TEXTURE_HIT := preload("res://sprites/enemies/enemy1_hit.png")

var _has_entered := false
var _has_fired := false
var _fire_timer: float = 0.0
var _half_width: float = 0.0
var _horizontal_direction: float = 0.0
var _velocity_x: float = 0.0

var _is_swaying := false
var _sway_phase: float = 0.0
var _sway_center_x: float = 0.0
const SWAY_AMPLITUDE := 100.0
const SWAY_SPEED := 2.5

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite3d: Sprite3D = $SubViewport/Node3D/Sprite3D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	hits_remaining = HITS_TO_KILL
	add_to_group("enemy1")

	# Compute the final screen size of the enemy using the 3D pipeline math.
	var source_tex := sprite3d.texture as Texture2D
	var tex_size := source_tex.get_size()
	var pixel_size := sprite3d.pixel_size
	var cam := $SubViewport/Camera3D as Camera3D
	var viewport_height_3d := 2.0 * cam.position.z * tan(deg_to_rad(cam.fov) / 2.0)
	var viewport_height_px := float($SubViewport.size.y)
	var scale_3d_to_viewport := viewport_height_px / viewport_height_3d
	var final_scale := scale_3d_to_viewport * pixel_size * sprite.scale.x

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		_shared_shape.size = Vector2(tex_size.x * final_scale * 0.7, tex_size.y * final_scale * 0.7)

	collision_shape.shape = _shared_shape
	collision_shape.position = Vector2.ZERO

	_half_width = tex_size.x * final_scale / 2.0
	position = Vector2(
		ScreenBounds.random_visible_x(_half_width),
		-50
	)


func _process(delta: float) -> void:
	var player := Player.instance
	var screen_size := ScreenBounds.size

	if player:
		position.y += SPEED * delta

		var player_moved := player.last_input_x != 0.0

		if _is_swaying:
			if player_moved:
				_is_swaying = false
			else:
				_sway_phase += SWAY_SPEED * delta
				var sway_offset := sin(_sway_phase) * SWAY_AMPLITUDE
				position.x = _sway_center_x + sway_offset
				position.x = clamp(position.x, _half_width, ScreenBounds.play_size.x - _half_width)
				_horizontal_direction = sign(cos(_sway_phase))

		if not _is_swaying:
			var x_difference := player.position.x - position.x
			var target_velocity_x: float = clampf(x_difference * 5.0, -X_SPEED_MAX, X_SPEED_MAX)
			_velocity_x = move_toward(_velocity_x, target_velocity_x, 800.0 * delta)

			if abs(x_difference) < 2.0 and not player_moved:
				_is_swaying = true
				_sway_center_x = player.position.x
				_sway_phase = 0.0
				_horizontal_direction = sign(_velocity_x) if abs(_velocity_x) > 1.0 else 1.0
			else:
				position.x += _velocity_x * delta

			_horizontal_direction = sign(_velocity_x) if abs(_velocity_x) > 1.0 else 0.0
			position.x = clamp(position.x, _half_width, ScreenBounds.play_size.x - _half_width)

	# 3D tilt based on horizontal movement direction
	var target_rotation := _horizontal_direction * TILT_AMOUNT
	sprite3d.rotation_degrees.y = move_toward(sprite3d.rotation_degrees.y, target_rotation, TILT_SPEED * delta)

	if not _has_entered and position.y > 0:
		_has_entered = true
		_fire_timer = randf_range(0.1, 0.7)
	if _has_entered and not _has_fired:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_has_fired = true
			_fire_bullet()

	_process_flash(delta)
	

	if position.y > screen_size.y + 100:
		queue_free()


func _apply_flash_color(flash: bool) -> void:
	sprite3d.texture = TEXTURE_HIT if flash else TEXTURE_NORMAL


func _fire_bullet() -> void:
	var player := Player.instance
	if not player:
		return
	var dir := (player.position - (position + Vector2(0, 50))).normalized()
	ObjectPool.spawn_enemy_bullet(get_parent(), position + Vector2(0, 50), dir)
