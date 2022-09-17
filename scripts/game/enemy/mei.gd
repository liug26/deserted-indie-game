extends AnimatedSprite

"""
Mei is a special enemy. it doesn't harm the player directly, but upon
finding the player, mei is going to stay some distance away from the
player and observe it, while updating all other enemies of player's
location, enabling them to chase the player. Mei also doesn't have a
collision box, which means it flies through walls in straight lines
"""

# Constant variables
# speed when roaming
export var speed_idle = 50
# speed when chasing player
export var speed_chase = 55
# start chasing player if distance squared is smaller than this
export var chase_player_distance_squared = 15000
# mei is going to stay some distance away from the player, instead
# of trying to collide with it
export var distance_to_player = 64
# determines the upper and lower boundary of the random tick number
# during which enemy can roam to a random location before changing
# its roam location again
# tick number's actual time length subject to delta variable
export var roam_ticker_upper = 1500
export var roam_ticker_lower = 1000

# allow for easier access to nodes
onready var navigation = get_node("/root/Game/Navigation")
onready var player = get_node("/root/Game/Player")
onready var audio = get_node("/root/Game/Audio")
onready var game = get_node("/root/Game")
var rng = RandomNumberGenerator.new()
# the current speed of the enemy, equals either speed_chase or
# speed_idle, also used as an indicator of whether the enemy
# is chasing the player or not
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


func _ready():
	rng.randomize()
	game.connect("global_freeze", self, "_on_game_global_freeze")


# called every frame. 'delta' is the elapsed time since the previous frame.
# determine if enemy should chase player, and update player health if in collision
func _process(delta):
	if freeze:
		return
	# check if player is within chase range and is not in tunnel
	if position.distance_squared_to(player.position) < chase_player_distance_squared and player.position.y > 0:
		speed = speed_chase
		# flies at the direction of player but remains some distance away from player
		path = [player.position + player.position.direction_to(position) * distance_to_player]
		# update other enemies to chase player
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.player_located = true
	else:
		# player is not within chase range, idles
		speed = speed_idle
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
	# mei's path is usually just one point, due to that it flies
	# in straight lines
	# if the next path point is too close to enemy's current position
	# the point is considered arrive, remove it from path so that
	# enemy can travel to next point
	while(path.size() > 0 and position.distance_squared_to(path[0]) < 1):
		# mei doesn't come into contact with player, so its path doesn't
		# contain player's position, so last point of path is removable
		path.remove(0)  # if path point is too close, consider it arrived
	# use adjusted path to determine velocity
	if(path.size() > 0):
		# update velocity to next location in path
		velocity = position.direction_to(path[0])
	else:
		# if path size = 0, enemy has arrived at the final destination
		# of path, if enemy is roaming, change another roam destination
		if speed == speed_idle:
			_rand_roam_path()
	# move position according to velocity and delta
	position += velocity * delta * speed
	# update adjusted path in Line2D, for debugging only
	line2d.points = path


# simply picks a random path tile and add it to path
func _rand_roam_path():
	path = [navigation.tile_to_pixel(navigation.rand_path_tile())]
	roam_ticker = rng.randi_range(roam_ticker_lower, roam_ticker_upper)


# when global freeze signal is emitted from Game, stop all updates
func _on_game_global_freeze(freeze):
	self.freeze = freeze


# when enemy noise finishes playing, tell Game/Audio to play another noise
func _on_Noise_finished():
	audio.on_enemy_noise_finished()
