extends RigidBody3D

# ──────────────────────────────────────────────
#  State machine
# ──────────────────────────────────────────────
enum State { PATROL, COMBAT, DEAD }
var state: State = State.PATROL

# ──────────────────────────────────────────────
#  Exports
# ──────────────────────────────────────────────
@export var faction: String = "red"
@export var max_health: float = 100.0
@export var patrol_speed: float = 5.0
@export var cannon_range: float = 30.0
@export var detection_range: float = 50.0
@export var fire_rate: float = 2.5
@export var turn_speed: float = 0.8
@export var cannonball_scene: PackedScene
@export var water_height: float = 0.0
@export var patrol_points: Array[NodePath] = []

# ──────────────────────────────────────────────
#  Runtime vars
# ──────────────────────────────────────────────
var health: float
var target: Node3D = null
var fire_timer: float = 0.0
var patrol_index: int = 0
var _patrol_nodes: Array[Node3D] = []

# ──────────────────────────────────────────────
#  Node references
# ──────────────────────────────────────────────
@onready var detection_zone: Area3D = $DetectionZone
@onready var l_cannon: Node3D = $Hull/l_cannon if has_node("Hull/l_cannon") else null
@onready var r_cannon: Node3D = $Hull/r_cannon if has_node("Hull/r_cannon") else null

# ──────────────────────────────────────────────
#  Ready
# ──────────────────────────────────────────────
func _ready() -> void:
	print(global_transform.basis.z)

	angular_damp = 5.0
	linear_damp = 1.5

	health = max_health
	add_to_group("pirate_ship")

	gravity_scale = 0.0
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true

	for path in patrol_points:
		var n = get_node_or_null(path)
		if n:
			_patrol_nodes.append(n)

	detection_zone.body_entered.connect(_on_body_entered)
	detection_zone.body_exited.connect(_on_body_exited)

# ──────────────────────────────────────────────
#  Physics loop
# ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_snap_to_water()

	match state:
		State.PATROL: _do_patrol(delta)
		State.COMBAT: _do_combat(delta)
		State.DEAD:   pass

# ──────────────────────────────────────────────
#  Water lock
# ──────────────────────────────────────────────
func _snap_to_water() -> void:
	global_position.y = water_height
	linear_velocity.y = 0.0

# ──────────────────────────────────────────────
#  PATROL
# ──────────────────────────────────────────────
func _do_patrol(delta: float) -> void:
	if _patrol_nodes.is_empty():
		return

	var goal: Vector3 = _patrol_nodes[patrol_index].global_position

	_rotate_toward(goal, delta)
	_move_forward(patrol_speed)

	if _flat_distance(global_position, goal) < 4.0:
		patrol_index = (patrol_index + 1) % _patrol_nodes.size()

# ──────────────────────────────────────────────
#  COMBAT
# ──────────────────────────────────────────────
func _do_combat(delta: float) -> void:
	if not _is_target_valid():
		_lose_target()
		return

	# Keep following the patrol path exactly as normal
	_do_patrol(delta)

	# Fire on a timer if broadside is aligned
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_rate
		if _has_line_of_sight():
			_fire_cannons()

# ──────────────────────────────────────────────
#  PATROL ADVANCEMENT (used during combat too)
# ──────────────────────────────────────────────
func _advance_patrol(delta: float) -> void:
	if _patrol_nodes.is_empty():
		return

	var goal: Vector3 = _patrol_nodes[patrol_index].global_position

	# Steer toward patrol waypoint but try to keep broadside facing target
	_rotate_toward_with_broadside(goal, delta)
	_move_forward(patrol_speed)

	if _flat_distance(global_position, goal) < 4.0:
		patrol_index = (patrol_index + 1) % _patrol_nodes.size()

# ──────────────────────────────────────────────
#  MOVEMENT
# ──────────────────────────────────────────────
func _move_forward(speed: float) -> void:
	var forward: Vector3 = global_transform.basis.z
	linear_velocity.x = forward.x * speed
	linear_velocity.z = forward.z * speed

func _rotate_toward(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = target_pos - global_position
	dir.y = 0.0

	if dir.length() < 0.01:
		return

	dir = dir.normalized()

	var forward: Vector3 = global_transform.basis.z
	var angle: float = forward.signed_angle_to(dir, Vector3.UP)

	angular_velocity.y = angle * turn_speed

# Rotates the ship so its broadside (X axis) faces the target while
# still generally steering toward the patrol waypoint.
func _rotate_toward_with_broadside(patrol_goal: Vector3, delta: float) -> void:
	if not _is_target_valid():
		_rotate_toward(patrol_goal, delta)
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	if to_target.length() < 0.01:
		_rotate_toward(patrol_goal, delta)
		return

	to_target = to_target.normalized()

	# Which side is the target on?
	var right_dot: float = global_transform.basis.x.dot(to_target)
	# Desired broadside offset: rotate 90° so the X axis faces the target
	var broadside_angle: float = PI / 2.0 if right_dot >= 0.0 else -PI / 2.0

	var bow_basis: Basis = Basis.looking_at(to_target, Vector3.UP)
	var target_basis: Basis = bow_basis.rotated(Vector3.UP, broadside_angle)

	# Smoothly slerp the ship's basis toward the broadside orientation
	basis = basis.slerp(target_basis, delta * turn_speed)

# ──────────────────────────────────────────────
#  DISTANCE HELPER
# ──────────────────────────────────────────────
func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# ──────────────────────────────────────────────
#  DETECTION
# ──────────────────────────────────────────────
func _on_body_entered(body: Node3D) -> void:
	if state == State.DEAD:
		return

	if _should_target(body):
		target = body
		state = State.COMBAT

func _on_body_exited(body: Node3D) -> void:
	if body == target:
		_lose_target()

func _should_target(body: Node3D) -> bool:
	if body == self:
		return false
	if body.is_in_group("player"):
		return true
	if body.is_in_group("pirate_ship"):
		return body.get("faction") != faction
	return false

func _lose_target() -> void:
	target = null
	state = State.PATROL

func _is_target_valid() -> bool:
	return target != null and is_instance_valid(target)

# ──────────────────────────────────────────────
#  FIRING
# ──────────────────────────────────────────────
func _has_line_of_sight() -> bool:
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	return abs(global_transform.basis.x.dot(to_target)) > 0.5

func _fire_cannons() -> void:
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	var right_dot: float = global_transform.basis.x.dot(to_target)

	var cannon: Node3D = r_cannon if right_dot >= 0.0 else l_cannon
	if cannon:
		_shoot_from(cannon)

func _shoot_from(cannon: Node3D) -> void:
	if cannonball_scene == null:
		return

	var ball: RigidBody3D = cannonball_scene.instantiate()
	get_tree().current_scene.add_child(ball)

	ball.global_position = cannon.global_position
	ball.add_collision_exception_with(self)

	var dir: Vector3 = (target.global_position - cannon.global_position).normalized()
	ball.linear_velocity = dir * ball.speed

# ──────────────────────────────────────────────
#  DAMAGE
# ──────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return

	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	linear_velocity = Vector3.ZERO
