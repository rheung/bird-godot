extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  SilentWolf.configure({
	"api_key": "k1AQz8xJZI1cGIjZqgGiT5NiIBZUR7eP1p9XtNIP",
	"game_id": "bird-godot",
	"game_version": "1.0.2",
	"log_level": 1
  })

  SilentWolf.configure_scores({
	"open_scene_on_close": "res://scenes/main.tscn"
  })
