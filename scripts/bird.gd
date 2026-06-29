extends CharacterBody2D

signal died

enum DeathCause {
	UNKNOWN,
	PIPE,
	GROUND,
	CEILING
}

@export var gravity: float = 1200.0
@export var terminal_velocity: float = 700.0
@export var flap_velocity: float = -350.0

@export var tilt_up_degrees: float = -20.0
@export var tilt_down_degrees: float = 70.0
@export var tilt_smoothing: float = 8.0
@export var flap_sound: AudioStream
@export var pipe_hit_sound: AudioStream
@export var ground_hit_sound: AudioStream

const SYNTH_SAMPLE_RATE: float = 44100.0

var _was_space_down: bool = false
var _was_left_mouse_down: bool = false
var _touch_flap_requested: bool = false
var _is_game_over: bool = false
var _base_scale: Vector2 = Vector2.ONE

var _flap_player: AudioStreamPlayer
var _pipe_hit_player: AudioStreamPlayer
var _ground_hit_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("bird")
	_base_scale = scale
	_apply_responsive_scale()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_flap_player = AudioStreamPlayer.new()
	_pipe_hit_player = AudioStreamPlayer.new()
	_ground_hit_player = AudioStreamPlayer.new()
	add_child(_flap_player)
	add_child(_pipe_hit_player)
	add_child(_ground_hit_player)
	_flap_player.stream = flap_sound
	_pipe_hit_player.stream = pipe_hit_sound
	_ground_hit_player.stream = ground_hit_sound
	_ensure_generator_stream(_flap_player)
	_ensure_generator_stream(_pipe_hit_player)
	_ensure_generator_stream(_ground_hit_player)

func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	if _consume_flap_input():
		flap()

	velocity.y = min(velocity.y + gravity * delta, terminal_velocity)
	_apply_tilt(delta)
	move_and_slide()

	if get_slide_collision_count() > 0:
		game_over(DeathCause.PIPE)
		return
	if _is_below_bottom_bound():
		game_over(DeathCause.GROUND)
		return
	if _is_above_top_bound():
		game_over(DeathCause.CEILING)

func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_flap_requested = true
			return

	if InputMap.has_action("flap") and event.is_action_pressed("flap"):
		_touch_flap_requested = true

func flap() -> void:
	velocity.y = flap_velocity
	rotation_degrees = tilt_up_degrees
	_play_flap_sound()

func _consume_flap_input() -> bool:
	if _touch_flap_requested:
		_touch_flap_requested = false
		return true

	var space_down := Input.is_key_pressed(KEY_SPACE)
	var left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	var space_pressed := space_down and not _was_space_down
	var left_clicked := left_mouse_down and not _was_left_mouse_down

	_was_space_down = space_down
	_was_left_mouse_down = left_mouse_down

	return space_pressed or left_clicked

func _apply_tilt(delta: float) -> void:
	var target_tilt := tilt_up_degrees if velocity.y < 0.0 else tilt_down_degrees
	var weight: float = minf(tilt_smoothing * delta, 1.0)
	rotation_degrees = lerpf(rotation_degrees, target_tilt, weight)

func game_over(cause: int = DeathCause.UNKNOWN) -> void:
	if _is_game_over:
		return
	_is_game_over = true
	velocity = Vector2.ZERO
	_play_death_sound(cause)
	emit_signal("died")

func _is_above_top_bound() -> bool:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var top_world := (canvas_to_world * rect.position).y
	return global_position.y < top_world

func _is_below_bottom_bound() -> bool:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var canvas_to_world := viewport.get_canvas_transform().affine_inverse()
	var bottom_world := (canvas_to_world * (rect.position + Vector2(0.0, rect.size.y))).y
	return global_position.y > bottom_world

func _play_death_sound(cause: int) -> void:
	if cause == DeathCause.GROUND:
		_play_ground_hit_sound()
		return
	_play_pipe_hit_sound()

func _play_flap_sound() -> void:
	if flap_sound != null:
		_flap_player.stream = flap_sound
		_flap_player.play()
		return
	_play_tone(_flap_player, 900.0, 620.0, 0.10, 0.28, 0.04)

func _play_pipe_hit_sound() -> void:
	if pipe_hit_sound != null:
		_pipe_hit_player.stream = pipe_hit_sound
		_pipe_hit_player.play()
		return
	_play_tone(_pipe_hit_player, 280.0, 180.0, 0.14, 0.40, 0.02)

func _play_ground_hit_sound() -> void:
	if ground_hit_sound != null:
		_ground_hit_player.stream = ground_hit_sound
		_ground_hit_player.play()
		return
	_play_tone(_ground_hit_player, 170.0, 95.0, 0.18, 0.45, 0.01)

func _ensure_generator_stream(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SYNTH_SAMPLE_RATE
	generator.buffer_length = 0.25
	player.stream = generator

func _play_tone(player: AudioStreamPlayer, start_hz: float, end_hz: float, duration_sec: float, start_amp: float, end_amp: float) -> void:
	_ensure_generator_stream(player)
	player.play()

	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	var generator := player.stream as AudioStreamGenerator
	if playback == null or generator == null:
		return

	var frame_count := int(maxf(1.0, generator.mix_rate * duration_sec))
	var phase: float = 0.0
	for i in frame_count:
		var t := float(i) / float(maxi(frame_count - 1, 1))
		var frequency := lerpf(start_hz, end_hz, t)
		phase += TAU * frequency / generator.mix_rate
		var amplitude := lerpf(start_amp, end_amp, t)
		var sample := sin(phase) * amplitude
		playback.push_frame(Vector2(sample, sample))

func _on_viewport_size_changed() -> void:
	_apply_responsive_scale()

func _apply_responsive_scale() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y > viewport_size.x * 1.2 and viewport_size.x < 1500.0:
		var scale_factor := clampf(viewport_size.y / 1280.0, 1.1, 1.6)
		scale = _base_scale * scale_factor
		return
	scale = _base_scale
