extends Control

@onready var health_bar   : ProgressBar = $ProgressBar
@onready var health_label : Label       = $Label
@onready var crosshair    : Label       = $crosshair
@onready var kill_label   : Label       = $killcount
@onready var gold_label   : Label       = $Gold/GoldAmount

var kill_count: int = 0

func _ready() -> void:
	health_bar.max_value = 100
	health_bar.value     = GameState.health
	crosshair.text       = "+"
	kill_count           = GameState.kill_count
	kill_label.text      = "Kills: " + str(kill_count)
	gold_label.text      = "Gold: " + str(GameState.gold)

func update_health(new_health: int) -> void:
	health_bar.value  = new_health
	health_label.text = "HP: " + str(new_health)

func add_kill() -> void:
	kill_count           += 1
	GameState.kill_count  = kill_count
	kill_label.text       = "Kills: " + str(kill_count)

func add_gold(amount: int) -> void:
	GameState.gold  += amount
	gold_label.text  = "Gold: " + str(GameState.gold)
