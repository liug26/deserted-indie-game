extends Node2D

"""
Item scene, presents a TextureButton displaying an item, and a
Label displaying the price of the Item. Initialized and set by
Game/UI
"""

# a number from 0-4 assigned by Game/UI, denotes what item the
# scene should be displaying. If type = 0: speed, = 2: heal,
# = 3: resurrection, = 4: game pass
var type


# called by Game/UI, sets the type and the price of the item,
# price displayed in Label and type displayed as a texture in TextureButton
func set(type, price):
	self.type = type
	var texture
	if type == 0:
		texture = load("res://assets/image/item/speed.png")
	elif type == 1:
		texture = load("res://assets/image/item/heal.png")
	elif type == 2:
		texture = load("res://assets/image/item/resurrection.png")
	elif type == 3:
		texture = load("res://assets/image/item/game_pass.png")
	$TextureButton.texture_normal = texture
	$Label.text = str(price)


# when TextureButton is pressed, the displaying item is bought
# update the type of item bought to Game/UI
func _on_TextureButton_pressed():
	get_node("/root/Game/UI").on_item_bought(type)
