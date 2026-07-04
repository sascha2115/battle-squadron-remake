extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	deactivate()


func activate(pos: Vector2) -> void:
	position = pos
	show()
	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play("explode")


func deactivate() -> void:
	hide()
	animated_sprite.stop()


func _on_animation_finished() -> void:
	ObjectPool.release_explosion(self)
