extends CharacterBody3D

# ─── Constants ────────────────────────────────────────────────────────────────

const MAX_HEALTH    := 100
const SPEED         := 3.0
const ATTACK_DAMAGE := 10
const ATTACK_RANGE  := 2.0
const TURN_SPEED    := 10.0

# Attack timing (seconds)
const ATTACK_WINDUP   := 0.4
const ATTACK_ACTIVE   := 0.2
const ATTACK_RECOVERY := 0.9

# ─── State ────────────────────────────────────────────────────────────────────

var health         : int     = MAX_HEALTH
var is_dead        : bool    = false
var is_attacking   : bool    = false
var attack_cooldown: bool    = false
var player_in_range: bool    = false
var direction      : Vector3 = Vector3.ZERO
var already_hit    : Array   = []
var start_position : Vector3

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var player         = get_tree().get_first_node_in_group("player")
@onready var ray            = $detectionzone/RayCast3D
@onready var detection_area = $detectionzone
@onready var hitbox         = $hitbox
@onready var hp_bar         = $hp_bar_root/enemyHP
@onready var hp_bg          = $hp_bar_root/hp_bg
var anim: AnimationPlayer

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	start_position    = global_position
	anim              = find_child("AnimationPlayer", true, false)
	hitbox.monitoring = false
	update_hp_visual()
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	hitbox.body_entered.connect(_on_hitbox_hit)

# ─── Detection zone ───────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if player == null or is_dead or player.is_dead:
		return

	# Always track player rotation, even while attacking
	_face_player(delta)
	_handle_movement(delta)

	if not is_attacking:
		var dist := global_position.distance_to(player.global_position)
		if dist < ATTACK_RANGE and not attack_cooldown:
			_attack()
		else:
			_play_anim("sprint" if direction.length() > 0 else "idle")

func _face_player(delta: float) -> void:
	if player == null or is_dead:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 0.5:
		return
	var target_pos: Vector3  = player.global_position
	target_pos.y             = global_position.y
	var target_dir           := (target_pos - global_position).normalized()
	var target_basis         := Basis.looking_at(target_dir, Vector3.UP)
	global_transform.basis   = global_transform.basis.slerp(target_basis, TURN_SPEED * delta)

func _handle_movement(delta: float) -> void:
	if is_dead or is_attacking:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if player_in_range:
		var dist := global_position.distance_to(player.global_position)
		ray.target_position = ray.to_local(player.global_position)
		ray.force_raycast_update()

		if ray.is_colliding() and ray.get_collider().is_in_group("player"):
			direction = (player.global_position - global_position).normalized()
			if dist > ATTACK_RANGE:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.x = 0
				velocity.z = 0
		else:
			_stop_moving()
	else:
		_stop_moving()

	move_and_slide()

func _stop_moving() -> void:
	velocity.x = 0
	velocity.z = 0
	direction  = Vector3.ZERO

# ─── Combat ───────────────────────────────────────────────────────────────────

func _attack() -> void:
	if attack_cooldown or is_dead:
		return
	is_attacking    = true
	attack_cooldown = true
	already_hit.clear()
	_play_anim("attack-melee-right")

	await get_tree().create_timer(ATTACK_WINDUP).timeout
	hitbox.monitoring = true
	await get_tree().create_timer(ATTACK_ACTIVE).timeout
	hitbox.monitoring = false
	await get_tree().create_timer(ATTACK_RECOVERY).timeout

	is_attacking    = false
	attack_cooldown = false

func _on_hitbox_hit(body: Node) -> void:
	if not body.is_in_group("player") or body in already_hit:
		return
	already_hit.append(body)
	body.health = max(body.health - ATTACK_DAMAGE, 0)
	if body.ui:
		body.ui.update_health(body.health)
	if body.health <= 0 and not body.is_dead:
		body.die()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(health - amount, 0)
	update_hp_visual()
	if health <= 0:
		die()

# ─── Life cycle ───────────────────────────────────────────────────────────────

func die() -> void:
	is_dead         = true
	is_attacking    = false
	attack_cooldown = false
	velocity        = Vector3.ZERO

	var player = get_tree().get_first_node_in_group("player")
	if player and player.ui:
		player.ui.add_kill()

	_set_collisions(true)
	_play_anim("die")
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn() -> void:
	global_position = start_position
	health          = MAX_HEALTH
	is_dead         = false
	is_attacking    = false
	attack_cooldown = false
	player_in_range = false
	direction       = Vector3.ZERO
	_set_collisions(false)
	update_hp_visual()
	_play_anim("idle")

func _set_collisions(disabled: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		child.disabled = disabled

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _play_anim(name: String) -> void:
	if anim and anim.current_animation != name:
		anim.play(name)

func update_hp_visual() -> void:
	if not hp_bar:
		return
	var ratio         := float(health) / float(MAX_HEALTH)
	hp_bar.scale.x    = max(ratio, 0.001)
	hp_bar.position.x = (ratio - 1.0) * 0.5
	hp_bg.position.x  = 0.0
	hp_bg.scale.x     = 1.0
	var mat: StandardMaterial3D = hp_bar.get_surface_override_material(0)
	if mat:
		mat.albedo_color = Color(1.0 - ratio, ratio, 0.0)
