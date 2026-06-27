extends CanvasLayer

signal game_over_triggered

@export var score_label_path: NodePath
@export var bird_path: NodePath
@export var pipe_spawner_path: NodePath

var score: int = 0
var is_game_over: bool = false

@onready var score_label: Label = get_node_or_null(score_label_path)
@onready var bird: Node = get_node_or_null(bird_path)
@onready var pipe_spawner: Node = get_node_or_null(pipe_spawner_path)

func _ready() -> void:
	_update_score_label()

	if bird != null and bird.has_signal("died"):
		bird.died.connect(_on_bird_died)
	if pipe_spawner != null and pipe_spawner.has_signal("pipe_passed"):
		pipe_spawner.pipe_passed.connect(_on_pipe_passed)

func _on_pipe_passed() -> void:
	if is_game_over:
		return
	score += 1
	_update_score_label()

func _on_bird_died() -> void:
	game_over()

func game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	emit_signal("game_over_triggered")
	if score_label != null:
		score_label.text = "Game Over\nScore: %d" % score

func _update_score_label() -> void:
	if score_label != null:
		score_label.text = "Score: %d" % score
