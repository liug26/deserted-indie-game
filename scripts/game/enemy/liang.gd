extends Area2D

"""
Liang is another enemy that cannot directly harm the player, liang
can only steal money from player, every time about 10% of coin
maximum. liang is very fast, and will try to flee from player after
stealing to a random location, if on its flee player collides with
liang once more, player can get its money back. liang is very fast
but has a small chasing range
"""

# Constant variables
# speed when roaming
export var speed_idle = 80
# speed when chasing player
export var speed_chase = 85
# start chasing player if distance squared is smaller than this
export var chase_player_distance_squared = 10000
# determines the upper and lower boundary of the random tick number
# during which enemy can roam to a random location before changing
# its roam location again
# tick number's actual time length subject to delta variable
export var roam_ticker_upper = 1500
export var roam_ticker_lower = 1000


# allow for easier access to nodes
onready var navigation = get_node("/root/Game/Navigation")
onready var player = get_node("/root/Game/Player")
onready var level_gen = get_node("/root/Game/LevelGen")
onready var audio = get_node("/root/Game/Audio")
onready var game = get_node("/root/Game")
var rng = RandomNumberGenerator.new()
# the current speed of the enemy, equals either speed_chase or
# speed_idle, unlike all other enemies, liang does not use speed
# as an indicator of chasing or idling status
var speed = 0
# a list of pixel positions that assemble into a path that the
# enemy is moving towards, could be a random roam location or the
# player's location
var path = []
# a number in range from roam_ticker_upper to roam_ticker_lower,
# substracts 1 every update tick, and if equals 0 update a random
# roam path
var roam_ticker = 0 
# if set to true, will stop all updates
var freeze = false
# updates every frame, if player is located by Mei, will set to
# true, enemy will chase to player's location regardless of distance
var player_located = false
# the Line2D assigned to enemy when scene is instantiated, displays
# path for debugging
var line2d
"""
liang has three modes, idling, chasing, or fleeing. when liang satisfies
both flee and chase reqruirements, flee is going to override chase,
because flee and chase cannot both be true. but they can both be false,
which indicates liang is idling
"""
var flee = false
var chase = false
# the amount of coins stolen, also the amount that will be returned
# to player if player collides with liang when fleeing
var stolen_coins = 0
# when > 0, liang's stolen coins cannot be returned to player,
# this is to prevent liang's stealing and returning from happening
# during the same collision
var invulnerable_seconds = 0


func _ready():
	rng.randomize()
	game.connect("global_freeze", self, "_on_game_global_freeze")


# called every frame. 'delta' is the elapsed time since the previous frame.
# determine if liang should chase player, idle or flee
func _process(delta):
	# unlike all other _process() methods, liang has a section
	# that keeps updating while in freeze, this is the section that
	# controls returning stolen coins to player. if this section is 
	# is freeze-able, when player freezes enemies by picking up the
	# ice prop, player will not be able to retrieve its coins
	# in this case, it is fine to have this section to stay out of freeze
	# because it is only checking for updates, not actively updating
	# update invulnerable seconds
	invulnerable_seconds = max(0, invulnerable_seconds - delta)
	# check for collision with player
	for body in get_overlapping_bodies():
		if body.name == "Player":
			if flee:
				# if liang is on flee and its invulnerablilty is over
				if invulnerable_seconds == 0:
					# return stolen coins to player
					player.update_coin(stolen_coins)
					stolen_coins = 0
			elif not freeze:
				# if liang is not on flee, then liang is stealing coins from player
				# steal about 5% to 10% of maximum coin from player
				stolen_coins = int(rng.randf_range(0.05, 0.1) * level_gen.coin_maximum)
				# if player doesn't have that many coins, steal all player's coins
				if stolen_coins > player.coins:
					stolen_coins = player.coins
				player.update_coin(-stolen_coins)
				# after stealing, flee mode is true, also turn off
				# chase mode because both cannot be true at the same itme
				flee = true
				chase = false
				# flee to a random path with chasing speed
				_rand_roam_path()
				speed = speed_chase
				# activate invulerability to be 0.25 seconds
				invulnerable_seconds = 0.25
	# freeze update if freezed
	# if liang is on flee mode, it is not going to worry about anything
	# until it reaches flee location
	if freeze or flee:
		return
	# determine if liang is on chase mode
	if (player_located or position.distance_squared_to(player.position) < chase_player_distance_squared) and player.position.y > 0:
		# chase mode is on when player is within chase range or located
		# by mei, and is not in tunnel
		chase = true
		speed = speed_chase
		path = navigation.a_star_path(position, player.position)
		# reset player_located every frame
		player_located = false
		# this line makes sure if enemy losse track of player,
		# immediately changes path to a roam location, instead of
		# still arriving to player's last seen position
		roam_ticker = 0
	else:
		# if not in chase mode or flee mode, liang idles
		speed = speed_idle
		chase = false
		if roam_ticker == 0:
			_rand_roam_path()
		else:
			roam_ticker -= 1


# move enemy towards the next location in path
func _physics_process(delta):
	if freeze:
		return
	# velocity by default is a zero vector
	var velocity = Vector2.ZERO
	# if the next path point is too close to enemy's current position
	# the point is considered arrive, remove it from path so that
	# enemy can travel to next point
	while(path.size() > 0 and position.distance_squared_to(path[0]) < 1):
		# if it is the last point of path and enemy is chasing player
		# the last point is the player's location, don't remove this point
		# because you want the enemy to get locked on the player
		if path.size() == 1 and chase:
			break
		path.remove(0)  # if path point is too close, consider it arrived
	# use adjusted path to determine velocity
	if(path.size() > 0):
		# update velocity to next location in path
		velocity = position.direction_to(path[0])
	else:
		# if path size = 0, enemy has arrived at the final destination
		# if flee mode is on, then liang has finished fleeing, set
		# flee to false, if liang is idling, select a new random path
		flee = false
		_rand_roam_path()
	# move position according to velocity and delta
	position += velocity * delta * speed
	# update adjusted path in Line2D, for debugging only
	line2d.points = path


# returns the A* path from current position to a random path tile
# on the map
func _rand_roam_path():
	path = navigation.a_star_path(position, navigation.tile_to_pixel(navigation.rand_path_tile()))
	roam_ticker = rng.randi_range(roam_ticker_lower, roam_ticker_upper)


# when global freeze signal is emitted from Game, stop all updates
func _on_game_global_freeze(freeze):
	self.freeze = freeze


# when enemy noise finishes playing, tell Game/Audio to play another noise
func _on_Noise_finished():
	audio.on_enemy_noise_finished()
