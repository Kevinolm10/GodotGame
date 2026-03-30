extends Control

@onready var health_bar   : ProgressBar = $ProgressBar
@onready var health_label : Label       = $Label
@onready var crosshair    : Label       = $crosshair
@onready var kill_label   : Label       = $killcount  # add this Label node in the editor

var kill_count: int = 0

func _ready() -> void:
	health_bar.max_value = 100
	health_bar.value     = 100
	crosshair.text       = "+"
	kill_label.text      = "Kills: 0"

func update_health(new_health: int) -> void:
	health_bar.value  = new_health
	health_label.text = "HP: " + str(new_health)

func add_kill() -> void:
	kill_count       += 1
	kill_label.text   = "Kills: " + str(kill_count)
