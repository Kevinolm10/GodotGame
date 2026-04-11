extends PanelContainer

@onready var texture_rect = $item_image
@onready var label        = $item_label

func setup(item_name: String, item_texture: Texture2D) -> void:
	label.text           = item_name
	texture_rect.texture = item_texture
