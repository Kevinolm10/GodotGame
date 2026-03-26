extends Node3D

var enemy_scene = preload("res://enemy.tscn")

func spawn_enemy():
	for i in range(10):
		var enemy = enemy_scene.instantiate()
		enemy.position = Vector3(randf_range(-20, 20), 1, randf_range(-20, 20))
		add_child(enemy)

func _ready() -> void:
	spawn_enemy()

func _process(delta: float) -> void:
	pass
