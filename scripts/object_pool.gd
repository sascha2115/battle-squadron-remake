extends Node

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

var _bullet_pool: Array[Area2D] = []
var _enemy_bullet_pool: Array[Area2D] = []
var _explosion_pool: Array[Node2D] = []


func spawn_player_bullet(parent: Node, pos: Vector2, cfg: BulletConfig.BulletData) -> Area2D:
	var bullet: Area2D
	if _bullet_pool.is_empty():
		bullet = BULLET_SCENE.instantiate() as Area2D
		parent.add_child(bullet)
	else:
		bullet = _bullet_pool.pop_back()
		if not is_instance_valid(bullet):
			bullet = BULLET_SCENE.instantiate() as Area2D
		elif bullet.get_parent() != parent:
			parent.add_child(bullet)
	bullet.activate(pos, cfg)
	return bullet


func release_player_bullet(bullet: Area2D) -> void:
	if not is_instance_valid(bullet):
		return
	bullet.deactivate()
	_bullet_pool.append(bullet)


func spawn_enemy_bullet(parent: Node, pos: Vector2, dir: Vector2) -> Area2D:
	var bullet: Area2D
	if _enemy_bullet_pool.is_empty():
		bullet = ENEMY_BULLET_SCENE.instantiate() as Area2D
		parent.add_child(bullet)
	else:
		bullet = _enemy_bullet_pool.pop_back()
		if not is_instance_valid(bullet):
			bullet = ENEMY_BULLET_SCENE.instantiate() as Area2D
		elif bullet.get_parent() != parent:
			parent.add_child(bullet)
	bullet.activate(pos, dir)
	return bullet


func release_enemy_bullet(bullet: Area2D) -> void:
	if not is_instance_valid(bullet):
		return
	bullet.deactivate()
	_enemy_bullet_pool.append(bullet)


func spawn_explosion(parent: Node, pos: Vector2) -> Node2D:
	var explosion: Node2D
	if _explosion_pool.is_empty():
		explosion = EXPLOSION_SCENE.instantiate() as Node2D
		parent.add_child(explosion)
	else:
		explosion = _explosion_pool.pop_back()
		if not is_instance_valid(explosion):
			explosion = EXPLOSION_SCENE.instantiate() as Node2D
		elif explosion.get_parent() != parent:
			parent.add_child(explosion)
	explosion.activate(pos)
	return explosion


func release_explosion(explosion: Node2D) -> void:
	if not is_instance_valid(explosion):
		return
	explosion.deactivate()
	_explosion_pool.append(explosion)
