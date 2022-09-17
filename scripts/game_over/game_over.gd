extends Node2D

"""
Game over scene, instantiated by Game when game is over, displays
an animation telling the player game is over, and main menu with
try again button
"""

# for easier access to nodes
onready var game = get_node("/root/Game")
# is the number of seconds after which the scene will stop updating animation
var seconds_stop = 7  # not very useful though
# is the current tick measured in seconds, used to guide animation
# on transition timing and which animation to play
var seconds_tick = 0
# a number ranging from -1 to 3, denotes which ending to display
# assigned during initialization, if = -1: lost game with used
# resurretion, if = 0: lost game with no resurrection, if = 1:
# won game without unused resurrection, if = 2: won game with
# unused resurrection
var ending


# initialize ending and moves UI components to place
func initialize(ending):
	self.ending = ending
	# these will start out transparent and gradually fades in
	$GameOverLabel.modulate.a = 0
	$TryAgain.modulate.a = 0
	$MainMenu.modulate.a = 0
	# the sound effect to play, will be played immediately after initialization
	var sfx
	if ending == 0 or ending == -1:
		# for both endings, display the following text, and show
		# both try again and main menu buttons
		$Label.text = "You didn't succeed"
		$TryAgain.margin_left = 404
		$TryAgain.margin_top = 402
		$TryAgain.margin_right = 617
		$TryAgain.margin_bottom = 454
		$MainMenu.margin_left = 404
		$MainMenu.margin_top = 478
		$MainMenu.margin_right = 617
		$MainMenu.margin_bottom = 530
		# note that these two audios are wav, so no set_loop(false)
		# because they don't have this method and they are by default
		# not loops
		if ending == -1:
			# for ending (-1), play the fish head audio signifying
			# enemies' laughter to player
			sfx = load("res://assets/audio/ending/fish_head.wav")
			# adjust volume because fish head is pretty loud
			$Audio.volume_db = -10
		else:
			# for ending (0), play a normal strange-feeling sound
			sfx = load("res://assets/audio/ending/0.wav")
	elif ending == 1:
		# ending (1), display the following text and only the
		# main menu button
		$Label.text = "You escaped"
		$MainMenu.margin_left = 411
		$MainMenu.margin_top = 439
		$MainMenu.margin_right = 624
		$MainMenu.margin_bottom = 491
		# play a cheerful sound, note that the sound is in mp3
		sfx = load("res://assets/audio/ending/1.mp3")
		sfx.set_loop(false)
	elif ending == 2:
		# ending (2), displays the following text and only the
		# mani menu button
		$Label.text = "Spirits are fared away"
		$MainMenu.margin_left = 411
		$MainMenu.margin_top = 439
		$MainMenu.margin_right = 624
		$MainMenu.margin_bottom = 491
		# play a slightly more cheerful sound, note that the sound is in mp3
		sfx = load("res://assets/audio/ending/2.mp3")
		sfx.set_loop(false)
	# play audio immediately
	$Audio.stream = sfx
	$Audio.play()


# does the transitioning animation
func _process(delta):
	# if the tick exceeds stop, stop updating anything (not useful line)
	if seconds_tick > seconds_stop:
		return
	
	"""
	there isn't much difference between losing and winning endings,
	the only difference being that winning ending animation starts
	1 second later than losing one. this is to let the player see
	that the end gate is what causes a game over
	"""
	if ending == 0 or ending == -1:
		# background alpha increment, causes gradual darkening
		if seconds_tick < 2:
			# alpha value maximizes at 0.9
			$Background.color.a += 0.9 / 2 * delta
		# game over title alpha increment, causes fading in effect
		if seconds_tick < 3 and seconds_tick > 1:
			# maximizes at alpha = 1.0
			$GameOverLabel.modulate.a += 1.0 / 2 * delta
		# gradual increasing of Label's percent visible property
		# causes words to gradually appear from left to right
		if seconds_tick < 4.2 and seconds_tick > 3:
			# extra seconds to make sure percent visible maxs out at 1.0
			$Label.percent_visible += 1.0 / 1 * delta
		# gradual fading in of buttons
		if seconds_tick < 6 and seconds_tick > 5:
			# alpha maximizes at 1.0
			$MainMenu.modulate.a += 1.0 / 1 * delta
			$TryAgain.modulate.a += 1.0 / 1 * delta
	else:
		# background alpha increment, causes gradual darkening
		if seconds_tick < 3 and seconds_tick > 0.5:
			# alpha value maximizes at 0.9
			$Background.color.a += 0.9 / 2.5 * delta
		# game over title alpha increment, causes fading in effect
		if seconds_tick < 4 and seconds_tick > 2:
			# maximizes at alpha = 1.0
			$GameOverLabel.modulate.a += 1.0 / 2 * delta
		# gradual increasing of Label's percent visible property
		# causes words to gradually appear from left to right
		if seconds_tick < 5.2 and seconds_tick > 4:
			# extra seconds to make sure percent visible maxs out at 1.0
			$Label.percent_visible += 1.0 / 1 * delta
		# gradual fading in of buttons
		if seconds_tick < 7 and seconds_tick > 6:
			# alpha maximizes at 1.0
			$MainMenu.modulate.a += 1.0 / 1 * delta
	# update tick
	seconds_tick += delta


# when try again is pressed, tells game to restart game, frees self
func _on_TryAgain_pressed():
	game.on_restart_game()
	queue_free()


# when mani menu is pressed, tells game to go to main menu, frees self
func _on_MainMenu_pressed():
	game.on_main_menu()
	queue_free()
