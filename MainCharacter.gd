extends CharacterBody3D

# ─── Constants ──────────────────────────────────────────────────────────────────
const SPEED             := 3.0
const RUN_SPEED         := 6.0
const GRAVITY           := -9.8
const JUMP_FORCE        := 5.0
const MOUSE_SENSITIVITY := 0.003
const FOV_DEFAULT       := 70.0
const FOV_RUN           := 100.0
const FOV_SMOOTH        := 5.0
const ATTACK_RANGE      := 2.0
const ATTACK_COOLDOWN     : float = 1.2


# ─── Variables ──────────────────────────────────────────────────────────────────
var inventory      : Array = []
var xp_gained_from : Array = []
var attack_cooldown_timer : float = 0.0
var ATTACK_DAMAGE     := 25


# ─── State ──────────────────────────────────────────────────────────────────────
var health        : int  = 100
var health_regen : int = 10
var is_dead       : bool = false
var is_jumping    : bool = false
var is_attacking  : bool = false
var is_interacting: bool = false
var is_paused     : bool = false
var is_in_combat  : bool = false
var combat_timer  : float = 0.0
const COMBAT_TIMEOUT := 5.0

# ─── Level / XP ─────────────────────────────────────────────────────────────────
var level           : int = 1
var xp              : int = 0
var xp_to_next_level: int = 100

# ─── Nodes ──────────────────────────────────────────────────────────────────────
@onready var camera         : Camera3D        = $Camera3D
@onready var anim           : AnimationPlayer = $keeper/AnimationPlayer
@onready var ui                               = $playerUI/Control
@onready var loot_label     : Label           = $playerUI/Control/loot
@onready var xp_progress_bar: ProgressBar     = $playerUI/XP/xp_progress
@onready var level_label    : Label           = $playerUI/XP/Level

# ─── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Load from GameState
	health           = GameState.health
	level            = GameState.level
	xp               = GameState.xp
	xp_to_next_level = GameState.xp_to_next_level
	inventory        = GameState.inventory.duplicate()

	if ui:
		ui.update_health(health)
	_update_loot_label()
	_refresh_xp_ui()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.respawned.connect(_on_enemy_respawned.bind(enemy))

	regen()
# ─── Input ──────────────────────────────────────────────────────────────────────
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
	is_paused = !is_paused
	get_tree().paused = is_paused
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED)

# ─── Physics ────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead or is_paused:
		return
	if is_in_combat:
		combat_timer -= delta
		if combat_timer <= 0.0:
			is_in_combat = false
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
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

# ─── Attack ─────────────────────────────────────────────────────────────────────
func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_interacting and attack_cooldown_timer <= 0.0:
		is_attacking = true
		attack_cooldown_timer = ATTACK_COOLDOWN
		anim.play("attack-melee-right")
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if global_position.distance_to(enemy.global_position) < ATTACK_RANGE:
				if not enemy.is_dead:
					enemy.take_damage(ATTACK_DAMAGE)
					if enemy.is_dead and enemy not in xp_gained_from:
						xp_gained_from.append(enemy)
						gain_xp(20)
						gain_gold(10)

	if is_attacking and not anim.is_playing():
		is_attacking = false

# ─── Interact / Pickup ──────────────────────────────────────────────────────────
func _handle_interact() -> void:
	if Input.is_action_just_pressed("interact") and not is_interacting and not is_attacking:
		is_interacting = true
		anim.play("interact-right")
		for item in get_tree().get_nodes_in_group("loot"):
			if not item or not item.is_inside_tree():
				continue
			if global_position.distance_to(item.global_position) < 2.0:
				_pickup_item(item)

	if is_interacting and not anim.is_playing():
		is_interacting = false

# ─── Movement ───────────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction  := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, rotation.y).normalized()
	var is_running := Input.is_action_pressed("run")
	var speed      := RUN_SPEED if is_running else SPEED
	var moving     := direction.length() > 0

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
			velocity.y  = JUMP_FORCE
			is_jumping   = true
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

# ─── Damage ─────────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(health - amount, 0)
	is_in_combat = true
	combat_timer = COMBAT_TIMEOUT
	if ui:
		ui.update_health(health)
	if health <= 0:
		die()

# ─── Regen ─────────────────────────────────────────────────────────────────────

func _any_enemy_chasing() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.player_in_range:
			return true
	return false

func regen() -> void:
	while true:
		await get_tree().create_timer(4.0).timeout
		if not is_dead and not is_in_combat and not _any_enemy_chasing():
			health = min(health + health_regen, GameState.max_health)
			if ui:
				ui.update_health(health)
				print("Health: ", health)


# ─── Life cycle ────────────────────────	─────────────────────────────────────────
func die() -> void:
	if is_dead:
		return

	# Save to GameState BEFORE anything changes
	GameState.health           = GameState.max_health
	GameState.level            = level
	GameState.xp               = xp
	GameState.xp_to_next_level = xp_to_next_level
	GameState.inventory        = inventory.duplicate()

	is_dead  = true
	velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim.play("die")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

# ─── Enemy respawn callback ──────────────────────────────────────────────────────
func _on_enemy_respawned(enemy: Node) -> void:
	xp_gained_from.erase(enemy)

# ─── Helpers ────────────────────────────────────────────────────────────────────
func _play_anim(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)

# ─── Inventory / Pickup ─────────────────────────────────────────────────────────
func _pickup_item(item: Node) -> void:
	if not item or not item.is_inside_tree():
		return
	if item.get_child_count() > 0:
		for child in item.get_children():
			if child is Node3D:
				_add_to_inventory(child)
				child.queue_free()
	else:
		_add_to_inventory(item)
		item.queue_free()

func _add_to_inventory(item: Node3D) -> void:
	inventory.append(item.name)
	GameState.inventory = inventory.duplicate()
	_update_loot_label()
	print("Picked up:", item.name)

func _update_loot_label() -> void:
	if loot_label:
		loot_label.text = "Inventory: " + ", ".join(inventory)

# ─── XP / Leveling ──────────────────────────────────────────────────────────────
func gain_xp(amount: int) -> void:
	xp += amount
	print("Gained XP:", amount, " Total XP:", xp)
	_refresh_xp_ui()
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level_up()

func level_up() -> void:
	level            += 1
	xp_to_next_level  = int(xp_to_next_level * 1.5)
	health           += 10
	GameState.max_health += 10
	ATTACK_DAMAGE += 5
	print("Level Up! New level:", level, " XP for next level:", xp_to_next_level)
	print(ATTACK_DAMAGE)
	if ui:
		ui.update_health(health)
	_refresh_xp_ui()

func gain_gold(amount: int) -> void:
	if ui:
		ui.add_gold(amount)
		print("Gold gained:", amount)

func _refresh_xp_ui() -> void:
	if xp_progress_bar:
		xp_progress_bar.value = float(xp) / float(xp_to_next_level) * xp_progress_bar.max_value
	if level_label:
		level_label.text = "Level: " + str(level)
