extends Label
class_name PauseLabel

func _ready() -> void:
	text = "PAUSED"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_delta: float) -> void:
	visible = get_tree().paused