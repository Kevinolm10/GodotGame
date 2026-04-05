extends RigidBody3D

@export var speed: float = 30.0
@export var damage: float = 20.0
@export var lifetime: float = 4.0

func _ready() -> void:
	gravity_scale = 0.0
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body == get_parent():
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
