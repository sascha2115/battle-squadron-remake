extends Label
class_name InfoLabel

## General-purpose HUD info label. Call InfoLabel.show_info(text) from anywhere.

const HOLD_DURATION := 2.0   # seconds at full opacity before fading
const FADE_DURATION := 0.8   # seconds to fade out

static var instance: Label = null

var _hold_timer: float = 0.0
var _fade_timer: float = 0.0
var _active := false


func _ready() -> void:
	instance = self
	modulate.a = 0.0


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Show a message. Resets timer if already visible.
static func show_info(msg: String) -> void:
	if instance:
		instance.text = msg
		instance.modulate.a = 1.0
		instance._hold_timer = HOLD_DURATION
		instance._fade_timer = FADE_DURATION
		instance._active = true


func _process(delta: float) -> void:
	if not _active:
		return

	if _hold_timer > 0.0:
		_hold_timer -= delta
	else:
		_fade_timer -= delta
		modulate.a = maxf(0.0, _fade_timer / FADE_DURATION)
		if _fade_timer <= 0.0:
			_active = false
