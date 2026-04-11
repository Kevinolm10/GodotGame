extends CharacterBody3D

# ─── Signals ────────────────────────────────────────────────────────────────────
signal respawned

# ─── Constants ──────────────────────────────────────────────────────────────────
const MAX_HEALTH      := 100
const SPEED           := 3.0
const ATTACK_DAMAGE   := 10
const ATTACK_RANGE    := 0.8
const TURN_SPEED      := 10.0
const PATROL_SPEED    := 1.5

const ATTACK_WINDUP   := 0.4
const ATTACK_ACTIVE   := 0.2
const ATTACK_RECOVERY := 0.9

# ─── State ──────────────────────────────────────────────────────────────────────
var health          : int     = MAX_HEALTH
var is_dead         : bool    = false
var is_attacking    : bool    = false
var attack_cooldown : bool    = false
var player_in_range : bool    = false
var direction       : Vector3 = Vector3.ZERO
var already_hit     : Array   = []
var start_position  : Vector3

var patrol_points        : Array[Vector3] = []
var current_patrol_index : int  = 0
var patrol_forward       : bool = true
var is_patrolling        : bool = false

# ─── Nodes ──────────────────────────────────────────────────────────────────────
@onready var player         : CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var ray                              = $detectionzone/RayCast3D
@onready var detection_area                   = $detectionzone
@onready var hitbox                           = $hitbox
@onready var hp_bar                           = $hp_bar_root/enemyHP
@onready var hp_bg                            = $hp_bar_root/hp_bg

var anim: AnimationPlayer

# ─── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	start_position    = global_position
	anim              = find_child("AnimationPlayer", true, false)
	hitbox.monitoring = false
	update_hp_visual()

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	hitbox.body_entered.connect(_on_hitbox_hit)

	patrol_points = [
		start_position,
		start_position + Vector3(5, 0, 0),
		start_position + Vector3(5, 0, 5),
		start_position + Vector3(0, 0, 5)
	]
	is_patrolling = true

# ─── Detection zone ─────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if is_dead: return
	if body.is_in_group("player"):
		player_in_range = false

# ─── Physics ────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if player == null or is_dead or player.is_dead:
		return

	if player_in_range:
		_face_player(delta)
		_handle_movement(delta)
		if not is_attacking:
			var dist := global_position.distance_to(player.global_position)
			if dist < ATTACK_RANGE and not attack_cooldown:
				_attack()
			else:
				_play_anim("sprint" if direction.length() > 0 else "idle")
	else:
		_patrol(delta)

func _face_player(delta: float) -> void:
	if player == null or is_dead: return
	var dist := global_position.distance_to(player.global_position)
	if dist < 0.5: return
	var target_pos  : Vector3 = player.global_position
	target_pos.y              = global_position.y
	var target_dir   := (target_pos - global_position).normalized()
	var target_basis := Basis.looking_at(target_dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_basis, TURN_SPEED * delta)

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

# ─── Patrol ─────────────────────────────────────────────────────────────────────
func _patrol(delta: float) -> void:
	if not is_patrolling or patrol_points.size() == 0:
		return

	var target         := patrol_points[current_patrol_index]
	var dist_to_target := global_position.distance_to(target)

	if dist_to_target < 0.1:
		if patrol_forward:
			current_patrol_index += 1
			if current_patrol_index >= patrol_points.size():
				current_patrol_index = patrol_points.size() - 2
				patrol_forward       = false
		else:
			current_patrol_index -= 1
			if current_patrol_index < 0:
				current_patrol_index = 1
				patrol_forward       = true
	else:
		var dir    := (target - global_position).normalized()
		direction   = dir
		velocity.x  = direction.x * PATROL_SPEED
		velocity.z  = direction.z * PATROL_SPEED
		_play_anim("walk")
		_face_direction(delta)
		move_and_slide()

func _face_direction(delta: float) -> void:
	var target_pos  : Vector3 = global_position + direction
	var target_dir   := (target_pos - global_position).normalized()
	var target_basis := Basis.looking_at(target_dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_basis, TURN_SPEED * delta)

# ─── Combat ─────────────────────────────────────────────────────────────────────
func _attack() -> void:
	if attack_cooldown or is_dead: return
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
	if is_dead: return
	if not body.is_in_group("player") or body in already_hit: return
	already_hit.append(body)
	body.take_damage(ATTACK_DAMAGE)

func take_damage(amount: int) -> void:
	if is_dead: return
	health = max(health - amount, 0)
	update_hp_visual()
	if health <= 0:
		die()

# ─── Life cycle ─────────────────────────────────────────────────────────────────
func die() -> void:
	if is_dead: return
	is_dead         = true
	is_attacking    = false
	attack_cooldown = false
	velocity        = Vector3.ZERO

	var p = get_tree().get_first_node_in_group("player")
	if p and p.ui:
		p.ui.add_kill()

	_set_collisions(true)
	detection_area.monitoring  = false
	detection_area.monitorable = false
	hitbox.monitoring          = false
	_play_anim("die")
	await get_tree().create_timer(20.0).timeout
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
	detection_area.monitoring  = true
	detection_area.monitorable = true
	update_hp_visual()
	_play_anim("idle")
	emit_signal("respawned")

func _set_collisions(disabled: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		child.disabled = disabled

# ─── Helpers ────────────────────────────────────────────────────────────────────
func _play_anim(name: String) -> void:
	if anim and anim.current_animation != name:
		anim.play(name)

func update_hp_visual() -> void:
	if not hp_bar: return
	var ratio := float(health) / float(MAX_HEALTH)
	hp_bar.scale.x    = max(ratio, 0.001)
	hp_bar.position.x = (ratio - 1.0) * 0.5
	hp_bg.position.x  = 0.0
	hp_bg.scale.x     = 1.0
	var mat: StandardMaterial3D = hp_bar.get_surface_override_material(0)
	if mat:
		mat.albedo_color = Color(1.0 - ratio, ratio, 0.0)
