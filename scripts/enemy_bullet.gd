extends Area2D

const SPEED := 500.0
const TEXTURE_CYCLE_INTERVAL := 0.16

const TEXTURES := [
	preload("res://sprites/bullets/enemy_bullet.png"),
	preload("res://sprites/bullets/enemy_bullet_green1.png"),
	preload("res://sprites/bullets/enemy_bullet_green2.png"),
	preload("res://sprites/bullets/enemy_bullet.png"),
	preload("res://sprites/bullets/enemy_bullet_white1.png"),
	preload("res://sprites/bullets/enemy_bullet_white2.png"),
	preload("res://sprites/bullets/enemy_bullet.png"),
]

var _velocity: Vector2 = Vector2.DOWN

static var _shared_shape: RectangleShape2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _texture_timer: float = 0.0
var _texture_index: int = 0


func _ready() -> void:
	add_to_group("enemy_bullet")
	sprite.material = null

	if not _shared_shape:
		_shared_shape = RectangleShape2D.new()
		_shared_shape.size = sprite.texture.get_size() * sprite.scale

	collision_shape.shape = _shared_shape
	deactivate()


func activate(pos: Vector2, dir: Vector2) -> void:
	position = pos
	_velocity = dir
	_texture_timer = 0.0
	_texture_index = 0
	sprite.texture = TEXTURES[0]
	show()
	set_process(true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)


func deactivate() -> void:
	hide()
	set_process(false)
	set_deferred("monitorable", false)


func _process(delta: float) -> void:
	position += _velocity * SPEED * delta

	_texture_timer += delta
	if _texture_timer >= TEXTURE_CYCLE_INTERVAL:
		_texture_timer = fmod(_texture_timer, TEXTURE_CYCLE_INTERVAL)
		_texture_index = (_texture_index + 1) % TEXTURES.size()
		sprite.texture = TEXTURES[_texture_index]

	var screen_size := ScreenBounds.size
	if position.y > screen_size.y + 100 or position.y < -100 \
			or position.x > ScreenBounds.play_size.x + 100 \
			or position.x < -100:
		ObjectPool.release_enemy_bullet(self)
