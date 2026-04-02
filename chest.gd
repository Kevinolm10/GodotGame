extends Node3D

@onready var zone = $Area3D
@onready var anim = $CryptCHObj/AnimationPlayer

var player_nearby = false
var is_open = false

func _ready():
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print(body.name)
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func _process(delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		print("Opening chest")
		open_chest()

func open_chest():
	if is_open:
		return
	is_open = true
	anim.play("lid_001Action")
