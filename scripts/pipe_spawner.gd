extends Node2D

signal pipe_passed

@export var pipe_scene: PackedScene = preload("res://scenes/pipe.tscn")
@export var spawn_interval: float = 2.0
@export var spawn_y_min: float = -150.0
@export var spawn_y_max: float = 150.0
@export var pipe_speed: float = 200.0
@export var vertical_spawn_margin: float = 140.0
@export var pipe_color: Color = Color(0.247059, 0.6, 0.266667, 1.0)

var _timer: float = 0.0
var _is_stopped: bool = false
var _target_pipe_distance: float = 0.0

func _ready() -> void:
	add_to_group("pipe_spawners")
	_target_pipe_distance = pipe_speed * spawn_interval
	randomize()
	_spawn_pipe()

func _process(delta: float) -> void:
	if _is_stopped:
		return

	_timer += delta
	if _timer >= spawn_interval:
		_timer -= spawn_interval
		_spawn_pipe()

func _spawn_pipe() -> void:
	if pipe_scene == null:
		push_warning("PipeSpawner: pipe_scene is not assigned.")
		return

	var pipe := pipe_scene.instantiate()
	if not (pipe is Node2D):
		push_warning("PipeSpawner: pipe.tscn root must inherit Node2D.")
		return

	var spawn_x := _get_right_edge_world_x() + 64.0
	var spawn_center_y := _get_viewport_center_world_y()
	var spawn_y := spawn_center_y + randf_range(spawn_y_min, spawn_y_max)
	spawn_y = _clamp_spawn_y(spawn_y)
	(pipe as Node2D).global_position = Vector2(spawn_x, spawn_y)

	# If the spawned pipe script exposes move_speed, set it from spawner.
	if pipe.has_method("set_move_speed"):
		pipe.call("set_move_speed", pipe_speed)
	elif pipe.get("move_speed") != null:
		pipe.set("move_speed", pipe_speed)
	if pipe.has_method("set_pipe_color"):
		pipe.call("set_pipe_color", pipe_color)
	if pipe.has_signal("passed"):
		pipe.passed.connect(_on_pipe_passed)

	add_child(pipe)

func _get_right_edge_world_x() -> float:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var right_world := canvas_to_world * (rect.position + Vector2(rect.size.x, 0.0))
	return right_world.x

func _get_viewport_center_world_y() -> float:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var center_screen := rect.position + rect.size * 0.5
	var center_world := canvas_to_world * center_screen
	return center_world.y

func _clamp_spawn_y(raw_spawn_y: float) -> float:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var top_world := (canvas_to_world * rect.position).y
	var bottom_world := (canvas_to_world * (rect.position + Vector2(0.0, rect.size.y))).y
	return clampf(raw_spawn_y, top_world + vertical_spawn_margin, bottom_world - vertical_spawn_margin)

func _on_pipe_passed() -> void:
	emit_signal("pipe_passed")

func set_stopped(stopped: bool) -> void:
	_is_stopped = stopped

func apply_difficulty(new_speed: float, new_color: Color) -> void:
	if new_speed > 0.0:
		pipe_speed = new_speed
		if _target_pipe_distance > 0.0:
			spawn_interval = _target_pipe_distance / pipe_speed
	pipe_color = new_color
	get_tree().call_group("pipes", "set_move_speed", pipe_speed)
	get_tree().call_group("pipes", "set_pipe_color", pipe_color)
