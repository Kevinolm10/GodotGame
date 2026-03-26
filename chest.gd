extends Node3D

@onready var zone = $Area3D
@onready var anim = $chest2/AnimationPlayer

var player_nearby = false
var is_open = false
var is_closed = false

func _ready():
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		print("Player entered chest zone")
		# TODO: show interaction prompt UI here

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		print("Player left chest zone")
		# TODO: hide interaction prompt UI here

func _process(delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		open_chest()

func open_chest():
	if is_open:
		is_open = false
		anim.play("close")
	else:
		is_open = true
		anim.play("open")
