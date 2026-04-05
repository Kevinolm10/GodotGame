extends Node3D

# ─── Constants ───────────────────────────────────────────────────────────────
const ItemSlot = preload("res://item_slot.tscn")

# ─── Variables ───────────────────────────────────────────────────────────────
var player_nearby := false
var items = [
	{ "name": "Chest",  "texture": preload("res://kenney_mini-dungeon/Previews/chest.png") },
	{ "name": "Bench",  "texture": preload("res://kenney_mini-dungeon/Previews/weapon-sword.png") },  # adjust this path
]


# ─── Node References ─────────────────────────────────────────────────────────
@onready var zone           = $"shop-keeper/Area3D"
@onready var shop_ui        = $ShopUi
@onready var item_container = $ShopUi/PanelContainer/ItemContainer

# ─── Setup ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	shop_ui.visible = false

# ─── Player Detection ────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		_close_shop()

# ─── Input ───────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		if shop_ui.visible:
			_close_shop()
		else:
			_open_shop()

# ─── Shop Logic ──────────────────────────────────────────────────────────────
func _open_shop() -> void:
	shop_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_shop()

func _close_shop() -> void:
	shop_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _populate_shop() -> void:
	for child in item_container.get_children():
		child.queue_free()

	for item in items:
		var slot = ItemSlot.instantiate()
		item_container.add_child(slot)
		slot.setup(item["name"], item["texture"])
