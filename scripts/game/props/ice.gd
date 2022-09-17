extends Area2D

"""
Ice scene, generated by Game/LevelGen, an Area2D that freezes
all enemies for some seconds upon colliding with player
"""

# for easier access to nodes
onready var audio = get_node("/root/Game/Audio")
onready var level_gen = get_node("/root/Game/LevelGen")
# values initialized by Game/LevelGen, are indices that point to corresponding
# LevelGen.prop
var tile_x
var tile_y


# initialize its tile indices in LevelGen.props
func initialize(tile_x, tile_y):
	self.tile_x = tile_x
	self.tile_y = tile_y


# when player collides with prop, frees self and update player
func _on_body_entered(body):
	if body.name == "Player":
		# updates LevelGen.props to signal an available location
		# to generate new props
		level_gen.props[tile_y][tile_x] = 0
		body.add_buff(5)
		# play audio for ice
		audio.get_node("Prop/Ice").play()
		queue_free()
