extends CharacterBody3D

# ─── Constants ────────────────────────────────────────────────────────────────

const SPEED             := 3.0
const RUN_SPEED         := 6.0
const GRAVITY           := -9.8
const JUMP_FORCE        := 5.0
const MOUSE_SENSITIVITY := 0.003
const FOV_DEFAULT       := 70.0
const FOV_RUN           := 100.0
const FOV_SMOOTH        := 5.0
const ATTACK_RANGE      := 2.0
const ATTACK_DAMAGE     := 50

# ─── State ────────────────────────────────────────────────────────────────────

var health        : int  = 100
var is_dead       : bool = false
var is_jumping    : bool = false
var is_attacking  : bool = false
var is_interacting: bool = false
var is_paused     : bool = false

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var camera: Camera3D        = $Camera3D
@onready var anim  : AnimationPlayer = $keeper/AnimationPlayer
@onready var ui                      = $playerUI/Control

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if ui:
		ui.update_health(health)

# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if is_dead:
		return

	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

	if is_paused:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)

func _toggle_pause() -> void:
	is_paused         = !is_paused
	get_tree().paused = is_paused
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED
	)

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_dead or is_paused:
		return

	_apply_gravity(delta)
	_handle_attack()
	_handle_interact()
	_handle_movement(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_interacting:
		is_attacking = true
		anim.play("attack-melee-right")
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if global_position.distance_to(enemy.global_position) < ATTACK_RANGE:
				enemy.take_damage(ATTACK_DAMAGE)

	if is_attacking and not anim.is_playing():
		is_attacking = false

func _handle_interact() -> void:
	if Input.is_action_just_pressed("interact") and not is_interacting and not is_attacking:
		is_interacting = true
		anim.play("interact-right")

	if is_interacting and not anim.is_playing():
		is_interacting = false

func _handle_movement(delta: float) -> void:
	var input_dir  := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction  := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, rotation.y).normalized()
	var is_running := Input.is_action_pressed("run")
	var speed      := RUN_SPEED if is_running else SPEED
	var moving     := direction.length() > 0

	# During actions, zero horizontal velocity but still apply gravity/slide
	if is_attacking or is_interacting:
		velocity.x = 0
		velocity.z = 0
		return

	if is_on_floor():
		if is_jumping:
			is_jumping = false

		if moving:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			_play_anim("sprint" if is_running else "walk")
		else:
			velocity.x = 0
			velocity.z = 0
			_play_anim("idle")

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_FORCE
			is_jumping  = true
			anim.play("jump")

	else:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if is_jumping:
			_play_anim("jump")

	if Input.is_action_pressed("sit"):
		_play_anim("crouch")

	var target_fov: float = FOV_RUN if is_running and moving else FOV_DEFAULT
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_SMOOTH)

# ─── Life cycle ───────────────────────────────────────────────────────────────

func die() -> void:
	if is_dead:
		return
	is_dead  = true
	velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim.play("die")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _play_anim(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)
