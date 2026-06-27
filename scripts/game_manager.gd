extends Node

signal state_changed(new_state: int)

enum GameState {
	READY,
	PLAYING,
	GAME_OVER
}

@export var restart_action: StringName = &"restart"
@export var restart_key: Key = KEY_SPACE
@export var ui_manager_path: NodePath
@export var bird_path: NodePath

var state: int = GameState.READY

@onready var _ui_manager: Node = get_node_or_null(ui_manager_path)
@onready var _bird: Node = get_node_or_null(bird_path)

func _ready() -> void:
	if _ui_manager != null and _ui_manager.has_signal("game_over_triggered"):
		_ui_manager.game_over_triggered.connect(_on_game_over_triggered)
	if _bird != null and _bird.has_signal("died"):
		_bird.died.connect(_on_game_over_triggered)
	_set_state(GameState.PLAYING)

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.GAME_OVER:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			restart_current_scene()
			_mark_input_handled_safe()
			return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			restart_current_scene()
			_mark_input_handled_safe()
			return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == restart_key:
			restart_current_scene()
			_mark_input_handled_safe()
			return

	if InputMap.has_action(restart_action) and event.is_action_pressed(restart_action):
		restart_current_scene()
		_mark_input_handled_safe()

func set_game_over() -> void:
	_set_state(GameState.GAME_OVER)
	_freeze_gameplay()

func restart_current_scene() -> void:
	get_tree().reload_current_scene()

func _on_game_over_triggered() -> void:
	set_game_over()

func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	emit_signal("state_changed", state)

func _freeze_gameplay() -> void:
	if _bird != null and _bird.has_method("game_over"):
		_bird.call("game_over")
	get_tree().call_group("pipe_spawners", "set_stopped", true)
	get_tree().call_group("pipes", "set_stopped", true)

func _mark_input_handled_safe() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
