extends "res://scripts/enemy_base.gd"

const SPEED := 100.0
const STEP_SIZE := 80.0
const STEP_INTERVAL := 0.7
const MAX_SAME_DIR := 4
const HITS_TO_KILL := 28
const DAMAGE_FRAME_DURATION := 0.04
const DAMAGE_SEQUENCE: Array[int] = [1, 2, 2, 3, 4, 4]
const DAMAGE_DURATION: float = DAMAGE_FRAME_DURATION
const X_SPEED := 80.0
const X_ACCEL := 200.0

const VAULT_ITEM_SCENE := preload("res://scenes/vault_item.tscn")

static var DIRECTIONS: Array[Vector2] = [
	Vector2(-0.70710678, 0.70710678),  # down-left (normalized)
	Vector2(0.0, 1.0),                 # straight down
	Vector2(0.70710678, 0.70710678),   # down-right (normalized)
]

# Start point offsets relative to vault center (fraction of half-width)
const START_OFFSETS: Array[float] = [-0.6, 0.0, 0.6]

# Valid start point indices per direction index:
#   0 (down-left)  -> left(0) or center(1)
#   1 (straight)   -> left(0), center(1), or right(2)
#   2 (down-right) -> center(1) or right(2)
const START_OPTIONS: Array[Array] = [
	[0, 1],
	[0, 1, 2],
	[1, 2],
]

var _half_width: float = 0.0
var _step_timer: float = 0.0
var _direction: int = 1
var _same_dir_count: int = 0
var _target_x: float = 0.0
var _x_velocity: float = 0.0

var _has_entered_screen := false
var _last_directions: Array[int] = [-1, -1]
var _shoot_timer: float = 0.0
var _shoot_step: int = 0

var _damage_active := false
var _damage_index: int = 0
var _damage_timer: float = 0.0

const STAGE_TEXTURES: Array[Texture2D] = [
	preload("res://sprites/vault/vault.png"),
	preload("res://sprites/vault/vault_hit1.png"),
	preload("res://sprites/vault/vault_hit2.png"),
	preload("res://sprites/vault/vault_hit3.png"),
	preload("res://sprites/vault/vault_hit4.png"),
]

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	hits_remaining = HITS_TO_KILL
	add_to_group("vault")

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		var sprite_size := sprite.texture.get_size() * sprite.scale
		_shared_shape.size = Vector2(sprite_size.x * 0.7, sprite_size.y * 0.7)

	collision_shape.shape = _shared_shape
	collision_shape.position = Vector2.ZERO

	_half_width = sprite.texture.get_size().x * sprite.scale.x / 2.0

	var screen_size := ScreenBounds.size
	var visible_left := ScreenBounds.visible_left()
	var visible_right := ScreenBounds.visible_right()
	var center_75_left := visible_left + screen_size.x * 0.125
	var center_75_right := visible_left + screen_size.x * 0.875
	position.x = randf_range(
		maxf(center_75_left, visible_left + _half_width),
		minf(center_75_right, visible_right - _half_width)
	)
	var sprite_height := sprite.texture.get_size().y * sprite.scale.y
	position.y = -sprite_height / 2.0 + 10.0

	_direction = 1 if randi() % 2 == 0 else -1
	_same_dir_count = 0
	_step_timer = randf_range(0.0, STEP_INTERVAL)
	_target_x = position.x


func _process(delta: float) -> void:
	var screen_size := ScreenBounds.size

	position.y += SPEED * delta

	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL

		if _same_dir_count >= MAX_SAME_DIR:
			_direction = -_direction
			_same_dir_count = 0
		elif randi() % 2 == 0:
			_direction = -_direction
			_same_dir_count = 0
		else:
			_same_dir_count += 1

		_target_x = position.x + _direction * STEP_SIZE
		_target_x = clamp(_target_x, _half_width, ScreenBounds.play_size.x - _half_width)

	var diff: float = _target_x - position.x
	var target_velocity: float = clampf(diff * 2.0, -X_SPEED, X_SPEED)
	_x_velocity = move_toward(_x_velocity, target_velocity, X_ACCEL * delta)
	position.x += _x_velocity * delta
	# No pixel snap — smooth movement at all speeds

	if not _has_entered_screen:
		if position.y > 0:
			_has_entered_screen = true
			_shoot_timer = 1.0
	else:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			# Pick a random direction that differs from the last 2 fired
			var available: Array[int] = []
			for idx in 3:
				if idx != _last_directions[0] and idx != _last_directions[1]:
					available.append(idx)

			var chosen_idx := available[randi() % available.size()]
			var dir := DIRECTIONS[chosen_idx]

			# Pick a random valid start point for this direction
			var start_options := START_OPTIONS[chosen_idx]
			var start_offset := START_OFFSETS[start_options[randi() % start_options.size()]] * _half_width
			_fire_vault_bullet(dir, start_offset)

			_last_directions[0] = _last_directions[1]
			_last_directions[1] = chosen_idx

			match _shoot_step:
				0, 1:
					_shoot_timer = 0.5
					_shoot_step += 1
				2:
					_shoot_timer = 1.5
					_shoot_step = 0

	_process_flash(delta)

	if _damage_active:
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_index += 1
			if _damage_index < DAMAGE_SEQUENCE.size():
				sprite.texture = STAGE_TEXTURES[DAMAGE_SEQUENCE[_damage_index]]
				_damage_timer = DAMAGE_DURATION
			else:
				_damage_active = false
				sprite.texture = STAGE_TEXTURES[0]

	if position.y > screen_size.y + 100:
		queue_free()


func _fire_vault_bullet(dir: Vector2, x_offset: float) -> void:
	ObjectPool.spawn_enemy_bullet(get_parent(), position + Vector2(x_offset, 140), dir)


func _apply_flash_color(_flash: bool) -> void:
	pass  # Vault uses its own damage texture progression instead of tint flash.


func _on_player_collision() -> void:
	pass  # Vault is intentionally invulnerable to player contact — suppress base class kill.


func _on_killed() -> void:
	ObjectPool.spawn_explosion(get_parent(), position)
	call_deferred("_spawn_vault_item")
	queue_free()


func _on_damaged() -> void:
	_damage_active = true
	_damage_index = 0
	sprite.texture = STAGE_TEXTURES[DAMAGE_SEQUENCE[0]]
	_damage_timer = DAMAGE_DURATION


func _spawn_vault_item() -> void:
	var item := VAULT_ITEM_SCENE.instantiate()
	item.position = position
	get_parent().add_child(item)
