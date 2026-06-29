extends CanvasLayer

signal game_over_triggered

const LEADERBOARD_NAME := "main"
const LEADERBOARD_LIMIT := 5

@export var score_label_path: NodePath
@export var leaderboard_label_path: NodePath
@export var congrats_label_path: NodePath
@export var congrats_sound: AudioStream = preload("res://audio/mixkit-unlock-game-notification-253.wav")
@export var name_prompt_path: NodePath
@export var name_input_path: NodePath
@export var name_submit_button_path: NodePath
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
var _leaderboard_scores: Array = []
var _leaderboard_loaded: bool = false
var _best_leaderboard_score: int = -1
var _leaderboard_request_in_flight: bool = false
var _score_submission_pending: bool = false
var _score_submission_finished: bool = false
var _pending_player_name: String = ""
var _beaten_top_score: bool = false
var _congrats_shown: bool = false
var _congrats_hide_token: int = 0
var _congrats_audio_player: AudioStreamPlayer
var _congrats_flash_tween: Tween
var _ui_scale_factor: float = 1.0

var _base_score_font_size: int = 34
var _base_leaderboard_title_font_size: int = 24
var _base_leaderboard_font_size: int = 20
var _base_congrats_font_size: int = 22
var _base_name_prompt_title_font_size: int = 16
var _base_name_input_font_size: int = 16
var _base_name_submit_font_size: int = 16

var _base_leaderboard_left: float = -266.0
var _base_leaderboard_top: float = 20.0
var _base_leaderboard_right: float = -12.0
var _base_leaderboard_bottom: float = 220.0

var _base_congrats_left: float = -266.0
var _base_congrats_top: float = 232.0
var _base_congrats_right: float = -12.0
var _base_congrats_bottom: float = 278.0

var _base_name_prompt_left: float = -140.0
var _base_name_prompt_top: float = -70.0
var _base_name_prompt_right: float = 140.0
var _base_name_prompt_bottom: float = 70.0

var _base_name_input_min_size: Vector2 = Vector2.ZERO
var _base_name_submit_min_size: Vector2 = Vector2.ZERO

@onready var score_label: Label = get_node_or_null(score_label_path)
@onready var leaderboard_label: Label = get_node_or_null(leaderboard_label_path)
@onready var congrats_label: Label = get_node_or_null(congrats_label_path)
@onready var leaderboard_panel: Control = get_node_or_null("LeaderboardPanel")
@onready var leaderboard_title_label: Label = get_node_or_null("LeaderboardPanel/MarginContainer/VBoxContainer/LeaderboardTitle")
@onready var name_prompt: Control = get_node_or_null(name_prompt_path)
@onready var name_prompt_title_label: Label = get_node_or_null("NamePrompt/MarginContainer/VBoxContainer/NamePromptLabel")
@onready var name_input: LineEdit = get_node_or_null(name_input_path)
@onready var name_submit_button: Button = get_node_or_null(name_submit_button_path)
@onready var bird: Node = get_node_or_null(bird_path)
@onready var pipe_spawner: Node = get_node_or_null(pipe_spawner_path)

func _ready() -> void:
	if not SilentWolf.Scores.sw_get_scores_complete.is_connected(_on_sw_get_scores_complete):
		SilentWolf.Scores.sw_get_scores_complete.connect(_on_sw_get_scores_complete)
	if not SilentWolf.Scores.sw_save_score_complete.is_connected(_on_sw_save_score_complete):
		SilentWolf.Scores.sw_save_score_complete.connect(_on_sw_save_score_complete)
	_congrats_audio_player = AudioStreamPlayer.new()
	_congrats_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_congrats_audio_player)
	_ensure_congrats_sound()
	if name_prompt != null:
		name_prompt.visible = false
	if name_input != null:
		name_input.max_length = 10
		if not name_input.text_submitted.is_connected(_on_name_text_submitted):
			name_input.text_submitted.connect(_on_name_text_submitted)
	if name_submit_button != null:
		if not name_submit_button.pressed.is_connected(_on_name_submit_pressed):
			name_submit_button.pressed.connect(_on_name_submit_pressed)
	if congrats_label != null:
		congrats_label.visible = false
	if leaderboard_label != null:
		leaderboard_label.text = "Loading top 5..."
		leaderboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if pipe_spawner != null and pipe_spawner.get("pipe_speed") != null:
		_current_speed = float(pipe_spawner.get("pipe_speed"))
	if pipe_colors.is_empty():
		pipe_colors = [Color(0.247059, 0.6, 0.266667, 1.0)]
	_cache_base_ui_metrics()
	_apply_responsive_ui()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_current_difficulty()
	_update_score_label()
	_load_cached_leaderboard()
	call_deferred("_refresh_leaderboard")

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
	_maybe_show_top_score_congrats()

func _on_bird_died() -> void:
	game_over()

func game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	_congrats_shown = false
	emit_signal("game_over_triggered")
	if score_label != null:
		score_label.text = _build_score_text(true)
	_score_submission_pending = true
	_refresh_leaderboard()

func _update_score_label() -> void:
	if score_label != null:
		score_label.text = _build_score_text(false)
	_update_leaderboard_label()

func _build_score_text(game_over_state: bool) -> String:
	var score_text := "Score: %d" % score
	if game_over_state:
		return "Game Over\n" + score_text
	return score_text

func _refresh_leaderboard() -> void:
	if _leaderboard_request_in_flight:
		return
	_leaderboard_request_in_flight = true
	if leaderboard_label != null and not _leaderboard_loaded:
		leaderboard_label.text = "Loading top 5..."
	SilentWolf.Scores.get_scores(LEADERBOARD_LIMIT, LEADERBOARD_NAME)

func _load_cached_leaderboard() -> void:
	var cached_scores: Array = []
	if SilentWolf.Scores.leaderboards.has(LEADERBOARD_NAME):
		cached_scores = SilentWolf.Scores.leaderboards[LEADERBOARD_NAME]
	elif not SilentWolf.Scores.scores.is_empty():
		cached_scores = SilentWolf.Scores.scores
	if cached_scores.is_empty():
		return
	_leaderboard_scores = cached_scores
	_leaderboard_loaded = true
	_best_leaderboard_score = int(_leaderboard_scores[0].get("score", -1)) if not _leaderboard_scores.is_empty() else -1
	_update_leaderboard_label()

func _on_sw_get_scores_complete(result: Dictionary) -> void:
	_leaderboard_request_in_flight = false
	if not result.has("ld_name") or str(result.ld_name) != LEADERBOARD_NAME:
		return
	_leaderboard_loaded = true
	_leaderboard_scores = result.get("scores", [])
	_best_leaderboard_score = int(_leaderboard_scores[0].get("score", -1)) if not _leaderboard_scores.is_empty() else -1
	_update_leaderboard_label()
	_maybe_show_top_score_congrats()
	if _score_submission_pending and not _score_submission_finished:
		_evaluate_score_submission()

func _update_leaderboard_label() -> void:
	if leaderboard_label == null:
		return
	if not _leaderboard_loaded:
		leaderboard_label.text = "Loading top 5..."
		return
	if _leaderboard_scores.is_empty():
		leaderboard_label.text = "No scores yet"
		return
	var lines: Array[String] = []
	for index in range(min(_leaderboard_scores.size(), LEADERBOARD_LIMIT)):
		var entry: Dictionary = _leaderboard_scores[index]
		lines.append("%d. %s - %d" % [index + 1, str(entry.get("player_name", "---")), int(entry.get("score", 0))])
	leaderboard_label.text = "\n".join(lines)

func _evaluate_score_submission() -> void:
	if not _score_submission_pending or _score_submission_finished:
		return
	if not _leaderboard_loaded:
		return
	var qualifies := _leaderboard_scores.size() < LEADERBOARD_LIMIT
	if not qualifies and not _leaderboard_scores.is_empty():
		var lowest_index: int = min(_leaderboard_scores.size(), LEADERBOARD_LIMIT) - 1
		var lowest_visible_score := int(_leaderboard_scores[lowest_index].get("score", 0))
		qualifies = score > lowest_visible_score
	if qualifies:
		_show_name_prompt()
	else:
		_score_submission_pending = false

func _show_name_prompt() -> void:
	if name_prompt == null or name_input == null:
		return
	name_prompt.visible = true
	name_input.text = ""
	name_input.max_length = 10
	name_input.grab_focus()

func _hide_name_prompt() -> void:
	if name_prompt != null:
		name_prompt.visible = false

func _on_name_submit_pressed() -> void:
	_submit_player_name()

func _on_name_text_submitted(_text: String) -> void:
	_submit_player_name()

func _submit_player_name() -> void:
	if _score_submission_finished or name_input == null:
		return
	var player_name := name_input.text.strip_edges().left(10)
	if player_name.is_empty():
		return
	_pending_player_name = player_name
	_hide_name_prompt()
	SilentWolf.Scores.save_score(_pending_player_name, score, LEADERBOARD_NAME)

func _on_sw_save_score_complete(result: Dictionary) -> void:
	if not _score_submission_pending:
		return
	if result.has("success") and not bool(result.success):
		_show_name_prompt()
		return
	_score_submission_pending = false
	_score_submission_finished = true
	_pending_player_name = ""
	_refresh_leaderboard()

func _maybe_show_top_score_congrats() -> void:
	if _congrats_shown:
		return
	if is_game_over:
		return
	if _best_leaderboard_score < 0:
		return
	if score <= _best_leaderboard_score:
		return
	_beaten_top_score = true
	_show_top_score_congrats()

func _show_top_score_congrats() -> void:
	if _congrats_shown:
		return
	_congrats_shown = true
	if congrats_label != null:
		congrats_label.text = "New high score!"
		congrats_label.visible = true
		_start_congrats_flash()
		_congrats_hide_token += 1
		var hide_token := _congrats_hide_token
		_hide_congrats_later(hide_token)
	_play_congrats_sound()

func _hide_congrats_later(hide_token: int) -> void:
	await get_tree().create_timer(5.0).timeout
	if hide_token != _congrats_hide_token:
		return
	if congrats_label != null:
		congrats_label.visible = false
	_stop_congrats_flash()

func _play_congrats_sound() -> void:
	if _congrats_audio_player == null:
		return
	_congrats_audio_player.play()
	var playback := _congrats_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var generator := _congrats_audio_player.stream as AudioStreamGenerator
	if playback == null or generator == null:
		return
	var notes := [660.0, 880.0, 990.0]
	for frequency in notes:
		var frame_count := int(generator.mix_rate * 0.16)
		for i in frame_count:
			var sample := sin(TAU * frequency * float(i) / generator.mix_rate) * 0.18
			playback.push_frame(Vector2(sample, sample))
		for i in int(generator.mix_rate * 0.03):
			playback.push_frame(Vector2.ZERO)

func _ensure_congrats_sound() -> void:
	if _congrats_audio_player == null:
		return
	if congrats_sound != null:
		_congrats_audio_player.stream = congrats_sound
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.5
	_congrats_audio_player.stream = generator

func _start_congrats_flash() -> void:
	if congrats_label == null:
		return
	_stop_congrats_flash()
	_congrats_flash_tween = create_tween()
	_congrats_flash_tween.set_loops()
	for hue_step in range(8):
		var color := Color.from_hsv(float(hue_step) / 8.0, 0.9, 1.0)
		_congrats_flash_tween.tween_method(_set_congrats_color, congrats_label.get_theme_color("font_color"), color, 0.12)

func _stop_congrats_flash() -> void:
	if _congrats_flash_tween != null and is_instance_valid(_congrats_flash_tween):
		_congrats_flash_tween.kill()
		_congrats_flash_tween = null
	if congrats_label != null:
		congrats_label.remove_theme_color_override("font_color")

func _set_congrats_color(color: Color) -> void:
	if congrats_label != null:
		congrats_label.add_theme_color_override("font_color", color)

func _on_viewport_size_changed() -> void:
	_apply_responsive_ui()

func _cache_base_ui_metrics() -> void:
	if score_label != null:
		_base_score_font_size = int(score_label.get("theme_override_font_sizes/font_size"))
	if leaderboard_title_label != null:
		_base_leaderboard_title_font_size = int(leaderboard_title_label.get("theme_override_font_sizes/font_size"))
	if leaderboard_label != null:
		_base_leaderboard_font_size = int(leaderboard_label.get("theme_override_font_sizes/font_size"))
	if congrats_label != null:
		_base_congrats_font_size = int(congrats_label.get("theme_override_font_sizes/font_size"))
		_base_congrats_left = congrats_label.offset_left
		_base_congrats_top = congrats_label.offset_top
		_base_congrats_right = congrats_label.offset_right
		_base_congrats_bottom = congrats_label.offset_bottom
	if name_prompt != null:
		_base_name_prompt_left = name_prompt.offset_left
		_base_name_prompt_top = name_prompt.offset_top
		_base_name_prompt_right = name_prompt.offset_right
		_base_name_prompt_bottom = name_prompt.offset_bottom
	if name_prompt_title_label != null:
		_base_name_prompt_title_font_size = int(name_prompt_title_label.get_theme_font_size("font_size"))
	if name_input != null:
		_base_name_input_font_size = int(name_input.get_theme_font_size("font_size"))
		_base_name_input_min_size = name_input.custom_minimum_size
	if name_submit_button != null:
		_base_name_submit_font_size = int(name_submit_button.get_theme_font_size("font_size"))
		_base_name_submit_min_size = name_submit_button.custom_minimum_size
	if leaderboard_panel != null:
		_base_leaderboard_left = leaderboard_panel.offset_left
		_base_leaderboard_top = leaderboard_panel.offset_top
		_base_leaderboard_right = leaderboard_panel.offset_right
		_base_leaderboard_bottom = leaderboard_panel.offset_bottom

func _apply_responsive_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if not _is_mobile_like_portrait(viewport_size):
		_apply_ui_scale(1.0)
		return
	var scale_factor := clampf(viewport_size.y / 1280.0, 1.2, 2.0)
	_apply_ui_scale(scale_factor)

func _is_mobile_like_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x * 1.2 and viewport_size.x < 1500.0

func _apply_ui_scale(scale_factor: float) -> void:
	_ui_scale_factor = scale_factor

	if score_label != null:
		score_label.add_theme_font_size_override("font_size", int(round(_base_score_font_size * scale_factor)))
	if leaderboard_title_label != null:
		leaderboard_title_label.add_theme_font_size_override("font_size", int(round(_base_leaderboard_title_font_size * scale_factor)))
	if leaderboard_label != null:
		leaderboard_label.add_theme_font_size_override("font_size", int(round(_base_leaderboard_font_size * scale_factor)))
	if congrats_label != null:
		congrats_label.add_theme_font_size_override("font_size", int(round(_base_congrats_font_size * scale_factor)))
	if name_prompt_title_label != null:
		name_prompt_title_label.add_theme_font_size_override("font_size", int(round(_base_name_prompt_title_font_size * scale_factor)))
	if name_input != null:
		name_input.add_theme_font_size_override("font_size", int(round(_base_name_input_font_size * scale_factor)))
		var input_min_height := maxf(44.0, _base_name_input_min_size.y * scale_factor)
		name_input.custom_minimum_size = Vector2(_base_name_input_min_size.x, input_min_height)
	if name_submit_button != null:
		name_submit_button.add_theme_font_size_override("font_size", int(round(_base_name_submit_font_size * scale_factor)))
		var button_min_height := maxf(48.0, _base_name_submit_min_size.y * scale_factor)
		name_submit_button.custom_minimum_size = Vector2(_base_name_submit_min_size.x, button_min_height)

	if leaderboard_panel != null:
		var base_width := _base_leaderboard_right - _base_leaderboard_left
		var base_height := _base_leaderboard_bottom - _base_leaderboard_top
		var new_width := clampf(base_width * scale_factor, base_width, get_viewport().get_visible_rect().size.x * 0.75)
		var new_height := clampf(base_height * scale_factor, base_height, get_viewport().get_visible_rect().size.y * 0.45)
		leaderboard_panel.offset_right = _base_leaderboard_right
		leaderboard_panel.offset_left = leaderboard_panel.offset_right - new_width
		leaderboard_panel.offset_top = _base_leaderboard_top
		leaderboard_panel.offset_bottom = leaderboard_panel.offset_top + new_height

	if congrats_label != null and leaderboard_panel != null:
		var base_congrats_height := _base_congrats_bottom - _base_congrats_top
		congrats_label.offset_right = leaderboard_panel.offset_right
		congrats_label.offset_left = leaderboard_panel.offset_left
		congrats_label.offset_top = leaderboard_panel.offset_bottom + 12.0
		congrats_label.offset_bottom = congrats_label.offset_top + clampf(base_congrats_height * scale_factor, base_congrats_height, 140.0)

	if name_prompt != null:
		name_prompt.offset_left = _base_name_prompt_left * scale_factor
		name_prompt.offset_top = _base_name_prompt_top * scale_factor
		name_prompt.offset_right = _base_name_prompt_right * scale_factor
		name_prompt.offset_bottom = _base_name_prompt_bottom * scale_factor

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
