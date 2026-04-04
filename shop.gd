extends Node3D

# ─── Variables ───────────────────────────────────────────────────────────────────
var player_nearby := false

@onready var zone     = $"shop-keeper/Area3D"
@onready var shop_ui  = $ShopUi

# ─── Setup ───────────────────────────────────────────────────────────────────
func _ready():
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	shop_ui.visible = false

# ─── Player Detection ─────────────────────────────────────────────────────────
func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		_close_shop()

# ─── Input ────────────────────────────────────────────────────────────────────
func _process(delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if shop_ui.visible:
			_close_shop()
		else:
			_open_shop()

# ─── Shop Logic ───────────────────────────────────────────────────────────────
func _open_shop():
	shop_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_shop():
	shop_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
