extends Node2D

"""
This scene is the welcome page, also program's entrance
everything should be self-explanatory
"""


# help to access nodes easily
onready var root = get_node("/root")
"""
if set to true, a new game will be started next frame.
this is due to queue_free() clears an object the next frame,
so if game were to be restarted, freeing the old scene and
instantiating a new scene in the same frame will cause the node name
of the new scene to be changed. Because I regularly use get_node()
with absolute paths, if the node name of the game scene were changed,
error will be thrown due to unfound nodes.
"""
var delayed_start_game = false
# gamemode, -1 = null, 0 = easy, 1 = medium, 2 = hard, 3 = nightmare
# this variable doesn't refer to the gamemode of the current game scene,
# but the gamemode of the game scene to be created if delayed_start_game = true
var mode = -1


# called when play button is pressed, pops out difficulty selection panel
func _on_Play_pressed():
	$Difficulty.visible = true


# detects mouse clicking event on frame, if clicked then closes pop-out panels
func _input(event):
	if event is InputEventMouseButton and $Difficulty.visible:
		var pos = event.position
		# if player is not clicking inside the panel
		if pos.x < 300 or pos.x > 600 or pos.y < 200 or pos.y > 600:
			$Difficulty.visible = false
	if event is InputEventMouseButton and $CreditsPanel.visible:
		var pos = event.position
		if pos.x < 334 or pos.x > 684 or pos.y < 246 or pos.y > 684:
			$CreditsPanel.visible = false


# instantiate game scene with gamemode mode
func start_game(mode):
	var scene = load("res://scenes/game/game.tscn")
	var game = scene.instance()
	root.add_child(game)
	game.start_game(mode)
	$Ambience.stop()
	visible = false


# called every frame
func _process(delta):
	# if it is a restarted game and you want a game scene instantiated next frame
	if delayed_start_game:
		start_game(mode)
		delayed_start_game = false


# called by the game scene when the game is over
# mode=-1: don't restart game, mode=0-3: restart game with gamemode mode
func on_game_ends(mode=-1):
	visible = true
	if mode != -1:
		# start the game next frame
		self.mode = mode
		delayed_start_game = true
	else:
		# don't play ambience if it's restarting a game
		$Ambience.play()

# called when a difficulty is selected, start game with gamemode

func _on_Easy_pressed():
	start_game(0)
	$Difficulty.visible = false


func _on_Medium_pressed():
	start_game(1)
	$Difficulty.visible = false


func _on_Hard_pressed():
	start_game(2)
	$Difficulty.visible = false


func _on_Nightmare_pressed():
	start_game(3)
	$Difficulty.visible = false


# called when credits button is pressed, show credits page
func _on_Credits_pressed():
	$CreditsPanel.visible = true


# exit game
func _on_Exit_pressed():
	get_tree().quit()


"""
unused method, used when you want to display a url in richtextlabel 
this method lets player's OS opens the url page when url is clicked
tried to embed link on my email with mailto:email, but OS cannot open it
"""
func _on_RichTextLabel_meta_clicked(meta):
	OS.shell_open(str(meta))
