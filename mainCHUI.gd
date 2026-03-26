extends Control

@onready var health_bar = $ProgressBar
@onready var health_label = $Label
@onready var crosshair = $crosshair

func _ready():
	health_bar.max_value = 100
	health_bar.value = 100
	crosshair.text = "+"

func update_health(new_health: int):
	health_bar.value = new_health
	health_label.text = "HP: " + str(new_health)
