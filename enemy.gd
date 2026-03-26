extends CharacterBody3D

var speed = 3
var detection_range = 10
var health = 100
var attack_damage = 10
var attack_range = 2.0
var attack_cooldown = false
var is_attacking = false
var is_dead = false
var direction = Vector3.ZERO
var player_in_range = false
var start_position: Vector3

@onready var player = get_tree().get_first_node_in_group("player")
@onready var ray = $Area3D/RayCast3D
@onready var hp_bar = $hp_bar_root/enemyHP
@onready var hp_bg = $hp_bar_root/hp_bg
var anim: AnimationPlayer

func _ready():
	start_position = global_position
	anim = find_child("AnimationPlayer", true, false)
	update_hp_visual()
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false

func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	health = max(health, 0)
	print("[Enemy] Took ", amount, " damage. Health remaining: ", health)
	update_hp_visual()
	if health <= 0:
		die()

func update_hp_visual():
	if not hp_bar:
		return
	var ratio = float(health) / 100.0

	# scale the green bar and shift it left so it depletes from the right
	hp_bar.scale.x = max(ratio, 0.001)
	hp_bar.position.x = (ratio - 1.0) * 0.5

	# keep bg pinned to the same position as the bar root, no offset
	hp_bg.position.x = 0.0
	hp_bg.scale.x = 1.0

	# color changes gradually as health drops — green at full, red at zero
	var mat = hp_bar.get_surface_override_material(0)
	if mat:
		mat.albedo_color = Color(1.0 - ratio, ratio, 0.0)

func die():
	is_dead = true
	is_attacking = false
	attack_cooldown = false
	velocity = Vector3.ZERO
	for child in find_children("*", "CollisionShape3D", true, false):
		child.disabled = true
	if anim:
		anim.play("die")
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn():
	global_position = start_position
	is_dead = false
	is_attacking = false
	attack_cooldown = false
	health = 100
	direction = Vector3.ZERO
	player_in_range = false
	for child in find_children("*", "CollisionShape3D", true, false):
		child.disabled = false
	update_hp_visual()
	if anim:
		anim.play("idle")

func _attack():
	if attack_cooldown or is_dead:
		return
	is_attacking = true
	attack_cooldown = true
	velocity = Vector3.ZERO
	if anim:
		anim.play("attack-melee-right")
	player.health -= attack_damage
	player.health = max(player.health, 0)
	if player.ui:
		player.ui.update_health(player.health)
	print("[Enemy] Hit player for ", attack_damage, " damage. Player health: ", player.health)
	if player.health <= 0 and not player.is_dead:
		player.die()
	await get_tree().create_timer(1.5).timeout
	is_attacking = false
	attack_cooldown = false

func detect_player(delta):
	if is_dead or is_attacking:
		return
	if player_in_range:
		ray.target_position = ray.to_local(player.global_position)
		ray.force_raycast_update()
		if ray.is_colliding():
			if ray.get_collider().is_in_group("player"):
				direction = (player.global_position - global_position).normalized()
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
				look_at(player.global_position, Vector3.UP)
				rotate_y(deg_to_rad(180))
			else:
				velocity.x = 0
				velocity.z = 0
				direction = Vector3.ZERO
		else:
			velocity.x = 0
			velocity.z = 0
			direction = Vector3.ZERO
	else:
		velocity.x = 0
		velocity.z = 0
		direction = Vector3.ZERO
	move_and_slide()

func _process(delta):
	if player == null or is_dead or player.is_dead:
		return
	detect_player(delta)
	var dist = global_position.distance_to(player.global_position)
	if dist < attack_range and not attack_cooldown:
		_attack()
	elif not is_attacking:
		if anim:
			if direction.length() > 0:
				anim.play("sprint")
			else:
				anim.play("idle")
