extends MultiMeshInstance3D

func _ready() -> void:
	multimesh.instance_count = 50
	for i in range(50):
		var t = Transform3D()
		t.origin = Vector3(i * 2, 0, 0)
		multimesh.set_instance_transform(i, t)
