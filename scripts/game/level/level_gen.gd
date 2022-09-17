extends Node2D

"""
LevelGen node, takes care of map generation (using a method from
https://shaunlebron.github.io/pacman-mazegen/, first generate a
vertex map, then convert it to tile map, and display it using
TileMap), enemy generation, prop generation, and difficulty
adjustment

Node structure:
	Background: the black background of the map
	TileMap: displays natural looking walls and borders that have
		a collision and an occulusion layer. Notice that the tiles
		are in collision layer (1) and occulusion layer (1). each
		tile is 32x32 pixels. 
	GodView: for debugging only, a camera that overlooks the entire map
	PropTimer: a timer that timeout every 30 seconds and generate 
		some amount of props
"""


# for easier access to other nodes
onready var navigation = get_node("/root/Game/Navigation")
onready var player = get_node("/root/Game/Player")
onready var instances = get_node("/root/Game/Instances")
onready var tunnel = get_node("/root/Game/Tunnel")
"""
detected in _get_breakable_connections(), if set to true, the outmost
vertices in vertex_map will always be connected to other outmost vertices
along the border. this will cause the outmost tiles of tile map to be always
0 (path). this is to mimic the map in Pac-man, but eventually I decide that
having this border path is not important considering how big the map is
"""
var preserve_border_path = false
"""
block map width and height refers to how many "blocks" vertex map has. a block
consists of 4 vertices, which translate to a 3x3 block on tile map, where the
the 4 edges created translate to the outmost tiles in the 3x3 block, that also
means the middle tile always remains a wall (though you can suppress this 1x1
wall in other parameters). also note that the outmost edges of the 3x3 block
are shared with neighbor blocks.
here are some key formulas
vertex_map_width/height = block_map_width/height + 1 = (25, 16)
tile_map_width/height = 2 * block_map_width/height + 1 = (49, 31)
tile_map_width/height (in pixels) = (2 * block_map_width/height + 1) * 32 = (1568, 992)
default is (24, 15), remains unchanged across difficulties
"""
var block_map_width = 24
var block_map_height = 15
var vertex_map_width = block_map_width + 1
var vertex_map_height = block_map_height + 1
var tile_map_width = 2 * block_map_width + 1
var tile_map_height = 2 * block_map_height + 1
# thickness of the border surrounding the map, measured in tiles
var border_thickness = 8
# refering to that each tile is 32x32 pixels by size
var tile_to_pixel_ratio = 32

# Difficulty-Influenced Parameters, will be set in set_difficulty()
"""
parameter used in _create_vertex_map(), is the probability that
a vertex will try to break a connection with a neighboring vertex
if the vertex is broken, then it is also this probability that the
vertex will try to break another conenction. a total of 2 connections
can be broken. 
the higher the number is, the less block edges, the less path there are
the more walls there will be. the less the number, the more path there will be
"""
var break_connection_prob
# after tile map is generated, is the probability that 1-tile walls will
# be removed (resulted from a block with none of its edges removed)
# the higher the number is, the more open space there will be
var suppress_one_tile_wall_prob
# the maximum number of coins player can hold, also the price of game pass
var coin_maximum 
# an array of size 3 that contains the probability that a coin/vision buff/ice
# should spawn at a given tile
var prop_prob
# the maximum number of props that map can generate, equals to
# the number of path tiles in the map
var max_prop
# the percentage of max_prop of which PropTimer will spawn props
# corresponds to the percentage of props spawn every 30 seconds
var prop_percentage_spawn
# current difficulty, 0: easy, 1: medium, 2: hard, 3: nightmare
var mode

# Generated Variables, contain key information of the map
# an array of strings that contain the names of the enemies
# spawned in the map
var enemy_names
# a 2D array of dimension (tile_map_height, tile_map_width)
# if element = 0: there isn't a prop spawned at corresponding tile
# if = 1: there is a prop spawned at corresponding tile
# used to determine if props can spawn at some tile
var props
# a 2D array of dimension (tile_map_height, tile_map_width)
# if element = 0: there is a wall at the tile
# if element = 1: the tile is a path
var tile_map

# for debugging, controls the visibility of the Line2D assigned to
# each enemy, displays their intended path
var display_enemy_path = false
# rng
var rng = RandomNumberGenerator.new()

# used to locate neighbors of vertices and tiles
enum {UP, RIGHT, DOWN, LEFT}


# called when the node enters the scene tree for the first time.
func _ready():
	rng.randomize()


# called by Game when initializing game, set up the difficulty-dependent parameters
func set_difficulty(mode):
	# records difficulty
	self.mode = mode
	if mode == 0:
		coin_maximum = 200
		break_connection_prob = 0.4
		suppress_one_tile_wall_prob = 0.8
		prop_prob = [0.45, 0.005, 0.002]
		prop_percentage_spawn = 0.04
		enemy_names = _enemy_combo([2.0/3, 0, 1.0/3, 0, 0], 3)
	elif mode == 1:
		coin_maximum = 300
		break_connection_prob = 0.5
		suppress_one_tile_wall_prob = 0.7
		prop_prob = [0.45, 0.004, 0.002]
		prop_percentage_spawn = 0.04
		enemy_names = _enemy_combo([0.4, 0.15, 0.3, 0.1, 0.05], 4)
	elif mode == 2:
		coin_maximum = 300
		break_connection_prob = 0.55
		suppress_one_tile_wall_prob = 0.3
		prop_prob = [0.4, 0.004, 0.002]
		prop_percentage_spawn = 0.03
		enemy_names = _enemy_combo([0.3, 0.2, 0.3, 0.2, 0.1], 5)
	elif mode == 3:
		coin_maximum = 400
		break_connection_prob = 0.6
		suppress_one_tile_wall_prob = 0.1
		prop_prob = [0.4, 0.004, 0.002]
		prop_percentage_spawn = 0.03
		# nightmare level ensures that every enemy is involved plus an additional enemy
		# the seemingly unneccessary array box around _enemy_combo is because
		# _enemy_combo doesn't allow a combo with too many meis or liangs, which
		# in this case, doesn't allow any of them. so I generate a combo of size 3
		# to dodge this mechanism and picks the first enemy in the array
		enemy_names = ["gui", "chi", "mei", "wang", "liang"] + [_enemy_combo([0.3, 0.2, 0.3, 0.2, 0.1], 3)[0]]


# given an array prob with probabilities of generating each enemy
# and a number num of how many enemies you want to generate
# return an array of size num with random enemy names generated
func _enemy_combo(prob, num):
	var enemies = []
	while enemies.size() < num:
		# like prop generation, this is not the most efficient way
		# to do this, but it is fine for now
		var rand = rng.randf()
		if rand < prob[0]:
			enemies.append("gui")
		elif rand < prob[0] + prob[1]:
			enemies.append("chi")
		elif rand < prob[0] + prob[1] + prob[2]:
			enemies.append("mei")
		elif rand < prob[0] + prob[1] + prob[2] + prob[3]:
			enemies.append("wang")
		elif rand < prob[0] + prob[1] + prob[2] + prob[3] + prob[4]:
			enemies.append("liang")
	# this part makes sure that the number of meis and liangs stays
	# roughly within half of enemy count
	# too many meis and liangs won't pose a significant threat
	# to player because they cannot directly harm the player
	# this method isn't the best way to make sure this, because
	# 2 meis and 3 liangs can still spawn in a 5-member enemy crew
	# but the probability is low, so in general this method is fine
	if enemies.count("mei") > floor(num / 2) or enemies.count("liang") > floor((num + 1) / 2):
		# if the current combination contains too many meis or liangs
		# make a new combination that satisfies
		return _enemy_combo(prob, num)
	return enemies


# the method immediately following set_difficulty() during Game.start_game()
# generate vertex map and tile map, instantiate TileMap, enemy and prop instances
func initialize_level():
	# Map Generation
	# create vertex and tile map randomly, according to difficulty parameters
	var vertex_map = _create_vertex_map()
	_vertex_to_tile_map(vertex_map)
	# instantiates tiles in TileMap according to tile_map
	_visualize_tile_map()
	# set up god view camera's zoom to capture the entire map
	$GodView.zoom = Vector2(tile_map_width* tile_to_pixel_ratio / 1024.0, tile_map_height * tile_to_pixel_ratio / 600.0)
	
	# Enemy Generation
	# randomly placing player on a path tile
	var player_tile = navigation.rand_path_tile()
	player.position = navigation.tile_to_pixel(player_tile)
	# generate enemies and put them in Game/Instances
	for enemy_name in enemy_names:
		var enemy = instance_scene("enemy/" + enemy_name)
		instances.add_child(enemy)
		# randomly place enemy, but 10 tiles away from player's location
		var rand_tile = navigation.rand_path_tile_away_from(player_tile, 10)
		enemy.position = navigation.tile_to_pixel(rand_tile)
		# assign a Line2D to each enemy to display their path, for debugging
		var line2d = Line2D.new()
		line2d.visible = display_enemy_path
		instances.add_child(line2d)
		enemy.line2d = line2d
	
	# Prop Generation
	# initialize variables
	props = []
	max_prop = 0
	for y in range(tile_map.size()):
		var prop_row = []
		for x in range(tile_map[0].size()):
			# if the tile is a wall, then skip this tile
			if tile_map[y][x] != 1:
				prop_row.append(0)  # no prop is generated at this tile
				continue 
			# counts the number of path tiles = maximum number of possible
			# prop generation locations
			max_prop += 1
			# if the tile is player's location, skip it because we don't want
			# the player to get 1 coin/vision buff/ice without doing anything
			if [x, y] == player_tile:
				prop_row.append(0)
				continue
			# randomly select a prop to be generated based on difficulty parameters
			# this is not the most efficient way to do this, but considering there
			# are only 3 props now, it is okay
			var prop_name = ""
			var rand = rng.randf()
			if rand < prop_prob[0]:
				prop_name = "coin"
			elif rand < prop_prob[0] + prop_prob[1]:
				prop_name = "vision_buff"
			elif rand < prop_prob[0] + prop_prob[1] + prop_prob[2]:
				prop_name = "ice"
			# only generate a prop if probability falls in a prop
			if prop_name != "":
				var prop = instance_scene("props/" + prop_name)
				# tells prop its tile location so it can update the prop variable
				# when it's freed
				prop.initialize(x, y)
				instances.add_child(prop)
				prop.position = navigation.tile_to_pixel([x, y])
				prop_row.append(1)
			else:
				prop_row.append(0)
		props.append(prop_row)


# visualizes tile map on TileMap by creating autotiles
func _visualize_tile_map():
	var border_id = $TileMap.tile_set.find_tile_by_name("border")
	var wall_id = $TileMap.tile_set.find_tile_by_name("wall")
	# convert each tile in tile_map to autotiles in TileMap
	for y in range(tile_map_height):
		for x in range(tile_map_width):
			# if tile is not path
			if tile_map[y][x] == 0:
				# if tile is connected to border, make it a border tile
				if _search_global_border([x, y], []):
					$TileMap.set_cell(x, y, border_id)
				else:
					$TileMap.set_cell(x, y, wall_id)
	# create vertical border tiles
	for y in range(-border_thickness, 0) + range(tile_map_height, tile_map_height + border_thickness):
		for x in range(-border_thickness, tile_map_width + border_thickness):
			$TileMap.set_cell(x, y, border_id)
	# create horizontal border tiles
	for x in range(-border_thickness, 0) + range(tile_map_width, tile_map_width + border_thickness):
		for y in range(-border_thickness, tile_map_height + border_thickness):
			$TileMap.set_cell(x, y, border_id)
	# update autotiling
	$TileMap.update_bitmask_region(Vector2(-border_thickness, -border_thickness), Vector2(tile_map_width + border_thickness, tile_map_height + border_thickness))
	# move background to cover the map and its border
	# so that when tunnel opens background wouldn't be blank
	$Background.margin_top = -border_thickness * tile_to_pixel_ratio
	$Background.margin_left = -border_thickness * tile_to_pixel_ratio
	$Background.margin_right = (tile_map_width + border_thickness) * tile_to_pixel_ratio
	$Background.margin_bottom = (tile_map_height + border_thickness) * tile_to_pixel_ratio


# recursive function, returns if a wall is connected to the border or not
# arguments: xy, the indices of the wall in tile_map that you want
# to determine if it is connected to border. visited_xy, an array of indices
# of walls that you have analyzed and are not connected to border
func _search_global_border(xy, visited_xy):
	# if the wall is along the border, then it is connected to border
	if xy[0] == 0 or xy[1] == 0 or xy[0] == tile_map_width - 1 or xy[1] == tile_map_height - 1:
		return true
	# check neighboring tiles of the wall, see if they are connected
	for direction in range(4):
		# get a neighbor tile and its indices
		var facing_tile = get_facing(tile_map, xy[0], xy[1], direction)
		var facing_xy = get_facing_xy(xy[0], xy[1], direction)
		# if neighbor tile is not out of bounds and is a wall
		if facing_tile != null and facing_tile == 0:
			# if you have not analyzed this wall before
			if not visited_xy.has(facing_xy):
				# record that you have analyzed this wall
				visited_xy.append(facing_xy)
				# if this wall neighbor is connected to border, then you
				# are connected to border as well
				if _search_global_border(facing_xy, visited_xy):
					return true
	# you have searched through all your connected wall neighbors, and
	# none are connected to border, return false
	return false


# called by Game's on_vital_items_acquired(), when either game pass or
# resurrection is bought. acquiring game pass and resurrection could
# result in tunnel opening or instance clearing
func update_map():
	# if player has resurrection but not game pass then nothing is changed
	if player.game_pass == 1:
		# if player has game pass, open tunnel
		# note that this method could be called 1-2 times again, when
		# resurrection is acquired/used, so if tunnel is already generated
		# then skip it
		if tunnel.visible == false:  # used as an indicator if tunnel is already open or not
			# locate the middle point on the y=0 border
			var tunnel_x = floor(tile_map_width / 2)
			# remove border tiles and any walls in the 2x2
			# area in front of the tunnel
			for y in range(-border_thickness, 2):
				$TileMap.set_cell(tunnel_x, y, -1)
				$TileMap.set_cell(tunnel_x + 1, y, -1)
				if y >= 0:
					# also update the removed 2x2 area in tile map
					tile_map[y][tunnel_x] = 1
					tile_map[y][tunnel_x + 1] = 1
			# update autotiling
			$TileMap.update_bitmask_region(Vector2(-border_thickness, -border_thickness), Vector2(tile_map_width + border_thickness, tile_map_height + border_thickness))
			# show tunnel node and move to position
			tunnel.visible = true
			tunnel.get_node("Area2D").position.x = (tunnel_x + 1) * tile_to_pixel_ratio
		# when player has resurrection and game pass
		# do instance clearing
		if player.resurrection == 1:
			for child in instances.get_children():
				child.queue_free()
		# stops PropTimer from generating new props
		$PropTimer.stop()


# generates new props every 30 seconds
func _on_PropTimer_timeout():
	# the amount of props that there are now
	var prop_count = 0
	# a 2D array of dimension (n, 2), contains the [x, y] indices
	# of tiles where you can generate props on
	var available_tiles = []
	# determining these two variables
	for y in range(props.size()):
		for x in range(props[y].size()):
			var prop = props[y][x]
			if props[y][x] == 1:
				prop_count += 1
			elif tile_map[y][x] == 1:
				available_tiles.append([x, y])
	# basically sum of all elements of prop_prob, which may not be 1
	var total_prop_prob = 0
	for prob in prop_prob:
		total_prop_prob += prob
	# the number of new props that will be generated
	var num_new_props = min(max_prop * prop_percentage_spawn, max_prop - prop_count)
	# generate new props
	for _i in range(num_new_props):
		# pick a random tile from available tiles
		var rand_index = rng.randi_range(0, available_tiles.size() - 1)
		var rand_tile = available_tiles[rand_index]
		# the prop that will be generated, note that total_prop_prob
		# comes in to make sure that prop_name is not blank
		var prop_name = ""
		var rand = rng.randf()
		if rand < prop_prob[0] / total_prop_prob:
			prop_name = "coin"
		elif rand < (prop_prob[0] + prop_prob[1]) / total_prop_prob:
			prop_name = "vision_buff"
		else: 
			prop_name = "ice"
		# instantiate prop
		var prop = instance_scene("props/" + prop_name)
		prop.initialize(rand_tile[0], rand_tile[1])
		instances.add_child(prop)
		prop.position = navigation.tile_to_pixel(rand_tile)
		props[rand_tile[1]][rand_tile[0]] = 1
		# remove new prop's tile from available ones
		available_tiles.remove(rand_index)


# responds to Game's global freeze signal, stops PropTimer from generating props
func _on_game_global_freeze(freeze):
	if freeze:
		$PropTimer.stop()
	else:
		$PropTimer.start()


# Some useful functions used by other nodes as well

# return an instance of a scene with scene_path
func instance_scene(scene_path):
	var scene = load("res://scenes/game/" + scene_path + ".tscn")
	return scene.instance()


# given x and y and the direction facing, returns an array that contains
# the x and y indices of the neighbor you are facing
# unstable: can return an invalid x, y that are out of bounds
# to get a neighbor that checks bounds, use get_facing()
func get_facing_xy(x, y, direction):
	var facing_x = x
	var facing_y = y
	if direction == UP:
		facing_y -= 1
	if direction == DOWN:
		facing_y += 1
	if direction == LEFT:
		facing_x -= 1
	if direction == RIGHT:
		facing_x += 1
	return [facing_x, facing_y]


# given a 2D array map, the x and y indices of the current position
# and the direction facing, returns the neighbor that you are facing
# if neighbor is out of bounds, null is returned
func get_facing(map, x, y, direction):
	var facing_xy = get_facing_xy(x, y, direction)
	var facing_x = facing_xy[0]
	var facing_y = facing_xy[1]
	# check for out of bounds indices
	if facing_x >= 0 and facing_y >= 0 and facing_x < map[0].size() and facing_y < map.size():
		return map[facing_y][facing_x]
	else:
		return null


# Tile map generation

# given vertex_map, a 2D array, convert it to tile map
# suppress 1-tile walls as prompted, set tile_map variable
func _vertex_to_tile_map(vertex_map):
	# initialize tile map, default values are 0 (wall)
	tile_map = []
	for _y in range(tile_map_height):
		var tile_row = []
		for _x in range(tile_map_width):
			tile_row.append(0)
		tile_map.append(tile_row)
	# iterating through vertex map to translate it to tile map
	# the big idea is to first translate all vertices' right and
	# bottom connection, and lastly translate the entire vertex map's
	# right and bottom edge, also bottom row's right connection and
	# right column's bottom connection
	for y in range(vertex_map_height):
		for x in range(vertex_map_width):
			# (2x, 2y) is the middle tile of the 3x3 block, where
			# the top left vertex is vertex_map[y][x]
			var vertex = vertex_map[y][x]
			# if the vertex is not vacant (has no edges)
			# in my vertex map generation algorithm, vacant vertices are
			# prohibited, but I still put this line in case I want
			# vacant vertices to be a thing
			if vertex.get_num_connections() != 0:
				# make the tile containing the vertex a path (as the vertex is not vacant)
				tile_map[2 * y][2 * x] = 1
				# connect right and bottom neighboring tiles if there
				# is a connection, check if vertex is along the right
				# and bottom border so that the neighbor tiles don't
				# go out of bounds
				if x < block_map_width and vertex.connections[RIGHT]:
					tile_map[2 * y][2 * x + 1] = 1
				if y < block_map_height and vertex.connections[DOWN]:
					tile_map[2 * y + 1][2 * x] = 1
	# suppressing 1-tile walls
	for y in range(tile_map_height):
		for x in range(tile_map_width):
			# check through every wall tile
			if tile_map[y][x] == 0:
				# check if its neighbors are all path tiles
				var sum_neighboring_path = 0
				for direction in range(4):
					var neighbor_tile = get_facing(tile_map, x, y, direction)
					if neighbor_tile != null:
						if neighbor_tile == 1:
							# neighbor is a path
							sum_neighboring_path += 1
				# four (all) of its neighbors are path
				if sum_neighboring_path == 4:
					# removed randomly based on difficulty-dependent parameter
					if rng.randf() < suppress_one_tile_wall_prob:
						tile_map[y][x] = 1


# Vertex map generation

# class vertex, represents a vertex of a block, whose info can
# be translated into tile map, also stores the vertex's connections
# to neighbor vertices
class Vertex:
	# an bool array of size 4, if true: there is a connection
	# between self vertex and neighboring vertex of some direction
	# connections are synchronized, which means that every time a
	# connection is updated in one vertex, it is also updated in its
	# connected, neighboring vertex
	var connections = [true, true, true, true]
	
	
	# returns the number of connections the vertex has, maximum 4 and minimum 0
	func get_num_connections():
		var num_connections = 0
		for connection in connections:
			if connection:
				num_connections += 1
		return num_connections


# unused method, for debugging purposes
# prints in console what the vertex map looks like
# underscores are used to signify horizontal connections and
# pipes as vertical lines
func _print_vertex_map(vertex_map):
	# print the 1st line of underscores (horizontal connections
	# of topmost vertices)
	var h_bars = ""
	for vertex in vertex_map[0]:
		if vertex.connections[RIGHT]:
			h_bars += " _"
		else:
			h_bars += "  "
	print(h_bars)
	# prints the yth vertices' horizontal connections and y-1th
	# vertices' vertical connections
	for y in range(1, vertex_map.size()):
		var line = ""
		# construct the output for this row
		for x in range(vertex_map[y].size()):
			if vertex_map[y - 1][x].connections[DOWN]:
				line += "|"
			else:
				line += " "
			if vertex_map[y][x].connections[RIGHT]:
				line += "_"
			else:
				line += " "
		print(line)
	print()


# returns a random vertex map, a 2D array of dimension (vertex_map_width, vertex_map_height)
func _create_vertex_map():
	# initialize vertex map
	var vertex_map = []
	for y in range(vertex_map_height):
		var vertex_row = []
		for x in range(vertex_map_width):
			var vertex = Vertex.new()
			# update non-existent border vertices' connections
			if x == 0:
				vertex.connections[LEFT] = false
			if x == block_map_width:
				vertex.connections[RIGHT] = false
			if y == 0:
				vertex.connections[UP] = false
			if y == block_map_height:
				vertex.connections[DOWN] = false
			vertex_row.append(vertex)
		vertex_map.append(vertex_row)
	# the initialized vertex map has all its vertices connected
	# randomly break connections based on difficulty-dependent parameters
	# iterate through every vertex
	for y in range(vertex_map_height):
		for x in range(vertex_map_width):
			# get a list of breakable connections' directions
			var breakable_connections = _get_breakable_connections(vertex_map, x, y)
			# randomly breaks breakable connections
			while breakable_connections.size() > 0:
				if rng.randf() < break_connection_prob:
					# break connection, update both vertices of the conection
					var direction = breakable_connections[rng.randi_range(0, breakable_connections.size() - 1)]
					vertex_map[y][x].connections[direction] = false
					get_facing(vertex_map, x, y, direction).connections[(direction + 2) % 4] = false
					# re-update breakable connections, because breaking a connection
					# could result in the other breakable connection to be not breakable
					breakable_connections = _get_breakable_connections(vertex_map, x, y)
				else:
					# breaking here enables an exponentially decreasing probability
					# of breaking a connection
					break
	return vertex_map


"""
In generating a vertex map, there are two undesirable things:
dead ends and disconnected areas. having lots of dead ends make
it hard for the player to escape from a chasing enemy, and
disconnected areas inconsistently shrinks the size of a map, and
are confusing. Both happen because of broken vertex
connections, resulting in new walls. Dead ends happen when a vertex
is reduce to just one connection, and disconnected areas happen walls
that are not borders completely surround a path. However we still want
to break some connections, because we want to build walls. So we need
to remove them carefully, making sure that removing one connection would
not result in dead ends or disconnected areas or other undesired features. 
"""
# given a 2D array vertex_map, and x, y indices locating the base
# vertex, returns a list of directions towards which the facing
# neighbor's connection can be broke (breaking will not result in
# a dead end or a disconnected area)
func _get_breakable_connections(vertex_map, x, y):
	# the array to be returned, stores directions of breakable connections
	var breakable_directions = []
	var vertex = vertex_map[y][x]  # base vertex
	# suppress dead ends, don't break any connections if 
	# base vertex only has 2 connections, because if you end up
	# just breaking one, it is a dead end.
	# if you can break both of the connections, there will be
	# a vacant vertex (which is fine, as it will be filled up by
	# a wall). but implementing double connection removal sounds
	# complex and unnecessary at this point
	if vertex.get_num_connections() == 2:
		return []
	# check on all its 4 connections, add to list if it is breakable
	for direction in range(4):
		# not breakable if it is already broke
		if vertex.connections[direction] == false:
			continue
		# neighbor vertex
		var facing_vertex = get_facing(vertex_map, x, y, direction)
		# suppress dead ends, check if breaking this connection will
		# make neighbor have only 1 connection
		if facing_vertex.get_num_connections() == 2:
			continue
		if preserve_border_path:
			# if vertex is along the border, don't break the connection
			# along the border, this will result in an all-connected border
			if (x == 0 or x == block_map_width) and (direction == UP or direction == DOWN):
				continue
			if (y == 0 or y == block_map_height) and (direction == LEFT or direction == RIGHT):
				continue
		# suppress disconnected graph, check if breaking this connection
		# will lose this vertex global connection to the neighboring vertex
		vertex.connections[direction] = false  # assume connection is broken
		if _search_global_connection(vertex_map, [x, y], get_facing_xy(x, y, direction), []):
			# satisfies all criteria, is breakable, add to list
			breakable_directions.append(direction)
		# restore the broken connection assumption
		vertex.connections[direction] = true
	return breakable_directions


"""
The big idea to checking if breaking a connection will result in
a disconnected graph is that every vertex in an all-connected graph
should have direct or indirect connections to all other nodes. I
call this a vertex's global connection, consisting of the vertex's
direct connections, and the direct connections of the vertex's direct
connections (indirect connections). Assuming that a graph is all-connected,
one way to see if a connection is breakable is to check if a vertex,
with the connection broken, has global connection to every other vertex,
but to do so is computationally expensive. So an easier way is to check
upon breaking a direct connection, if the vertex has indirect connections
to the broken neighboring vertex. If yes, then the direct connection is
replaceable and thus okay to break, otherwise it is not breakable. In the
following function I am going to be use the second method. 
"""
# given a 2D array vertex_map, xy as an array indicating the indices
# of the base vertex, target_xy as an array indicating the indices
# of the vertex with whom the connection will be broken, visited_xy
# as a list of indices of vertices that have analyzed and do not have
# direct connection with target vertex
# recursive function, returns true if the direct connection between xy
# and target_xy is replaceable by an indirect connection, false otherwise
func _search_global_connection(vertex_map, xy, target_xy, visited_xy):
	# if base and target are the same vertex, then they definitely
	# have direct connection
	if xy == target_xy:
		return true
	# if not, check on its neighbors to see if they have direct
	# connection to target or not
	for direction in range(4):
		# if base is connected to this neighbor
		if vertex_map[xy[1]][xy[0]].connections[direction]:
			var connected_xy = get_facing_xy(xy[0], xy[1], direction)
			# if neighbor is not analyzed before so may have direct
			# connection to target
			if not visited_xy.has(connected_xy):
				# add neighbor to list, as it is analyzed and do not
				# note that if this line is put after the next
				# line overflow error will be resulted, because
				# two connected vertices will loop back and forth
				visited_xy.append(connected_xy)
				# check if neighbor has direct connection to target
				if _search_global_connection(vertex_map, connected_xy, target_xy, visited_xy):
					return true
	# no direct or indirect connections to target
	return false
