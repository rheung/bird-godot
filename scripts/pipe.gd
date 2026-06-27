extends Node2D

signal passed

@export var move_speed: float = 200.0
@export var despawn_margin: float = 128.0
@export var gap_size: float = 260.0
@export var pipe_width: float = 80.0
@export var overscan_height: float = 200.0

var _has_scored: bool = false
var _is_stopped: bool = false

@onready var _score_zone: Area2D = $ScoreZone
@onready var _top_visual: Polygon2D = $TopPipe
@onready var _bottom_visual: Polygon2D = $BottomPipe
@onready var _top_body: StaticBody2D = $TopBody
@onready var _bottom_body: StaticBody2D = $BottomBody
@onready var _top_shape: CollisionShape2D = $TopBody/CollisionShape2D
@onready var _bottom_shape: CollisionShape2D = $BottomBody/CollisionShape2D
@onready var _score_shape: CollisionShape2D = $ScoreZone/CollisionShape2D

func _ready() -> void:
	add_to_group("pipes")
	_layout_to_viewport()
	get_viewport().size_changed.connect(_layout_to_viewport)
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

func _layout_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var top_world_y := (canvas_to_world * rect.position).y
	var bottom_world_y := (canvas_to_world * (rect.position + Vector2(0.0, rect.size.y))).y
	var world_height := bottom_world_y - top_world_y
	var half_screen := world_height * 0.5

	var gap_half := gap_size * 0.5
	var top_top := -half_screen - overscan_height
	var top_bottom := -gap_half
	var bottom_top := gap_half
	var bottom_bottom := half_screen + overscan_height

	var top_height := top_bottom - top_top
	var bottom_height := bottom_bottom - bottom_top

	var half_width := pipe_width * 0.5

	if _top_visual != null:
		_top_visual.position = Vector2(0.0, (top_top + top_bottom) * 0.5)
		_top_visual.polygon = PackedVector2Array([
			Vector2(-half_width, -top_height * 0.5),
			Vector2(half_width, -top_height * 0.5),
			Vector2(half_width, top_height * 0.5),
			Vector2(-half_width, top_height * 0.5)
		])
	if _bottom_visual != null:
		_bottom_visual.position = Vector2(0.0, (bottom_top + bottom_bottom) * 0.5)
		_bottom_visual.polygon = PackedVector2Array([
			Vector2(-half_width, -bottom_height * 0.5),
			Vector2(half_width, -bottom_height * 0.5),
			Vector2(half_width, bottom_height * 0.5),
			Vector2(-half_width, bottom_height * 0.5)
		])

	if _top_body != null:
		_top_body.position = Vector2(0.0, (top_top + top_bottom) * 0.5)
	if _bottom_body != null:
		_bottom_body.position = Vector2(0.0, (bottom_top + bottom_bottom) * 0.5)

	if _top_shape != null:
		var top_rect := _top_shape.shape as RectangleShape2D
		if top_rect != null:
			top_rect.size = Vector2(pipe_width, top_height)
	if _bottom_shape != null:
		var bottom_rect := _bottom_shape.shape as RectangleShape2D
		if bottom_rect != null:
			bottom_rect.size = Vector2(pipe_width, bottom_height)

	if _score_shape != null:
		var score_rect := _score_shape.shape as RectangleShape2D
		if score_rect != null:
			score_rect.size = Vector2(60.0, maxf(40.0, gap_size - 24.0))
