extends "res://scripts/enemy_base.gd"

const SPEED := 520.0
const ROTATION_SPEED := 65.0
const STRAIGHT_DOWN_DISTANCE := 260.0
const HITS_TO_KILL := 1
const MCAPSULE_SCENE := preload("res://scenes/mcapsule.tscn")

enum State { ENTERING, ROTATING, STRAIGHT_DOWN, ROTATING_2, EXITING }

var state: int = State.ENTERING
var spawn_side: int
var formation_y: float = 0.0
var formation_index: int = 0
var formation_visible_left: float = -1.0

var _target_angle: float = 0.0
var _rotation_direction: float = 0.0
var _turn_start_x: float = 0.0
var _straight_down_start_y: float = 0.0

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _on_killed() -> void:
	# Remove from group immediately so the check below isn't fooled
	# by other enemy2 that also queue_free()'d this frame (queue_free
	# does not remove nodes from groups until end of frame).
	remove_from_group("enemy2")
	var remaining := get_tree().get_nodes_in_group("enemy2")
	if remaining.is_empty():
		_spawn_mcapsule_deferred()
	super._on_killed()


func _spawn_mcapsule_deferred() -> void:
	var mcapsule := MCAPSULE_SCENE.instantiate()
	mcapsule.position = position
	get_parent().call_deferred("add_child", mcapsule)


func _ready() -> void:
	super._ready()
	hits_remaining = HITS_TO_KILL
	add_to_group("enemy2")

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		var sprite_size := sprite.texture.get_size() * sprite.scale
		_shared_shape.size = Vector2(sprite_size.x * 0.8, sprite_size.y * 0.8)

	collision_shape.shape = _shared_shape

	var screen_size := ScreenBounds.size
	var visible_left := formation_visible_left if formation_visible_left >= 0.0 else ScreenBounds.visible_left()
	var visible_right := visible_left + screen_size.x
	const FORMATION_SPACING := 180.0

	if spawn_side == -1:
		position = Vector2(visible_left - 50 - formation_index * FORMATION_SPACING, formation_y)
		rotation = deg_to_rad(-90.0)
		_turn_start_x = visible_left + screen_size.x * 0.65
	else:
		position = Vector2(visible_right + 50 + formation_index * FORMATION_SPACING, formation_y)
		rotation = deg_to_rad(90.0)
		_turn_start_x = visible_left + screen_size.x * 0.35


func _process(delta: float) -> void:
	match state:
		State.ENTERING:
			if spawn_side == -1:
				position.x += SPEED * delta
			else:
				position.x -= SPEED * delta

			if spawn_side == -1 and position.x >= _turn_start_x:
				state = State.ROTATING
				_target_angle = 0.0
				_rotation_direction = 1.0
			elif spawn_side == 1 and position.x <= _turn_start_x:
				state = State.ROTATING
				_target_angle = 0.0
				_rotation_direction = -1.0

		State.ROTATING:
			var forward := Vector2(0, 1).rotated(rotation)
			position += forward * SPEED * delta

			var rotate_step: float = ROTATION_SPEED * delta * _rotation_direction
			var current_deg := rad_to_deg(rotation)
			if _rotation_direction > 0.0 and current_deg + rotate_step >= _target_angle:
				rotation = deg_to_rad(_target_angle)
				state = State.STRAIGHT_DOWN
				_straight_down_start_y = position.y
			elif _rotation_direction < 0.0 and current_deg + rotate_step <= _target_angle:
				rotation = deg_to_rad(_target_angle)
				state = State.STRAIGHT_DOWN
				_straight_down_start_y = position.y
			else:
				rotation += deg_to_rad(rotate_step)

		State.STRAIGHT_DOWN:
			position.y += SPEED * delta
			if position.y - _straight_down_start_y >= STRAIGHT_DOWN_DISTANCE:
				state = State.ROTATING_2
				if spawn_side == -1:
					_target_angle = 90.0
					_rotation_direction = 1.0
				else:
					_target_angle = -90.0
					_rotation_direction = -1.0

		State.ROTATING_2:
			var forward := Vector2(0, 1).rotated(rotation)
			position += forward * SPEED * delta

			var rotate_step: float = ROTATION_SPEED * delta * _rotation_direction
			var current_deg := rad_to_deg(rotation)
			if _rotation_direction > 0.0 and current_deg + rotate_step >= _target_angle:
				rotation = deg_to_rad(_target_angle)
				state = State.EXITING
			elif _rotation_direction < 0.0 and current_deg + rotate_step <= _target_angle:
				rotation = deg_to_rad(_target_angle)
				state = State.EXITING
			else:
				rotation += deg_to_rad(rotate_step)

		State.EXITING:
			var forward := Vector2(0, 1).rotated(rotation)
			position += forward * SPEED * delta

	_process_flash(delta)

	var screen_size := ScreenBounds.size
	if state != State.ENTERING and (
			position.x < -200 or position.x > ScreenBounds.play_size.x + 200
			or position.y < -200 or position.y > screen_size.y + 200
	):
		queue_free()
