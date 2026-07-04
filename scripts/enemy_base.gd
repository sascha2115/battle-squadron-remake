extends Area2D
class_name EnemyBase

const FLASH_DURATION := 0.1

var hits_remaining: int = 1
var _flash_timer: float = 0.0
var _is_flashing: bool = false
var _sprite_2d: Sprite2D = null


func _ready() -> void:
	_sprite_2d = get_node_or_null("Sprite2D") as Sprite2D
	area_entered.connect(_on_area_entered)


func _process_flash(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_is_flashing = false
			_apply_flash_color(false)


func _apply_flash_color(flash: bool) -> void:
	var color := Color(0.45, 1.0, 0.45) if flash else Color.WHITE
	if _sprite_2d:
		_sprite_2d.modulate = color


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_on_player_collision()
		return
	_on_bullet_hit(area)


func _on_player_collision() -> void:
	ObjectPool.spawn_explosion(get_parent(), position)
	queue_free()


func _on_bullet_hit(bullet: Area2D) -> void:
	var damage := 2 if bullet.get("_double_damage") == true else 1
	ObjectPool.release_player_bullet(bullet)
	hits_remaining -= damage
	_flash_timer = FLASH_DURATION
	_is_flashing = true
	_apply_flash_color(true)
	if hits_remaining <= 0:
		_on_killed()
	else:
		_on_damaged()


func _on_killed() -> void:
	ObjectPool.spawn_explosion(get_parent(), position)
	queue_free()


func _on_damaged() -> void:
	pass
