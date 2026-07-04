extends Area2D

const DEFAULT_SPEED := 2000.0
const DEFAULT_SCALE := Vector2(0.25, 0.25)
const CYCLE_INTERVAL := 0.08

# Swerve fallback ranges (used when BulletConfig doesn't specify)
const SWERVE_AMPLITUDES := [40.0, 80.0]
const SWERVE_FREQUENCIES := [30.0, 35.0, 40.0]
const SWERVE_START_OFFSETS := [1.0, PI - 1.0]

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.UP
var _speed: float = DEFAULT_SPEED
var _cycle_textures: Array[Texture2D] = []
var _cycle_index: int = 0
var _cycle_timer: float = 0.0
var _is_swerve: bool = false
var _double_damage: bool = false
var _life_time: float = 0.0
var _origin_x: float = 0.0
var _swerve_phase: float = 0.0
var _swerve_amplitude: float = 0.0
var _swerve_frequency: float = 0.0


func _ready() -> void:
	add_to_group("bullet")
	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		_shared_shape.size = sprite.texture.get_size() * DEFAULT_SCALE
	collision_shape.shape = _shared_shape
	deactivate()


func activate(pos: Vector2, cfg: BulletConfig.BulletData) -> void:
	position = pos
	_direction = cfg.direction.normalized()
	_speed = cfg.speed
	sprite.scale = cfg.scale
	_double_damage = cfg.double_damage
	_origin_x = pos.x

	# Texture cycle
	_cycle_textures = cfg.cycle
	if _cycle_textures:
		_cycle_index = cfg.cycle_start if cfg.cycle_start >= 0 else (randi() % _cycle_textures.size())
		_cycle_timer = cfg.cycle_time_offset
		sprite.texture = _cycle_textures[_cycle_index]

	# Swerve (orange level 2+)
	_is_swerve = cfg.swerve_phase != 0.0
	if _is_swerve:
		_swerve_phase = cfg.swerve_phase
		_swerve_amplitude = cfg.swerve_amplitude if cfg.swerve_amplitude > 0.0 \
			else SWERVE_AMPLITUDES[randi() % SWERVE_AMPLITUDES.size()]
		_swerve_frequency = cfg.swerve_frequency if cfg.swerve_frequency > 0.0 \
			else SWERVE_FREQUENCIES[randi() % SWERVE_FREQUENCIES.size()]
		var offset_rad: float = cfg.swerve_start_offset if cfg.swerve_start_offset >= 0.0 \
			else SWERVE_START_OFFSETS[randi() % SWERVE_START_OFFSETS.size()]
		_life_time = offset_rad / _swerve_frequency
	else:
		_life_time = 0.0

	show()
	set_process(true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)


func deactivate() -> void:
	_cycle_textures = []
	_is_swerve = false
	_double_damage = false
	hide()
	set_process(false)
	set_deferred("monitorable", false)


func _process(delta: float) -> void:
	position += _direction * _speed * delta

	if _cycle_textures:
		_cycle_timer += delta
		if _cycle_timer >= CYCLE_INTERVAL:
			_cycle_timer -= CYCLE_INTERVAL
			_cycle_index = (_cycle_index + 1) % _cycle_textures.size()
			sprite.texture = _cycle_textures[_cycle_index]

	if _is_swerve:
		_life_time += delta
		var curve_factor := (1.0 - cos(_life_time * _swerve_frequency)) / 2.0
		# Swerve around the angled trajectory, not the initial spawn position
		var base_x := _origin_x + _direction.x * _speed * _life_time
		position.x = base_x + sign(_swerve_phase) * curve_factor * _swerve_amplitude

	if position.y < -50:
		ObjectPool.release_player_bullet(self)
