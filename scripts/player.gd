extends Area2D
class_name Player

static var instance: Player = null

const SPEED_X := 1500.0
const SPEED_Y := 1125.0
const ACCEL_X := 20000.0
const PAUSE_KEY := KEY_P
const FLASH_DURATION := 0.15
# Fire interval per weapon level (0=base, 1, 2, 3, 4=max)
const FIRE_INTERVALS: Array[float] = [0.1, 0.15, 0.2, 0.25, 0.3]

# Tilt animation frames
const TILT_FRAMES_LEFT: Array[Texture2D] = [
	preload("res://sprites/player/player_left1.png"),
	preload("res://sprites/player/player_left2.png"),
	preload("res://sprites/player/player_left3.png"),
]
const TILT_FRAMES_RIGHT: Array[Texture2D] = [
	preload("res://sprites/player/player_right1.png"),
	preload("res://sprites/player/player_right2.png"),
	preload("res://sprites/player/player_right3.png"),
]
const TILT_TIME_1 := 0.04
const TILT_TIME_2 := 0.12

# Weapon names indexed by pair (matches COLOR_PAIRS order in vault_item.gd):
# 0=yellow/white, 1=red/orange, 2=darkblue/lightblue, 3=darkgreen/lightgreen
const WEAPON_NAMES := [
	"ORANGE MAGMA WAVE",
	"RED MAGNETIC TORPS",
	"BLUE ANTI-MATTER PARTICLE BEAM",
	"GREEN EMERALD LASER",
]

# Bullet scales per weapon
const ORANGE_SCALE    := Vector2(0.25, 0.25)
const ORANGE_SCALE_S  := Vector2(0.22, 0.22)  # small second volley
const ORANGE_SCALE_ORB := Vector2(0.27, 0.32)
const RED_SCALE       := Vector2(0.225, 0.225)
const RED_SCALE_BIG   := Vector2(0.33, 0.33)   # big bullets (levels 3-5)
const BLUE_SCALE      := Vector2(0.4, 0.45)
const BLUE_SCALE_L2   := Vector2(0.5, 0.5)
const GREEN_SCALE     := Vector2(0.5, 0.5)
const GREEN_SCALE_BIGGER := Vector2(0.7, 0.7)

@onready var sprite_2d: Sprite2D = $Sprite2D

var _camera: Camera2D = null

var last_input_x: float = 0.0
var last_input_y: float = 0.0

var _velocity_x: float = 0.0
var _flash_timer: float = 0.0
var _is_flashing: bool = false
var _fire_cooldown: float = 0.0
var _sprite_height: float = 0.0
var _sprite_width: float = 0.0
var _neutral_texture: Texture2D
var _tilt_time: float = 0.0
var _tilt_direction: float = 0.0
var _current_pair_index: int = 0
var _weapon_levels: Array[int] = [0, 0, 0, 0]


func _ready() -> void:
	instance = self
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 20

	_neutral_texture = sprite_2d.texture

	var tex_size := sprite_2d.texture.get_size() * sprite_2d.scale
	_sprite_height = tex_size.y
	_sprite_width = tex_size.x

	_current_pair_index = 0
	_camera = get_viewport().get_camera_2d()

	call_deferred("_center_bottom")
	area_entered.connect(_on_area_entered)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _center_bottom() -> void:
	position = Vector2(
		ScreenBounds.visible_center_x(),
		ScreenBounds.size.y - _sprite_height / 2.0
	)


func _process(delta: float) -> void:
	if get_tree().paused:
		# Only continue processing flash timer while paused
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _is_flashing:
			_is_flashing = false
			_set_flash_visual(false)
		return

	var screen_size := ScreenBounds.size

	var input_x := Input.get_axis("left", "right")
	var input_y := Input.get_axis("up", "down")
	last_input_x = input_x
	last_input_y = input_y

	# Horizontal movement with acceleration; stops instantly on release
	if input_x != 0:
		var target_vx := input_x * SPEED_X
		_velocity_x = move_toward(_velocity_x, target_vx, ACCEL_X * delta)
	else:
		_velocity_x = 0.0

	position.x += _velocity_x * delta

	# Compensate for camera scrolling — player stays fixed in screen space
	if _camera:
		position.x += _camera.get("delta_x") as float

	# Vertical movement remains instant / responsive
	position.y += input_y * SPEED_Y * delta

	# Clamp to visible area (screen space) so player never leaves the viewport
	position.x = clamp(position.x, ScreenBounds.visible_left() + _sprite_width / 2.0, ScreenBounds.visible_right() - _sprite_width / 2.0)
	position.y = clamp(position.y, _sprite_height / 2.0, screen_size.y - _sprite_height / 2.0)

	# Skew disabled – sprite stays upright (keep this line if re-enabling skew tilt)
	# sprite_2d.skew = 0.0

	# Track how long the player has been moving in the same direction
	if input_x != 0:
		if input_x == _tilt_direction:
			_tilt_time += delta
		else:
			_tilt_time = 0.0
			_tilt_direction = input_x
	else:
		_tilt_time = 0.0
		_tilt_direction = 0.0

	# Tilt animation based on duration in same direction
	_update_tilt_sprite()

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	if _flash_timer > 0.0:
		_flash_timer -= delta
		_set_flash_visual(true)
	elif _is_flashing:
		_is_flashing = false
		_set_flash_visual(false)


func _update_tilt_sprite() -> void:
	if _tilt_direction == 0:
		sprite_2d.texture = _neutral_texture
	elif _tilt_direction < 0:
		# Moving left
		if _tilt_time > TILT_TIME_2:
			sprite_2d.texture = TILT_FRAMES_LEFT[2]
		elif _tilt_time > TILT_TIME_1:
			sprite_2d.texture = TILT_FRAMES_LEFT[1]
		else:
			sprite_2d.texture = TILT_FRAMES_LEFT[0]
	else:
		# Moving right
		if _tilt_time > TILT_TIME_2:
			sprite_2d.texture = TILT_FRAMES_RIGHT[2]
		elif _tilt_time > TILT_TIME_1:
			sprite_2d.texture = TILT_FRAMES_RIGHT[1]
		else:
			sprite_2d.texture = TILT_FRAMES_RIGHT[0]


func get_sprite_half_width() -> float:
	return _sprite_width / 2.0


# Returns the correct bullet cycle array for a given weapon pair and level.
func _weapon_cycle(pair: int, level: int) -> Array[Texture2D]:
	match pair:
		0: return BulletConfig.ORANGE_CYCLE_LEVEL2 if level >= 1 else BulletConfig.ORANGE_CYCLE
		1: return BulletConfig.RED_CYCLE
		2: return BulletConfig.BLUE_CYCLE_LEVEL2 if level >= 1 else BulletConfig.BLUE_CYCLE
		3: return BulletConfig.GREEN_CYCLE_MIDDLE
	return BulletConfig.ORANGE_CYCLE


func _set_flash_visual(flash: bool) -> void:
	sprite_2d.modulate = Color(0.4, 1.0, 0.4) if flash else Color.WHITE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == PAUSE_KEY:
		get_tree().paused = not get_tree().paused
		return

	if get_tree().paused:
		return

	if event.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_fire_bullet()
		_fire_cooldown = _get_fire_interval()
	elif event.is_action_pressed("quit"):
		get_tree().quit()

	# Debug weapon selection via number keys
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_debug_select_weapon(0)
			KEY_2:
				_debug_select_weapon(1)
			KEY_3:
				_debug_select_weapon(2)
			KEY_4:
				_debug_select_weapon(3)


func _fire_bullet() -> void:
	match _current_pair_index:
		0: _fire_orange()
		1: _fire_red()
		2: _fire_blue()
		3: _fire_green()


# ---------------------------------------------------------------------------
# Helper: fire one bullet from a BulletConfig
# ---------------------------------------------------------------------------
func _shoot(offset: Vector2, cfg: BulletConfig.BulletData) -> void:
	ObjectPool.spawn_player_bullet(get_parent(), position + offset, cfg)


# ---------------------------------------------------------------------------
# Helper: build a direction vector from degrees off straight-up
# ---------------------------------------------------------------------------
static func _deg_dir(deg: float) -> Vector2:
	var r := deg * PI / 180.0
	return Vector2(sin(r), -cos(r)).normalized()


# ---------------------------------------------------------------------------
# ORANGE MAGMA WAVE
# ---------------------------------------------------------------------------
func _fire_orange() -> void:
	var lvl := _weapon_levels[0]
	var cycle := _weapon_cycle(0, lvl)
	var speed := 2800.0 if lvl >= 1 else 2400.0
	var cs := randi() % 3

	if lvl >= 4:  # level 5: 3 volleys
		# Volley 1: 2 swerving big bullets (same as level 2)
		var swerve_amp: float = [40.0, 80.0][randi() % 2]
		var swerve_freq: float = [30.0, 35.0, 40.0][randi() % 3]
		var swerve_off: float = [0.6, 1.0][randi() % 2]
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = cycle
			cfg.direction = _deg_dir(i * 6.0)
			cfg.speed = speed
			cfg.scale = Vector2(0.35, 0.35)
			cfg.cycle_start = cs
			cfg.double_damage = true
			cfg.swerve_phase = float(i)
			cfg.swerve_start_offset = swerve_off
			cfg.swerve_amplitude = swerve_amp
			cfg.swerve_frequency = swerve_freq
			_shoot(Vector2(i * 40.0, -160), cfg)
		# Volley 2: 2 orb bullets with slight angle
		_fire_orange_orb_volley(speed, cs, 6.0, 55.0, 0.09)
		# Volley 3: 2 orb bullets straight up
		_fire_orange_orb_volley(speed, cs, 0.0, 55.0, 0.17)
	elif lvl >= 3:  # level 4: 2 volleys of orb bullets (swerving + angled)
		var swerve_amp: float = [40.0, 80.0][randi() % 2]
		var swerve_freq: float = [30.0, 35.0, 40.0][randi() % 3]
		var swerve_off: float = [0.6, 1.0][randi() % 2]
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = BulletConfig.ORANGE_CYCLE_ORB
			cfg.direction = _deg_dir(i * 6.0)
			cfg.speed = speed
			cfg.scale = ORANGE_SCALE_ORB
			cfg.cycle_start = cs
			cfg.double_damage = true
			cfg.swerve_phase = float(i)
			cfg.swerve_start_offset = swerve_off
			cfg.swerve_amplitude = swerve_amp
			cfg.swerve_frequency = swerve_freq
			_shoot(Vector2(i * 40.0, -160), cfg)
		_fire_orange_orb_delayed(speed, cs)
	elif lvl >= 1:  # level 2 + 3: swerving big bullets
		var swerve_amp: float = [40.0, 80.0][randi() % 2]
		var swerve_freq: float = [30.0, 35.0, 40.0][randi() % 3]
		var swerve_off: float = [0.6, 1.0][randi() % 2]
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = cycle
			cfg.speed = speed
			cfg.scale = ORANGE_SCALE
			cfg.cycle_start = cs
			cfg.double_damage = lvl >= 2
			cfg.swerve_phase = float(i)
			cfg.swerve_start_offset = swerve_off
			cfg.swerve_amplitude = swerve_amp
			cfg.swerve_frequency = swerve_freq
			_shoot(Vector2(i * 40.0, -160), cfg)
		if lvl >= 2:  # level 3: extra small volley after 80ms
			_fire_orange_small_delayed(speed, cs)
	else:  # level 1: 2 small straight bullets
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = cycle
			cfg.speed = speed
			cfg.scale = ORANGE_SCALE_S
			cfg.cycle_start = cs
			_shoot(Vector2(i * 40.0, -160), cfg)


func _fire_orange_orb_volley(speed: float, cs: int, angle: float, x_offset: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.ORANGE_CYCLE_ORB
		cfg.direction = _deg_dir(i * angle)
		cfg.speed = speed
		cfg.scale = ORANGE_SCALE_ORB
		cfg.cycle_start = cs
		cfg.double_damage = true
		cfg.cycle_time_offset = delay
		_shoot(Vector2(i * x_offset, -160), cfg)


func _fire_orange_orb_delayed(speed: float, cs: int) -> void:
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.ORANGE_CYCLE_ORB
		cfg.direction = _deg_dir(i * 6.0)
		cfg.speed = speed
		cfg.scale = ORANGE_SCALE_ORB
		cfg.cycle_start = cs
		cfg.double_damage = true
		cfg.cycle_time_offset = 0.08
		_shoot(Vector2(i * 55.0, -160), cfg)


func _fire_orange_small_delayed(speed: float, cs: int) -> void:
	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.ORANGE_CYCLE
		cfg.speed = speed
		cfg.scale = ORANGE_SCALE_S
		cfg.cycle_start = cs
		cfg.cycle_time_offset = 0.08
		_shoot(Vector2(i * 55.0, -160), cfg)


# ---------------------------------------------------------------------------
# RED MAGNETIC TORPS
# ---------------------------------------------------------------------------
func _fire_red() -> void:
	var lvl := _weapon_levels[1]
	var cycle := _weapon_cycle(1, lvl)
	var speed := 2400.0 + lvl * 200.0  # 2400→2600→2800→3000→3200
	var cs := randi() % 3

	if lvl >= 4:  # level 5: 3 volleys, all 3 volleys big (6 big bullets)
		_fire_red_volley(cycle, [-8.0, 8.0],   [-30.0, 30.0],  speed, RED_SCALE_BIG, cs, true,  0.0)
		_fire_red_volley_delayed(cycle, [-25.0, 25.0], [-55.0, 55.0], speed, RED_SCALE_BIG, cs, 0.02, true)
		_fire_red_volley_delayed(cycle, [-40.0, 40.0], [-80.0, 80.0], speed, RED_SCALE_BIG, cs, 0.05, true)
	elif lvl >= 3:  # level 4: 3 volleys, first TWO are big (4 big bullets)
		_fire_red_volley(cycle, [-8.0, 8.0],   [-30.0, 30.0],  speed, RED_SCALE_BIG, cs, true,  0.0)
		_fire_red_volley_delayed(cycle, [-25.0, 25.0], [-55.0, 55.0], speed, RED_SCALE_BIG, cs, 0.02, true)
		_fire_red_volley_delayed(cycle, [-40.0, 40.0], [-80.0, 80.0], speed, RED_SCALE, cs, 0.05)
	elif lvl >= 2:  # level 3: 3 volleys, first uses bigger scale (double damage)
		_fire_red_volley(cycle, [-8.0, 8.0],   [-30.0, 30.0],  speed, RED_SCALE_BIG, cs, true,  0.0)
		_fire_red_volley_delayed(cycle, [-25.0, 25.0], [-55.0, 55.0], speed, RED_SCALE, cs, 0.02)
		_fire_red_volley_delayed(cycle, [-40.0, 40.0], [-80.0, 80.0], speed, RED_SCALE, cs, 0.05)
	elif lvl >= 1:  # level 2: 3 volleys, all normal scale
		_fire_red_volley(cycle, [-8.0, 8.0],   [-30.0, 30.0],  speed, RED_SCALE, cs, false, 0.0)
		_fire_red_volley_delayed(cycle, [-25.0, 25.0], [-55.0, 55.0], speed, RED_SCALE, cs, 0.02)
		_fire_red_volley_delayed(cycle, [-40.0, 40.0], [-80.0, 80.0], speed, RED_SCALE, cs, 0.05)
	else:  # level 1: 2 volleys
		_fire_red_volley(cycle, [-10.0, 10.0], [-30.0, 30.0],  speed, RED_SCALE, cs, false, 0.0)
		_fire_red_volley_delayed(cycle, [-30.0, 30.0], [-80.0, 80.0], speed, RED_SCALE, cs, 0.045)


func _fire_red_volley(cycle: Array[Texture2D], angles: Array, x_offsets: Array, speed: float, scale: Vector2, cs: int, double_dmg: bool, time_offset: float) -> void:
	for i in angles.size():
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = cycle
		cfg.direction = _deg_dir(angles[i])
		cfg.speed = speed
		cfg.scale = scale
		cfg.cycle_start = cs
		cfg.cycle_time_offset = time_offset
		cfg.double_damage = double_dmg
		_shoot(Vector2(x_offsets[i], -120), cfg)


func _fire_red_volley_delayed(cycle: Array[Texture2D], angles: Array, x_offsets: Array, speed: float, scale: Vector2, cs: int, delay: float, double_dmg: bool = false) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	_fire_red_volley(cycle, angles, x_offsets, speed, scale, cs, double_dmg, delay)


# ---------------------------------------------------------------------------
# BLUE ANTI-MATTER PARTICLE BEAM
# ---------------------------------------------------------------------------
func _fire_blue() -> void:
	var lvl := _weapon_levels[2]
	var cycle := _weapon_cycle(2, lvl)
	var speed := 2600.0 if lvl >= 1 else 2400.0
	var spacing := 70.0 if lvl >= 1 else 50.0
	var cs := randi() % 3

	if lvl >= 1:  # level 2 + 3: big bullets straight up (double damage)
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = cycle
			cfg.speed = speed
			cfg.scale = BLUE_SCALE_L2
			cfg.cycle_start = cs
			cfg.double_damage = true
			if lvl >= 3:  # level 4+: big bullets go slightly outward
				cfg.direction = _deg_dir(i * 6.0)
			_shoot(Vector2(i * spacing, -195), cfg)
		if lvl >= 4:  # level 5: 2 big backward bullets (same as forward, mirrored)
			for i in [-1, 1]:
				var cfg_b := BulletConfig.BulletData.new()
				cfg_b.cycle = BulletConfig.BLUE_CYCLE
				cfg_b.speed = speed
				cfg_b.scale = Vector2(BLUE_SCALE_L2.x, -BLUE_SCALE_L2.y)
				cfg_b.cycle_start = cs
				cfg_b.double_damage = true
				cfg_b.direction = Vector2(sin(i * 6.0 * PI / 180.0), cos(i * 6.0 * PI / 180.0)).normalized()
				_shoot(Vector2(i * spacing, 195), cfg_b)
			_fire_blue_back_small_delayed(speed, cs)
		elif lvl >= 2:  # level 3: additional backward bullets (2 small)
			_fire_blue_backward(speed, spacing, cs)
		if lvl >= 3:  # level 3+: extra small blue bullet forward (upward), slightly delayed
			_fire_blue_small_delayed(speed, cs)
	else:  # level 1: 2 bullets with slight outward angle
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = cycle
			cfg.direction = _deg_dir(i * 6.0)
			cfg.speed = speed
			cfg.scale = BLUE_SCALE
			cfg.cycle_start = cs
			_shoot(Vector2(i * spacing, -160), cfg)


func _fire_blue_small_delayed(speed: float, cs: int) -> void:
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	var cfg_small := BulletConfig.BulletData.new()
	cfg_small.cycle = BulletConfig.BLUE_CYCLE
	cfg_small.speed = speed
	cfg_small.scale = BLUE_SCALE
	cfg_small.cycle_start = cs
	_shoot(Vector2(0, -195), cfg_small)


func _fire_blue_back_small_delayed(speed: float, cs: int) -> void:
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	var cfg_small := BulletConfig.BulletData.new()
	cfg_small.cycle = BulletConfig.BLUE_CYCLE
	cfg_small.speed = speed
	cfg_small.scale = BLUE_SCALE
	cfg_small.cycle_start = cs
	cfg_small.direction = Vector2(0, 1)
	cfg_small.scale = Vector2(BLUE_SCALE.x, -BLUE_SCALE.y)
	_shoot(Vector2(0, 195), cfg_small)


func _fire_blue_backward(speed: float, spacing: float, cs: int) -> void:
	# Backward bullets fire downward at a slight outward angle
	for i in [-1, 1]:
		var r: float = i * 6.0 * PI / 180.0
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.BLUE_CYCLE
		cfg.direction = Vector2(sin(r), cos(r)).normalized()  # downward, slight outward spread
		cfg.speed = speed
		cfg.scale = Vector2(0.4, -0.45)
		cfg.cycle_start = cs
		_shoot(Vector2(i * spacing, 160), cfg)


# ---------------------------------------------------------------------------
# GREEN EMERALD LASER
# ---------------------------------------------------------------------------
func _fire_green() -> void:
	var lvl := _weapon_levels[3]
	var cycle := _weapon_cycle(3, lvl)
	var speed := 2800.0
	var cs := randi() % 3

	if lvl >= 4:  # level 5: 3 volleys, all straight up
		# Volley 1: 2 bigger bullets
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = BulletConfig.GREEN_CYCLE_BIGGER
			cfg.speed = speed
			cfg.scale = GREEN_SCALE
			cfg.cycle_start = cs
			cfg.double_damage = true
			_shoot(Vector2(i * 55.0, -160), cfg)
		# Volley 2: 2 big bullets
		_fire_green_big_volley_delayed2(BulletConfig.GREEN_CYCLE_BIG, speed, cs, GREEN_SCALE, 55.0, 0.09)
		# Volley 3: 2 big bullets
		_fire_green_big_volley_delayed2(BulletConfig.GREEN_CYCLE_BIG, speed, cs, GREEN_SCALE, 55.0, 0.16)
	elif lvl >= 3:  # level 4: 3 volleys of 2 big bullets, increasing angle
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = BulletConfig.GREEN_CYCLE_BIG
			cfg.speed = speed
			cfg.scale = GREEN_SCALE
			cfg.cycle_start = cs
			cfg.double_damage = true
			_shoot(Vector2(i * 55.0, -160), cfg)
		_fire_green_big_volley_delayed(cycle, speed, cs, 5.0, 55.0, 0.07)
		_fire_green_big_volley_delayed(cycle, speed, cs, 10.0, 55.0, 0.14)
	elif lvl >= 2:  # level 3: big angled first, then middle, then left+right
		for i in [-1, 1]:
			var cfg := BulletConfig.BulletData.new()
			cfg.cycle = BulletConfig.GREEN_CYCLE_BIG
			cfg.direction = _deg_dir(i * 6.0)
			cfg.speed = speed
			cfg.scale = GREEN_SCALE
			cfg.cycle_start = cs
			cfg.double_damage = true
			_shoot(Vector2(i * 30.0, -160), cfg)
		_fire_green_middle_delayed(cycle, 0.072, speed, cs)
		_fire_green_wings_delayed(speed, cs, 0.141)
	elif lvl >= 1:  # level 2: middle × 2, then left+right
		_shoot(Vector2(0, -160), _make_green_middle_cfg(cycle, speed, cs, 0.0))
		_fire_green_middle_delayed(cycle, 0.07, speed, cs)
		_fire_green_wings_delayed(speed, cs, 0.135)
	else:  # level 1: middle, then left+right
		_shoot(Vector2(0, -160), _make_green_middle_cfg(cycle, speed, cs, 0.0))
		_fire_green_wings_delayed(speed, cs, 0.065)


func _make_green_middle_cfg(cycle: Array[Texture2D], speed: float, cs: int, time_offset: float) -> BulletConfig.BulletData:
	var cfg := BulletConfig.BulletData.new()
	cfg.cycle = cycle
	cfg.speed = speed
	cfg.scale = GREEN_SCALE
	cfg.cycle_start = cs
	cfg.cycle_time_offset = time_offset
	return cfg


func _fire_green_big_volley_delayed2(cycle: Array[Texture2D], speed: float, cs: int, scale: Vector2, x_offset: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = cycle
		cfg.speed = speed
		cfg.scale = scale
		cfg.cycle_start = cs
		cfg.double_damage = true
		cfg.cycle_time_offset = delay
		_shoot(Vector2(i * x_offset, -160), cfg)


func _fire_green_big_volley_delayed(cycle: Array[Texture2D], speed: float, cs: int, angle: float, x_offset: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.GREEN_CYCLE_BIG
		cfg.direction = _deg_dir(i * angle)
		cfg.speed = speed
		cfg.scale = GREEN_SCALE
		cfg.cycle_start = cs
		cfg.double_damage = true
		cfg.cycle_time_offset = delay
		_shoot(Vector2(i * x_offset, -160), cfg)


func _fire_green_middle_delayed(cycle: Array[Texture2D], delay: float, speed: float, cs: int) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	_shoot(Vector2(0, -160), _make_green_middle_cfg(cycle, speed, cs, delay))


func _fire_green_wings_delayed(speed: float, cs: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	for i in [-1, 1]:
		var cfg := BulletConfig.BulletData.new()
		cfg.cycle = BulletConfig.GREEN_CYCLE_LEFT if i < 0 else BulletConfig.GREEN_CYCLE_RIGHT
		cfg.speed = speed
		cfg.scale = GREEN_SCALE
		cfg.cycle_start = cs
		cfg.cycle_time_offset = delay
		_shoot(Vector2(i * 50.0, -160), cfg)


# Returns the fire interval based on the current weapon's level.
# Higher level = bigger bullets = slower fire rate.
func _get_fire_interval() -> float:
	var level := _weapon_levels[_current_pair_index]
	return FIRE_INTERVALS[level]


func _get_max_weapon_level() -> int:
	var max_level := 0
	for lvl in _weapon_levels:
		if lvl > max_level:
			max_level = lvl
	return max_level


func _activate_weapon(pair_index: int) -> void:
	_current_pair_index = pair_index
	var level_str := " (LEVEL " + str(_weapon_levels[pair_index] + 1) + ")" if _weapon_levels[pair_index] >= 1 else ""
	InfoLabel.show_info(WEAPON_NAMES[pair_index] + level_str)


func _debug_select_weapon(pair_index: int) -> void:
	if _current_pair_index == pair_index:
		# Same weapon — cycle level 0→1→2→3→4→0
		_weapon_levels[pair_index] = (_weapon_levels[pair_index] + 1) % 5
	else:
		# New weapon — carry over the highest level already earned
		if _weapon_levels[pair_index] < 1:
			_weapon_levels[pair_index] = _get_max_weapon_level()
	_activate_weapon(pair_index)


func apply_bullet_color(pair_index: int) -> void:
	# Called from vault_item.gd on pickup.
	# Same color → upgrade level (max 2). Different color → switch, carrying max level.
	if _current_pair_index == pair_index:
		if _weapon_levels[pair_index] < 4:
			_weapon_levels[pair_index] += 1
	else:
		if _weapon_levels[pair_index] < 1:
			_weapon_levels[pair_index] = _get_max_weapon_level()
	_activate_weapon(pair_index)


func _on_area_entered(area: Area2D) -> void:
	_flash_timer = FLASH_DURATION
	_is_flashing = true
	_set_flash_visual(true)

	if area.is_in_group("enemy_bullet"):
		ObjectPool.release_enemy_bullet(area)
