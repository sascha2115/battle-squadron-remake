extends Node2D

const Enemy1Scene := preload("res://scenes/enemy1.tscn")
const Enemy2Scene := preload("res://scenes/enemy2.tscn")
const Enemy3Scene := preload("res://scenes/enemy3.tscn")
const Enemy4Scene := preload("res://scenes/enemy4.tscn")
const VaultScene := preload("res://scenes/vault.tscn")
const SPAWN_INTERVAL := 2.0
const INITIAL_DELAY := 1.0

enum EnemyType { ENEMY1, ENEMY2, ENEMY3, ENEMY4 }

var _current_type: int = EnemyType.ENEMY1
var _current_wave_count := 0
var _enemy3_pair_count := 0
var _enemy3_side: int = -1

var _enemy2_side: int = -1
var _enemy2_entry_y: float = 0.0
var _enemy2_index: int = 0
var _enemy2_visible_left: float = 0.0

const VAULT_INTERVAL := 30.0
const VAULT_INTERVAL_RANGE := 15.0

var _spawn_timer: Timer
var _vault_timer: Timer


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(_spawn_timer)

	_vault_timer = Timer.new()
	_vault_timer.one_shot = true
	_vault_timer.timeout.connect(_on_vault_timeout)
	add_child(_vault_timer)

	_current_type = EnemyType.ENEMY1
	_current_wave_count = 3

	# Pre-warm an enemy1 to force SubViewport 3D pipeline initialization
	# (World3D, Camera3D, Sprite3D shader) before gameplay starts,
	# avoiding a one-frame stutter when the first enemy1 appears.
	_prewarm_enemy1()

	_spawn_timer.start(INITIAL_DELAY)
	_vault_timer.start(VAULT_INTERVAL + randf_range(-VAULT_INTERVAL_RANGE, VAULT_INTERVAL_RANGE))


func _prewarm_enemy1() -> void:
	var dummy := Enemy1Scene.instantiate()
	add_child(dummy)
	dummy.position = Vector2(-9999, -9999)  # far off-screen; must be set AFTER add_child to override enemy1._ready() position
	# Wait until after the first frame is actually drawn to the GPU,
	# ensuring the SubViewport's World3D, Camera3D, Sprite3D shader,
	# and render targets are fully initialized.
	# RenderingServer.frame_post_draw fires after GPU work completes.
	RenderingServer.frame_post_draw.connect(
		func() -> void:
			if is_instance_valid(dummy):
				dummy.queue_free(),
		CONNECT_ONE_SHOT
	)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_V:
			_spawn_vault()
		KEY_E:
			_debug_spawn_enemy2()
		KEY_F:
			_debug_spawn_enemy4()


func _on_spawn_timeout() -> void:
	_spawn_current()
	_current_wave_count -= 1
	if _current_wave_count <= 0:
		_start_next_wave()

	var interval := 0.15 if _current_type == EnemyType.ENEMY2 else SPAWN_INTERVAL
	_spawn_timer.start(interval)


func _on_vault_timeout() -> void:
	_spawn_vault()
	_vault_timer.start(VAULT_INTERVAL + randf_range(-VAULT_INTERVAL_RANGE, VAULT_INTERVAL_RANGE))


func _start_next_wave() -> void:
	if _current_type == EnemyType.ENEMY1:
		_current_type = EnemyType.ENEMY2
		_current_wave_count = 4
		_enemy2_side = -1 if randi() % 2 == 0 else 1
		_enemy2_entry_y = 200.0
		_enemy2_index = 0
		_enemy2_visible_left = ScreenBounds.visible_left()
	elif _current_type == EnemyType.ENEMY2:
		_current_type = EnemyType.ENEMY3
		_current_wave_count = 4
		_enemy3_pair_count = 0
		_enemy3_side = 0 if randi() % 2 == 0 else 1
	elif _current_type == EnemyType.ENEMY3:
		_current_type = EnemyType.ENEMY4
		_current_wave_count = 3
	else:
		_current_type = EnemyType.ENEMY1
		_current_wave_count = 3 if randi() % 2 == 0 else 4


func _debug_spawn_enemy2() -> void:
	if get_tree().get_first_node_in_group("enemy2") != null:
		return
	var side := -1 if randi() % 2 == 0 else 1
	var visible_left := ScreenBounds.visible_left()
	for i in 4:
		if not is_instance_valid(self):
			return
		var enemy := Enemy2Scene.instantiate()
		enemy.spawn_side = side
		enemy.formation_y = 200.0
		enemy.formation_index = i
		enemy.formation_visible_left = visible_left
		add_child(enemy)
		await get_tree().create_timer(0.15).timeout


func _debug_spawn_enemy4() -> void:
	add_child(Enemy4Scene.instantiate())


func _spawn_vault() -> void:
	if get_tree().get_first_node_in_group("vault") != null \
			or get_tree().get_first_node_in_group("vault_item") != null:
		return
	add_child(VaultScene.instantiate())


func _spawn_current() -> void:
	match _current_type:
		EnemyType.ENEMY1:
			add_child(Enemy1Scene.instantiate())
		EnemyType.ENEMY2:
			var enemy := Enemy2Scene.instantiate()
			enemy.spawn_side = _enemy2_side
			enemy.formation_y = _enemy2_entry_y
			enemy.formation_index = _enemy2_index
			enemy.formation_visible_left = _enemy2_visible_left
			_enemy2_index += 1
			add_child(enemy)
		EnemyType.ENEMY3:
			var enemy := Enemy3Scene.instantiate()
			enemy.spawn_side = _enemy3_side
			add_child(enemy)
			_enemy3_pair_count += 1
			if _enemy3_pair_count >= 2:
				_enemy3_pair_count = 0
				_enemy3_side = 0 if _enemy3_side == 1 else 1
		EnemyType.ENEMY4:
			add_child(Enemy4Scene.instantiate())
