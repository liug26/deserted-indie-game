extends KinematicBody2D

"""
Player node, controls player movement and player-related variables

Node structure:
	Light2D: a high-energy, low texture-scale light source that lights
		up close-by areas, acts like a flashlight
	LightMask, a low-energy, high texture-scale light source that dimly
		lights up most part of camera's view, acs like a light mask
	Camera2D: the camera following the player and capturing a small
		section around the player, as opposed to God view camera, current
		default set to true
	Camera2D/Area2D: an Area2D that follows the camera but its dimension
		is slightly smaller than the camera to update bodies and areas
		that enters camera vision
	InvulnerableTimer: a 1-second wait time timer, used to update player's
		invulnerable frame
"""

# nodes for easier access
onready var game = get_node("/root/Game")
onready var ui = get_node("/root/Game/UI")
onready var level_gen = get_node("/root/Game/LevelGen")
onready var audio = get_node("/root/Game/Audio")
# player's health, range from 0 to 100, dies upon 0 health
var health = 100
# player's coin count, range from 0 to coin_maximum
var coins = 0
# player's speed, used to scale player's velocity
var speed = 100
# player's velocity, a normalized vector or a zero vector if player
# is not moving
var velocity = Vector2()
# if player is invulnerable/undamagable
var invulnerable = false
# player's resurrection status, if 0: doesn't have resurrection
# if 1: has resurretion, if 2: has used resurrection
var resurrection = 0
# player's game pass status, if 0: doesn't have game pass
# if 1: has game pass
var game_pass = 0
# if set to true, will prevent all movements and updates and stops
# the invulnerable timer
var freeze = false
# for debugging only, if set to true, player cannot die but can be hurt
var immortal = false


# detects player's key events, wasd for movement, sets velocity
func _input(ev):
	velocity = Vector2.ZERO
	if Input.is_key_pressed(KEY_D):
		velocity.x += 1
	if Input.is_key_pressed(KEY_A):
		velocity.x -= 1
	if Input.is_key_pressed(KEY_S):
		velocity.y += 1
	if Input.is_key_pressed(KEY_W):
		velocity.y -= 1
	velocity = velocity.normalized() * speed


# checks for nearby enemies and updates light and heartbeat
func _process(delta):
	if freeze:
		return
	if position.y > 0:
		# find the squared distance of the nearest chi
		var min_distance = 60000
		for chi in get_tree().get_nodes_in_group("chi"):
			if position.distance_squared_to(chi.position) < min_distance:
				min_distance = position.distance_squared_to(chi.position)
		# this linear function has scale = 1 (max light) at distance_squared = 55,000
		# and scale = 0 (no light) at distance_squared = 40,000
		var scale = min(1, max(0, 0.0000666667 * min_distance - 2.66667))
		$Light2D.energy = scale
		# finding the nearest, visible enemy's squared distance
		min_distance = 80000
		for enemy in get_tree().get_nodes_in_group("enemy"):
			# wang's alpha value has to be more than 0.2 to count as visible
			if position.distance_squared_to(enemy.position) < min_distance and enemy.modulate.a > 0.2:
				min_distance = position.distance_squared_to(enemy.position)
		# this linear function has speed = 1 (max) at distance_squared = 5000
		# and speed = 0 (min) at distance_squared = 80,000
		var heartbeat = min(1, max(0, -1 / 75000.0 * min_distance + 16 / 15.0))
		audio.set_heartbeat_speed(heartbeat)


# moves player by velocity
func _physics_process(delta):
	if freeze:
		return
	velocity = move_and_slide(velocity)


# updates player's health by amount
func update_health(amount):
	# determines if it's damage or heal
	if amount < 0:
		# update damage to player if not invulnerable
		if not invulnerable:
			# update health in player and on UI
			health = max(0, health + amount)
			ui.update_health(health)
			# turn on UI's damage mask
			ui.get_node("DamageMask").modulate.a = 1.0
			# play hurt audio
			audio.on_damaged()
			# give self a 1-second invulnerable frame
			invulnerable = true
			$InvulnerableTimer.start()
		# check if player is dead
		if health == 0:
			# if has resurrection
			if resurrection == 1:
				# resurrect and has 20 health, re-update health UI
				health = 20
				ui.update_health(health)
				# set resurrection to be used
				resurrection = 2
				# update vital item changes to Game (although this
				# for now does not result in any change)
				game.on_vital_items_acquired()
				# update vital items' status in UI
				ui.update_status_ui()
				# play resurrecting animation
				ui.get_node("Resurrection").visible = true
				ui.get_node("Resurrection").play()
				# play resurrecting audio
				audio.get_node("ResurrectionUsed").play()
			else:
				# don't have resurrection, die
				if immortal:  # unless you are immortal
					health = 1
				else:
					game.on_game_over(false)
	else:
		# if it's a heal, update health and UI
		health = min(health + amount, 100)
		ui.update_health(health)


# update player's coins by amount, cannot exceed coin maximum
func update_coin(amount):
	coins = min(coins + amount, level_gen.coin_maximum)
	ui.update_coin(coins)


# when invulnerable timer timeout, player loses invulnerable frame
func _on_InvulnerableTimer_timeout():
	invulnerable = false


# add a buff to a player by instantiating a buff scene
# argument type is an integer corresponding to the type of buff
func add_buff(type):
	var buff = level_gen.instance_scene("buff")
	add_child(buff)
	buff.initialize(type)


# when global freeze signal is emitted from Game, turns on freeze
# and stops invulnerable timer
func _on_game_global_freeze(freeze):
	self.freeze = freeze
	if freeze:
		$InvulnerableTimer.stop()
	else:
		$InvulnerableTimer.start()


# when an Area2D enters camera's vision, update it to audio
# and play the enemy appear audio
func _on_camera_area_entered(area):
	# invisible enemies (wangs having an alpha lower than 0.2)
	# and liangs & meis do not trigger the enemy appear audio
	# note that mei does not have a collision box so it even won't
	# be detected by the Area2D
	if area.is_in_group("enemy") and not area.is_in_group("liang") and area.modulate.a > 0.2:
		audio.on_enemy_appear(area.position)
