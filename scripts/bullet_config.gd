## BulletConfig autoload — cycle texture arrays + BulletData inner class.
## Access cycle arrays as BulletConfig.ORANGE_CYCLE etc. from anywhere.
## Create per-bullet parameter objects with BulletConfig.BulletData.new().
extends Node

# ---------------------------------------------------------------------------
# Texture cycle arrays (dark → normal → light → normal → repeat)
# ---------------------------------------------------------------------------
const ORANGE_CYCLE: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_orange_dark.png"),
	preload("res://sprites/bullets/bullet_orange.png"),
	preload("res://sprites/bullets/bullet_orange_light.png"),
	preload("res://sprites/bullets/bullet_orange.png"),
]
const ORANGE_CYCLE_LEVEL2: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_orange_big_dark.png"),
	preload("res://sprites/bullets/bullet_orange_big.png"),
	preload("res://sprites/bullets/bullet_orange_big_light.png"),
	preload("res://sprites/bullets/bullet_orange_big.png"),
]
const ORANGE_CYCLE_ORB: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_orange_orb_dark.png"),
	preload("res://sprites/bullets/bullet_orange_orb.png"),
	preload("res://sprites/bullets/bullet_orange_orb_light.png"),
	preload("res://sprites/bullets/bullet_orange_orb.png"),
]
const RED_CYCLE: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_red_dark.png"),
	preload("res://sprites/bullets/bullet_red.png"),
	preload("res://sprites/bullets/bullet_red_light.png"),
	preload("res://sprites/bullets/bullet_red.png"),
]
const BLUE_CYCLE: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_blue_dark.png"),
	preload("res://sprites/bullets/bullet_blue.png"),
	preload("res://sprites/bullets/bullet_blue_light.png"),
	preload("res://sprites/bullets/bullet_blue.png"),
]
const BLUE_CYCLE_LEVEL2: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_blue_big_dark.png"),
	preload("res://sprites/bullets/bullet_blue_big.png"),
	preload("res://sprites/bullets/bullet_blue_big_light.png"),
	preload("res://sprites/bullets/bullet_blue_big.png"),
]
const GREEN_CYCLE_LEFT: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_green_left_dark.png"),
	preload("res://sprites/bullets/bullet_green_left.png"),
	preload("res://sprites/bullets/bullet_green_left_light.png"),
	preload("res://sprites/bullets/bullet_green_left.png"),
]
const GREEN_CYCLE_MIDDLE: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_green_middle_dark.png"),
	preload("res://sprites/bullets/bullet_green_middle.png"),
	preload("res://sprites/bullets/bullet_green_middle_light.png"),
	preload("res://sprites/bullets/bullet_green_middle.png"),
]
const GREEN_CYCLE_RIGHT: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_green_right_dark.png"),
	preload("res://sprites/bullets/bullet_green_right.png"),
	preload("res://sprites/bullets/bullet_green_right_light.png"),
	preload("res://sprites/bullets/bullet_green_right.png"),
]
const GREEN_CYCLE_BIG: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_green_big_dark.png"),
	preload("res://sprites/bullets/bullet_green_big.png"),
	preload("res://sprites/bullets/bullet_green_big_light.png"),
	preload("res://sprites/bullets/bullet_green_big.png"),
]
const GREEN_CYCLE_BIGGER: Array[Texture2D] = [
	preload("res://sprites/bullets/bullet_green_bigger_dark.png"),
	preload("res://sprites/bullets/bullet_green_bigger.png"),
	preload("res://sprites/bullets/bullet_green_bigger_light.png"),
	preload("res://sprites/bullets/bullet_green_bigger.png"),
]

# ---------------------------------------------------------------------------
# Factory (convenience wrapper — equivalent to BulletConfig.BulletData.new())
# ---------------------------------------------------------------------------

## Create a new BulletData with default values.
func make() -> BulletData:
	return BulletData.new()


# ---------------------------------------------------------------------------
# BulletData — per-bullet parameter object (one instance per fired bullet)
# ---------------------------------------------------------------------------
class BulletData extends RefCounted:
	var cycle: Array[Texture2D] = []
	var direction: Vector2 = Vector2.UP
	var speed: float = 2000.0
	var scale: Vector2 = Vector2(0.25, 0.25)
	var cycle_start: int = -1
	var cycle_time_offset: float = 0.0
	var double_damage: bool = false

	# Swerve (orange level 2+)
	var swerve_phase: float = 0.0        # -1 left, +1 right; 0 = no swerve
	var swerve_start_offset: float = -1.0  # -1 = random
	var swerve_amplitude: float = 0.0    # 0 = random
	var swerve_frequency: float = 0.0    # 0 = random
