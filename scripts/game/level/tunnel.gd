extends Area2D

"""
Tunnel node, visualizes and controls the tunnel that opens upon
acquiring game pass. default visibility set to false, as its
visibility is used by LevelGen as an indicator if tunnel is put
into position or not.

Node structure:
	Area2D: an Area2D covering the entire tunnel and a small area
		in front of tunnel gate, updates tunnel-entering events
	Background: dark background covering the upper section (outer
		border of the map and above) of the tunnel
	AirWall: a StaticBody2D preventing the player to go too far out
		of the tunnel
	ShadeLow: a black ColorRect that will cover the map area shortly
		after player enters the tunnel. default set to be transparent
	ShadeTunnel: a black ColorRect that covers the tunnel area when
		the player is in map area, will be set to be transparent shortly
		after entering the tunnel
	ShadeHigh: a black ColorRect that will gradually darken as the player
		advances in the tunnel, covers the tunnel borders making the
		player unable to see the outer borders of the map. default set
		to be transparent.
	EndGate: an Area2D with a sprite and a colllision box, ends the game
		when player collides with it
	EndGate/Audio: an AudioStreamPlayer2D, auto-starts and plays an
		ambience music around the end gate
"""

# for easier access to nodes
onready var god_view = get_node("/root/Game/LevelGen/GodView")
onready var audio = get_node("/root/Game/Audio")
onready var player = get_node("/root/Game/Player")
onready var game = get_node("/root/Game")

# if player enters the tunnel for the first time
var first_time_in_tunnel = true


# called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for body in get_overlapping_bodies():
		# process player's location while player is inside detection area
		if body.name == "Player":
			var y = body.position.y
			# for debugging only, allows GodView camera to capture the tunnel
			if y > -10:
				god_view.position.y = 0
			elif y > -600 * god_view.zoom.y:
				god_view.position.y = -600 * god_view.zoom.y
			else:
				god_view.position.y = -1200 * god_view.zoom.y
			# adjust ShadeLow and ShadeTunnel, both will gradually turn on
			# and off when player is 0-1 tile in the tunnel
			if y > -32 and y < 0:
				$ShadeLow.color.a = -y / 32 * 1.0
				$ShadeTunnel.color.a = 1.0 - $ShadeLow.color.a
			# adjust ShadeHigh, when player is 2-4 tiles inside the tunnel
			if y > -128 and y < -64:
				$ShadeHigh.color.a = (-y - 64) / (128 - 64) * 1.0
			# quiets global volume when player is 0-2 tiles inside the tunnel
			# note that if player has resurrection and game pass, volume is already
			# silenced, so don't override that
			if y > -64 and y < 0 and not (player.resurrection == 1 and player.game_pass == 1):
				var vol = 1 + y / 64.0
				audio.set_all_volume(vol)
			# if player is first time in tunnel, plays an intriguing sound
			if first_time_in_tunnel:
				audio.get_node("TunnelEntered").play()
				first_time_in_tunnel = false


# when player enters the end gate, end the game
func _on_EndGate_body_entered(body):
	game.on_game_over(true)
