extends Control

const MAX_ITEMS := 8  # max icons shown — additional capsules beyond this still count but aren't displayed
const ICON_TEXTURE := preload("res://sprites/mcapsule/mcapsule_blue.png")

var _container: HBoxContainer
var _icon_size: float
var _margin_left := 20
var _margin_bottom := 10


func _ready() -> void:
	_icon_size = maxf(ICON_TEXTURE.get_width(), ICON_TEXTURE.get_height()) * 0.2

	_container = HBoxContainer.new()
	_container.add_theme_constant_override("separation", 8)
	add_child(_container)

	GameBus.mcapsule_collected.connect(_on_mcapsule_collected)
	get_viewport().size_changed.connect(_reposition)

	# Seed with 3 icons for testing
	for _i in range(3):
		_on_mcapsule_collected()

	# Defer reposition so container minimum size is correct after children are added
	call_deferred("_reposition")


func _reposition() -> void:
	var viewport_size := get_viewport_rect().size
	var total_height := _container.get_minimum_size().y
	position = Vector2(_margin_left, viewport_size.y - total_height - _margin_bottom)


func _on_mcapsule_collected() -> void:
	if _container.get_child_count() >= MAX_ITEMS:
		return
	var icon := TextureRect.new()
	icon.texture = ICON_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(int(_icon_size), int(_icon_size))
	_container.add_child(icon)
