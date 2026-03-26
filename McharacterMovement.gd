extends CharacterBody3D
const SPEED = 5.0
const RUN_SPEED = 9.0
const GRAVITY = -9.8
const JUMP_FORCE = 5.0
const MOUSE_SENSITIVITY = 0.003
const FOV_DEFAULT = 75.0
const FOV_RUN = 100.0
const FOV_SPEED = 5.0
var health = 100
var is_dead = false
var is_jumping = false
var is_attacking = false
var is_paused = false
var is_interacting = false
@onready var camera = $Camera3D
@onready var anim = $keeper/AnimationPlayer
@onready var ui = $playerUI/Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var arm = $keeper/"character-keeper"/root/torso/"arm-right"
	var item = load("res://kenney_graveyard-kit_5.0/Models/GLB format/shovel.glb")
	var item_instance = item.instantiate()
	arm.add_child(item_instance)
	item_instance.position = Vector3(0.25, -0.35, 0.4)
	item_instance.rotation_degrees = Vector3(90.9, 180.0, 0.0)
	item_instance.scale = Vector3(0.9, 1.21, 1.0)
	if ui:
		ui.update_health(health)

func die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim.play("die")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _input(event):
	if is_dead:
		return
	if event.is_action_pressed("ui_cancel"):
		is_paused = !is_paused
		if is_paused:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	if is_paused:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)

func _physics_process(delta):
	if is_dead or is_paused:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		anim.play("attack-melee-left")
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 2.0:
				enemy.take_damage(50)
	if is_attacking:
		if not anim.is_playing():
			is_attacking = false
		move_and_slide()
		return
	if Input.is_action_just_pressed("interact") and not is_interacting:
		is_interacting = true
		anim.play("interact-right")
	if is_interacting:
		if not anim.is_playing():
			is_interacting = false
		move_and_slide()
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, rotation.y).normalized()
	var is_running := Input.is_action_pressed("run")
	var current_speed := RUN_SPEED if is_running else SPEED
	if is_on_floor():
		if is_jumping:
			is_jumping = false
		if direction.length() > 0:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			if is_running:
				if anim.current_animation != "sprint":
					anim.play("sprint")
			else:
				if anim.current_animation != "walk":
					anim.play("walk")
		else:
			velocity.x = 0
			velocity.z = 0
			if anim.current_animation != "idle":
				anim.play("idle")
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_FORCE
			is_jumping = true
			anim.play("jump")
	else:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if is_jumping and anim.current_animation != "jump":
			anim.play("jump")
	if Input.is_action_pressed("sit"):
		anim.play("crouch")
	var target_fov = FOV_RUN if is_running and direction.length() > 0 else FOV_DEFAULT
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_SPEED)
	move_and_slide()
