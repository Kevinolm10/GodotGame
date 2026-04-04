extends Node3D

var player_nearby = false

func _ready():
	add_to_group("loot")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
