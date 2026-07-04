extends Node2D

@export var star_count := 200
@export var scroll_speed := 80.0
@export var min_star_radius := 1.0
@export var max_star_radius := 2.0

class Star:
	var position: Vector2
	var speed: float
	var color: Color
	var is_plus: bool
	var radius: float

# Precomputed pixel offsets for "+" star arms — avoids per-frame array allocation
const PLUS_INNER_OFFSETS: Array[Vector2] = [
	Vector2(-1, -4), Vector2(-4, -1), Vector2(2, -1), Vector2(-1, 2),
]
const PLUS_OUTER_OFFSETS: Array[Vector2] = [
	Vector2(-1, -7), Vector2(-7, -1), Vector2(5, -1), Vector2(-1, 5),
]

var _stars: Array[Star] = []


func _ready() -> void:
	_spawn_stars()


func _spawn_stars() -> void:
	var screen_size := ScreenBounds.size
	var play_size := ScreenBounds.play_size
	var total_stars := int(round(star_count * play_size.x / screen_size.x))
	for i in range(total_stars):
		var star := Star.new()
		star.radius = randf_range(min_star_radius, max_star_radius)

		var roll := randf()
		var brightness := randf_range(0.3, 1.0)
		if roll < 0.4:
			star.color = Color(0.5, 0.7, 1.0) * brightness
		elif roll < 0.6:
			star.color = Color(1.0, 0.6, 0.6) * brightness
		elif roll < 0.8:
			star.color = Color(0.6, 1.0, 0.6) * brightness
		else:
			star.color = Color(1.0, 1.0, 0.5) * brightness

		star.is_plus = randf() < 0.25
		star.position = Vector2(
			randf_range(0.0, play_size.x),
			randf_range(-screen_size.y * 0.5, screen_size.y)
		)
		star.speed = scroll_speed * randf_range(0.5, 1.5)
		_stars.append(star)


func _process(delta: float) -> void:
	var screen_size := ScreenBounds.size

	for star in _stars:
		star.position.y += star.speed * delta
		if star.position.y > screen_size.y + 20:
			star.position.y = -20
			star.position.x = randf_range(0.0, ScreenBounds.play_size.x)

	queue_redraw()


func _draw() -> void:
	for star in _stars:
		if star.is_plus:
			_draw_plus_star(star)
		else:
			draw_rect(
				Rect2(star.position - Vector2(star.radius, star.radius), Vector2(star.radius * 2.0, star.radius * 2.0)),
				star.color
			)


func _draw_plus_star(star: Star) -> void:
	var c := star.color
	var arm_inner := Color(c.r, c.g, c.b, 0.66)
	var arm_outer := Color(c.r, c.g, c.b, 0.33)
	var p := star.position

	# Center (3x3 white)
	draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), Color.WHITE)

	# Inner arm pixels
	for off in PLUS_INNER_OFFSETS:
		draw_rect(Rect2(p + off, Vector2(3, 3)), arm_inner)

	# Outer arm pixels
	for off in PLUS_OUTER_OFFSETS:
		draw_rect(Rect2(p + off, Vector2(3, 3)), arm_outer)
