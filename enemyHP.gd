extends MeshInstance3D

func update_hp_visual(health: float):
	var ratio = health / 100.0
	scale.x = ratio
