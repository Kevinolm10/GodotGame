extends Node3D

@onready var ground = $Map/Ground

func _ready() -> void:
	call_deferred("_create_world_border")
	#get_tree().debug_collisions_hint = true

func _create_world_border() -> void:
	# Taken directly from Global AABB output
	var border_size_x : float = 43.36
	var border_size_z : float = 36.08
	var wall_bottom   : float = -2.0
	var wall_top      : float = 10.0
	var wall_height   : float = wall_top - wall_bottom
	var wall_center_y : float = wall_bottom + wall_height / 2.0
	var wall_thickness: float = 1.0

	var walls: Array = [
		[Vector3(0,               wall_center_y,  border_size_z), Vector3(border_size_x, wall_height, wall_thickness)],
		[Vector3(0,               wall_center_y, -border_size_z), Vector3(border_size_x, wall_height, wall_thickness)],
		[Vector3( border_size_x,  wall_center_y,  0),             Vector3(wall_thickness, wall_height, border_size_z)],
		[Vector3(-border_size_x,  wall_center_y,  0),             Vector3(wall_thickness, wall_height, border_size_z)],
	]

	for i in walls.size():
		var wall_data = walls[i]
		var static_body := StaticBody3D.new()
		static_body.name = "BorderWall_" + str(i)
		add_child(static_body)
		static_body.global_position = wall_data[0]

		var col_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall_data[1] * 2.0
		col_shape.shape = box
		static_body.add_child(col_shape)
		print("[Border] Wall ", i, " global pos: ", static_body.global_position, " box size: ", box.size)

func _process(_delta: float) -> void:
	pass
