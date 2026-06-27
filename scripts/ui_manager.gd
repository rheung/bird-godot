extends CanvasLayer

signal game_over_triggered

@export var score_label_path: NodePath
@export var bird_path: NodePath
@export var pipe_spawner_path: NodePath
@export var level_up_every_points: int = 30
@export var speed_increase_per_level: float = 15.0
@export var pipe_colors: Array[Color] = [
	Color(0.247059, 0.6, 0.266667, 1.0),
	Color(0.941176, 0.533333, 0.184314, 1.0),
	Color(0.203922, 0.643137, 0.886275, 1.0),
	Color(0.85098, 0.286275, 0.286275, 1.0),
	Color(0.588235, 0.423529, 0.823529, 1.0),
	Color(0.941176, 0.792157, 0.211765, 1.0),
	Color(0.180392, 0.745098, 0.631373, 1.0),
	Color(0.968627, 0.396078, 0.541176, 1.0),
	Color(0.360784, 0.52549, 0.878431, 1.0),
	Color(0.980392, 0.596078, 0.117647, 1.0),
	Color(0.360784, 0.803922, 0.321569, 1.0),
	Color(0.815686, 0.466667, 0.203922, 1.0),
	Color(0.196078, 0.721569, 0.839216, 1.0),
	Color(0.901961, 0.309804, 0.462745, 1.0),
	Color(0.470588, 0.682353, 0.266667, 1.0),
	Color(0.776471, 0.396078, 0.756863, 1.0)
]

var score: int = 0
var is_game_over: bool = false
var _color_index: int = 0
var _current_speed: float = 0.0

@onready var score_label: Label = get_node_or_null(score_label_path)
@onready var bird: Node = get_node_or_null(bird_path)
@onready var pipe_spawner: Node = get_node_or_null(pipe_spawner_path)

func _ready() -> void:
	if pipe_spawner != null and pipe_spawner.get("pipe_speed") != null:
		_current_speed = float(pipe_spawner.get("pipe_speed"))
	if pipe_colors.is_empty():
		pipe_colors = [Color(0.247059, 0.6, 0.266667, 1.0)]
	_apply_current_difficulty()
	_update_score_label()

	if bird != null and bird.has_signal("died"):
		bird.died.connect(_on_bird_died)
	if pipe_spawner != null and pipe_spawner.has_signal("pipe_passed"):
		pipe_spawner.pipe_passed.connect(_on_pipe_passed)

func _on_pipe_passed() -> void:
	if is_game_over:
		return
	score += 1
	if level_up_every_points > 0 and score > 0 and score % level_up_every_points == 0:
		_level_up_difficulty()
	_update_score_label()

func _on_bird_died() -> void:
	game_over()

func game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	emit_signal("game_over_triggered")
	if score_label != null:
		score_label.text = "Game Over\nScore: %d  Speed: %d" % [score, int(round(_current_speed))]

func _update_score_label() -> void:
	if score_label != null:
		score_label.text = "Score: %d  Speed: %d" % [score, int(round(_current_speed))]

func _level_up_difficulty() -> void:
	_current_speed += speed_increase_per_level
	_color_index = (_color_index + 1) % pipe_colors.size()
	_apply_current_difficulty()

func _apply_current_difficulty() -> void:
	if pipe_spawner == null:
		return
	var current_color: Color = pipe_colors[_color_index]
	if pipe_spawner.has_method("apply_difficulty"):
		pipe_spawner.call("apply_difficulty", _current_speed, current_color)
		return
	if pipe_spawner.get("pipe_speed") != null:
		pipe_spawner.set("pipe_speed", _current_speed)
