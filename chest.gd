extends Node3D

@onready var zone = $Area3D
@onready var anim = $CryptCHObj/AnimationPlayer

# Drag & drop loot bundle scenes in Inspector
@export var loot_table: Array[PackedScene] = []

var player_nearby := false
var is_open := false


# ─── Loot Spawn ──────────────────────────────────────────────────────────────

func _spawn_loot():
	if loot_table.is_empty():
		print("No loot assigned!")
		return

	var forward = -global_transform.basis.z

	for loot_scene in loot_table:
		var instance = loot_scene.instantiate()
		get_parent().add_child(instance)
		instance.global_transform.origin = global_position + forward * 1.5 + Vector3(
			randf_range(-1.5, 1.5),
			randf_range(0.5, 1.5),
			randf_range(-1.5, 1.5)
		)

		instance.add_to_group("loot")

		# Optional physics impulse for rigidbodies
		if instance is RigidBody3D:
			var dir = (forward + Vector3(randf(), 1, randf())).normalized()
			instance.apply_impulse(Vector3.ZERO, dir * randf_range(2.0, 5.0))

		print("Spawned loot:", instance.name)


# ─── Setup ───────────────────────────────────────────────────────────────────

func _ready():
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


# ─── Player Detection ─────────────────────────────────────────────────────────

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false


# ─── Input ────────────────────────────────────────────────────────────────────

func _process(delta):
	if player_nearby and not is_open and Input.is_action_just_pressed("interact"):
		open_chest()


# ─── Chest Logic ─────────────────────────────────────────────────────────────

func toggle_chest():
	if is_open:
		close_chest()
	else:
		open_chest()


func open_chest():
	if is_open:
		return  # Already open, do nothing

	is_open = true
	print("Opening chest")

	# Play lid animation forward
	anim.play("lid_001Action")

	# Small delay to sync loot spawn with lid animation
	await get_tree().create_timer(0.3).timeout

	_spawn_loot()


func close_chest():
	if not is_open:
		return  # Already closed

	is_open = false
	print("Closing chest")

	# Make sure animation starts at the end
	anim.play("lid_001Action")
	anim.seek(anim.current_animation_length, true)  # Jump to the end
	anim.play_backwards("lid_001Action")
