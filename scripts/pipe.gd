extends Node2D

signal passed

@export var move_speed: float = 200.0
@export var despawn_margin: float = 128.0

var _has_scored: bool = false
var _is_stopped: bool = false

@onready var _score_zone: Area2D = $ScoreZone

func _ready() -> void:
	add_to_group("pipes")
	if _score_zone != null:
		_score_zone.body_entered.connect(_on_score_zone_body_entered)

func _process(delta: float) -> void:
	if _is_stopped:
		return

	global_position.x -= move_speed * delta
	if global_position.x < _get_left_edge_world_x() - despawn_margin:
		queue_free()

func _get_left_edge_world_x() -> float:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var left_world := canvas_to_world * rect.position
	return left_world.x

func _on_score_zone_body_entered(body: Node) -> void:
	if _has_scored:
		return
	if body.is_in_group("bird") or body.name == "Bird":
		_has_scored = true
		emit_signal("passed")

func set_stopped(stopped: bool) -> void:
	_is_stopped = stopped
