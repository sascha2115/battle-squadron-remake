extends "res://scripts/enemy_base.gd"

const SPEED := 400.0
const HITS_TO_KILL := 3
const FADE_SPEED := 2.5  # How fast it fades in/out (cycles per second)
const ROTATION_SPEED := 90.0  # Degrees per second

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _fade_time: float = 0.0
var _target_rotation: float = 0.0  # Target angle in degrees (-45 or +45)

func _ready() -> void:
	super._ready()
	hits_remaining = HITS_TO_KILL
	add_to_group("enemy4")
	
	# Set up sprite - use enemy2's sprite
	sprite.texture = preload("res://sprites/enemies/enemy2.png")
	
	# Create collision shape (same as enemy2)
	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		var sprite_size := sprite.texture.get_size() * sprite.scale
		_shared_shape.size = Vector2(sprite_size.x * 0.8, sprite_size.y * 0.8)
	collision_shape.shape = _shared_shape
	
	# Determine spawn side (left third or right third of VISIBLE screen, never middle)
	var visible_width := ScreenBounds.visible_right() - ScreenBounds.visible_left()
	var third_width := visible_width / 3.0
	var spawn_left_side := randi() % 2 == 0
	
	# Spawn just above the visible screen
	var spawn_x: float
	if spawn_left_side:
		spawn_x = ScreenBounds.visible_left() + randf() * third_width
	else:
		spawn_x = ScreenBounds.visible_left() + third_width * 2.0 + randf() * third_width
	
	position = Vector2(spawn_x, -50)
	
	# Set initial direction toward player (45° diagonal)
	_update_direction_toward_player()
	
	# Start fully transparent
	sprite.modulate.a = 0.0


func _on_player_collision() -> void:
	# Override base behavior: enemy4 does NOT explode on player collision
	pass


func _update_direction_toward_player() -> void:
	# Determine if player is to the left or right
	var player := Player.instance
	if not player:
		return
	
	var direction_to_player := player.position.x - position.x
	if direction_to_player < 0:
		# Player is to the left, go down-left
		_target_rotation = deg_to_rad(45.0)
	else:
		# Player is to the right, go down-right
		_target_rotation = deg_to_rad(-45.0)


func _process(delta: float) -> void:
	# Update direction toward player (check if we need to switch diagonal)
	_update_direction_toward_player()
	
	# Smoothly rotate toward target angle
	var current_rot := rotation
	var angle_diff := _target_rotation - current_rot
	
	# Normalize angle difference to [-PI, PI]
	while angle_diff > PI:
		angle_diff -= 2.0 * PI
	while angle_diff < -PI:
		angle_diff += 2.0 * PI
	
	# Rotate toward target
	if abs(angle_diff) > 0.01:
		var rotate_step: float = sign(angle_diff) * deg_to_rad(ROTATION_SPEED) * delta
		rotation += clamp(rotate_step, -abs(angle_diff), abs(angle_diff))
	
	# Move in the current facing direction
	var forward := Vector2(0, 1).rotated(rotation)
	position += forward * SPEED * delta
	
	# Handle fade in/out (faster than before: 2.5 cycles/sec)
	_fade_time += delta * FADE_SPEED
	var alpha := (sin(_fade_time * PI * 2.0) + 1.0) / 2.0  # Oscillates between 0 and 1
	
	# Process flash (may set modulate to green)
	_process_flash(delta)
	
	# Apply fade alpha while preserving any flash color
	if _is_flashing:
		# Flash is active, preserve the green color but update alpha
		var current_color := sprite.modulate
		current_color.a = alpha
		sprite.modulate = current_color
	else:
		# No flash, just set alpha
		sprite.modulate.a = alpha
	
	# Remove when off screen
	var screen_size := ScreenBounds.size
	if position.y > screen_size.y + 100 or position.x < -100 or position.x > screen_size.x + 100:
		queue_free()