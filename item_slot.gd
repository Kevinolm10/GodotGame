extends PanelContainer

@onready var texture_rect = $PanelContainer/ItemContainer/Item_Image
@onready var label        = $PanelContainer/ItemContainer/Item_label

func setup(item_name: String, item_texture: Texture2D) -> void:
	label.text           = item_name
	texture_rect.texture = item_texture
