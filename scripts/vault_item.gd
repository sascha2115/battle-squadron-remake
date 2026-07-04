extends Area2D

const SPEED := 500.0
const ACCEL := 2500.0
const FADE_IN_DELAY := 0.35
const DEFAULT_DURATION := 0.5
const FLASH_INTERVAL := 0.06   # time each texture is shown at full alpha before crossfading
const CROSSFADE_DURATION := 0.08  # how long the crossfade between textures takes
const DESCENT_SPEED := 30.0   # slow downward drift
const CAMERA_COMPENSATION_FACTOR := 1.0
const TRAIL_MAX_POINTS := 8

const TEXTURE_DEFAULT := preload("res://sprites/vault/vaultitem_default.png")

# Pairs in cycle order: [primary, secondary]
const COLOR_PAIRS: Array = [
	[
		preload("res://sprites/vault/vaultitem_yellow.png"),
		preload("res://sprites/vault/vaultitem_white.png"),
	],
	[
		preload("res://sprites/vault/vaultitem_red.png"),
		preload("res://sprites/vault/vaultitem_orange.png"),
	],
	[
		preload("res://sprites/vault/vaultitem_blue.png"),
		preload("res://sprites/vault/vaultitem_lightblue.png"),
	],
	[
		preload("res://sprites/vault/vaultitem_green.png"),
		preload("res://sprites/vault/vaultitem_lightgreen.png"),
	],
]

var _direction: int = 0
var _velocity: float = 0.0
var _half_width: float = 0.0
var _fade_timer: float = 0.0
var _fading_in := true

var _default_timer: float = DEFAULT_DURATION
var _showing_default := true

var _pair_index: int = 0
var _displayed_pair_index: int = 0  # only updated when crossfade completes — reflects what player sees
var _flash_alt := false         # which texture in the pair is currently the target
var _hold_timer: float = 0.0    # time remaining showing current texture before next crossfade
var _crossfade_t: float = 1.0   # 0..1, 1 = crossfade complete
var _bounce_triggered := false
var _trail_points: Array[Vector2] = []

static var _shared_shape: RectangleShape2D

@onready var sprite_back: Sprite2D = $SpriteBack
@onready var sprite_front: Sprite2D = $SpriteFront
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	process_priority = 20
	add_to_group("vault_item")
	sprite_back.modulate.a = 0.0
	sprite_front.modulate.a = 0.0
	sprite_back.texture = TEXTURE_DEFAULT
	sprite_front.texture = TEXTURE_DEFAULT

	_half_width = sprite_back.texture.get_size().x * sprite_back.scale.x / 2.0

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		_shared_shape.size = sprite_back.texture.get_size() * sprite_back.scale * 0.5

	collision_shape.shape = _shared_shape

	position.x = ScreenBounds.clamp_visible_x(position.x, _half_width)
	var dist_left := position.x - ScreenBounds.visible_left() - _half_width
	var dist_right := ScreenBounds.visible_right() - position.x - _half_width
	_direction = 1 if dist_right > dist_left else -1

	_pair_index = randi() % COLOR_PAIRS.size()
	_displayed_pair_index = _pair_index
	_hold_timer = FLASH_INTERVAL
	_crossfade_t = 1.0

	_fade_timer = FADE_IN_DELAY
	_add_trail_point()
	area_entered.connect(_on_area_entered)


func _on_area_entered(_area: Area2D) -> void:
	if Player.instance:
		Player.instance.apply_bullet_color(_displayed_pair_index)
	queue_free()


func _process(delta: float) -> void:
	var screen_size := ScreenBounds.size

	# Initial fade-in of the whole item
	if _fading_in:
		_fade_timer -= delta
		if _fade_timer <= 0.0:
			_fading_in = false
			sprite_back.modulate.a = 1.0

	# Default texture phase
	if _showing_default:
		_default_timer -= delta
		if _default_timer <= 0.0:
			_showing_default = false
			_start_crossfade_to(_current_target_texture())
	elif _crossfade_t < 1.0:
		# Crossfade in progress: fade front in, back stays
		_crossfade_t += delta / CROSSFADE_DURATION
		if _crossfade_t >= 1.0:
			_crossfade_t = 1.0
			# Crossfade done — promote front to back
			sprite_back.texture = sprite_front.texture
			sprite_back.modulate.a = sprite_front.modulate.a
			sprite_front.modulate.a = 0.0
			_displayed_pair_index = _pair_index
			_hold_timer = FLASH_INTERVAL
		else:
			sprite_front.modulate.a = _crossfade_t
	else:
		# Holding current texture — count down to next flip
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_flash_alt = not _flash_alt
			_start_crossfade_to(_current_target_texture())

	# Movement
	var dist_left := position.x - ScreenBounds.visible_left() - _half_width
	var dist_right := ScreenBounds.visible_right() - position.x - _half_width
	var hitting_edge := dist_right < 45.0 or dist_left < 45.0

	if dist_right < 45.0:
		_direction = -1
	elif dist_left < 45.0:
		_direction = 1

	var prev_velocity := _velocity
	var target_velocity: float = _direction * SPEED
	_velocity = move_toward(_velocity, target_velocity, ACCEL * delta)

	# Trigger color change the frame velocity crosses zero (peak of the bounce)
	if hitting_edge and not _bounce_triggered \
			and not _showing_default \
			and prev_velocity != 0.0 \
			and sign(_velocity) != sign(prev_velocity):
		_bounce_triggered = true
		_pair_index = (_pair_index + 1) % COLOR_PAIRS.size()
		_flash_alt = false
		_start_crossfade_to(_current_target_texture())

	if not hitting_edge:
		_bounce_triggered = false

	position.x += _velocity * delta + ScreenBounds.camera_delta_x * CAMERA_COMPENSATION_FACTOR
	position.x = ScreenBounds.clamp_visible_x(position.x, _half_width)

	position.y += DESCENT_SPEED * delta
	_add_trail_point()
	queue_redraw()
	if position.y > screen_size.y + 100:
		queue_free()


func _current_target_texture() -> Texture2D:
	return COLOR_PAIRS[_pair_index][1 if _flash_alt else 0]


func _start_crossfade_to(tex: Texture2D) -> void:
	sprite_front.texture = tex
	sprite_front.modulate.a = 0.0
	_crossfade_t = 0.0


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
		draw_line(from_point, to_point, Color(1.0, 0.95, 0.25, alpha), 8.0, true)
