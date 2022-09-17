extends Sprite

"""
Status scene is super simple, it is basically a easily changeable
sprite
"""


# set what image to display in the sprite. if type = 0: resurrection
# if type = 1: used resurrection, if type = 2: game pass
func set_type(type):
	if type == 0:
		texture = load("res://assets/image/item/resurrection.png")
	elif type == 1:
		texture = load("res://assets/image/item/resurrection_used.png")
	elif type == 2:
		texture = load("res://assets/image/item/game_pass.png")
