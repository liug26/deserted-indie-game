extends Node2D

"""
Navigation is in charge of finding locations on the map, contains
a few utility functions and the A* path finding algorithm. 
"""

# for easier access to nodes and variables
onready var level_gen = get_node("/root/Game/LevelGen")
onready var tile_to_pixel_ratio = level_gen.tile_to_pixel_ratio

var rng = RandomNumberGenerator.new()


func _ready():
	rng.randomize()


# given an array containing the x and y indices of a tile, returns
# an array containing the x and y pixel value of the tile
# an offset is added so that the returned x and y points to the
# center of the tile
func tile_to_pixel(tile_xy):
	var offset = tile_to_pixel_ratio / 2
	return Vector2(tile_xy[0] * tile_to_pixel_ratio + offset, tile_xy[1] * tile_to_pixel_ratio + offset)


# returns the x and y indices of a random tile in tile map that
# is a path
# unstable: if there are no path tiles in tile map, the function
# will stuck in an infinite loop
func rand_path_tile():
	var tile_map = level_gen.tile_map
	var rand_indices = [rng.randi_range(0, tile_map[0].size() - 1), rng.randi_range(0, tile_map.size() - 1)]
	while tile_map[rand_indices[1]][rand_indices[0]] != 1:
		rand_indices = [rng.randi_range(0, tile_map[0].size() - 1), rng.randi_range(0, tile_map.size() - 1)]
	return rand_indices


# given tile_xy the x and y indices of the base tile, and a number
# distance, returns the x and y indices of a random tile in
# tile map that is both a path and is located at least
# [distance] away from base tile
# unstable: uses rand_path_tile(), function can stuck in infinite
# loop if there are no path tiles that are distance away from
# base tile
func rand_path_tile_away_from(tile_xy, distance):
	var rand_tile = rand_path_tile()
	while pow(tile_xy[0] - rand_tile[0], 2) + pow(tile_xy[1] - rand_tile[1], 2) < pow(distance, 2):
		rand_tile = rand_path_tile()
	return rand_tile


# returns the number of path tiles in tile map
func get_path_tile_count():
	var count = 0
	var tile_map = level_gen.tile_map
	for row in tile_map:
		for tile in row:
			if tile == 1:
				count += 1
	return count


"""
A* algorithm for helping enemies find the shortest path to locations,
while not staying too computionally expensive. 
Referenced website: https://stackabuse.com/graphs-in-java-a-star-algorithm/
"""
# self_xy, an array of size 2 containing the pixel position of
# self, and target_xy, an array of size 2 containing the pixel
# position of target
# returns a list containing multiple pixel locations that is the
# shortest path from self to target, returns an empty list if
# target is unreachable
func a_star_path(self_xy, target_xy):
	var tile_map = level_gen.tile_map
	# convert self and target pixel position to tile position
	var self_tile = [floor(self_xy[0] / tile_to_pixel_ratio), floor(self_xy[1] / tile_to_pixel_ratio)]
	var target_tile = [floor(target_xy[0] / tile_to_pixel_ratio), floor(target_xy[1] / tile_to_pixel_ratio)]
	# if they are in the same tile, then the shortest path is
	# to just go in a straight line at the direction of target
	if self_tile == target_tile:
		return [target_xy]
	"""
	there are 2 lists: open and closed list. open list contains
	candidate tiles that are neighbors of members of the closed
	list, tiles that we've encountered but havene't analyzed yet.
	each iteration the "best" open list candidate is picked based
	on cost f, is then analyzed and thrown into closed list. Initially
	open list contains only self tile.
	closed list contains tiles whose neighbors are all added to
	the open list, and are fully analyzed
	"""
	var open_list = [self_tile]
	var closed_list = []
	"""
	cost function f(n) = g(n) + h(n), move function + heuristic function
	move function is how many tiles it takes to arrive at tile n,
	which is the number we want to minimize, and we use a heuristic
	to more quickly estimate the shortest path. i use the manhattan
	heuristic, for more info see: http://theory.stanford.edu/~amitp/GameProgramming/Heuristics.html
	"""
	# g and f are 2D arrays of dimension (tile_map_width, tile_map_height)
	# parent is also of the same dimension, but its elements store
	# arrays of size 2 containing x and y indices (so it's 3D array)
	var g = _init_2d_transpose_array(tile_map)
	var f = _init_2d_transpose_array(tile_map)
	# parent tells each tile what indices its parent tile has
	# benig a parent of a tile means you are the shortest path
	# from self tile to this tile, used during path traceback
	# note that initial_value has to be [], otherwise error will
	# result in _traceback()
	var parent = _init_2d_transpose_array(tile_map, [])
	# iterate through open list
	while open_list.size() > 0:
		# find the tile from open list with the least f value
		# open list's tiles' f values are calculated before they are
		# added to the open list, with the exception of the starting
		# tile, but there will only be one element in open list anyways
		# in my case 9999 is large enough, but if the map were to be
		# large this needs to change
		var least_f = 9999
		var open
		for o in open_list:
			if f[o[0]][o[1]] < least_f:
				open = o
				least_f = f[o[0]][o[1]]
		# if the least-f tile from open list is the target tile
		# you've found the shortest path, do a parent traceback
		if open == target_tile:
			# parent traceback, returns a list of tile positions that
			# lead self tile to target tile
			var tile_path = _traceback(open, parent)
			# convert tile path to pixel path
			var pixel_path = []
			for i in range(tile_path.size()):
				if i == tile_path.size() - 1:
					# last element of tile path is the target path,
					# instead of going to the center of the target tile
					# and then going to target location, go straight to target
					# location from last tile, since last tile is a neighbor of
					# target tile, it is okay to go in a straight line
					pixel_path.append(target_xy)
				else:
					# note that tile_to_pixel returns the position of
					# the center of the tile
					pixel_path.append(tile_to_pixel(tile_path[i]))
			return pixel_path
		# if the least-f open tile is not the target tile, check on its neighbors
		for direction in range(4):
			# the x and y indices of a neighbor tile
			var neighbor_tile = level_gen.get_facing_xy(open[0], open[1], direction)
			# the neighbor tile
			var tile = level_gen.get_facing(tile_map, open[0], open[1], direction)
			# check if tile is out of bounds or tile isn't path
			if tile == null or tile != 1:
				continue
			# check if neighbor is not encountered before
			if not closed_list.has(neighbor_tile) and not open_list.has(neighbor_tile):
				# neighbor is not encoutnered before, queue it in open list
				# to analyze it later
				open_list.append(neighbor_tile)
				# update its parent as the least-f open tile
				parent[neighbor_tile[0]][neighbor_tile[1]] = open
				# also calculate g and f of the neighbor tile
				g[neighbor_tile[0]][neighbor_tile[1]] = g[open[0]][open[1]] + 1
				f[neighbor_tile[0]][neighbor_tile[1]] = g[neighbor_tile[0]][neighbor_tile[1]] + _heuristic(open[0], open[1], neighbor_tile[0], neighbor_tile[1])
			else:
				# if tile is encountered before, tile has a parent
				# check if the least-f open tile gives a shorter path to the neighbor
				# than its previous parent
				# note that we compare g not f, because we want to minimize g
				if g[open[0]][open[1]] + 1 < g[neighbor_tile[0]][neighbor_tile[1]]:
					# if least-f open tile gives a shorter path, re-update
					# least-f open tile as neighbor's parent, and re-calculate
					# neighbor's f and g
					parent[neighbor_tile[0]][neighbor_tile[1]] = open
					g[neighbor_tile[0]][neighbor_tile[1]] = g[open[0]][open[1]] + 1
					f[neighbor_tile[0]][neighbor_tile[1]] = g[neighbor_tile[0]][neighbor_tile[1]] + _heuristic(open[0], open[1], neighbor_tile[0], neighbor_tile[1])
					# move neighbor to open list, if it's in closed list, because
					# we have not analyzed its new information yet
					if closed_list.has(neighbor_tile):
						closed_list.erase(neighbor_tile)
						open_list.append(neighbor_tile)
		# you have fully analyzed the least-f open tile, move it to closed list
		open_list.erase(open)
		closed_list.append(open)
	# you have iterated through the entire open list, target is unreachable
	print("unreachable path")  # this shouldn't really happen
	return []


# given a 2D array of dimension (y, x) (y rows and x columns)
# return a 2D array of dimension (x, y) with initial values set
# to initial_value (default 0)
func _init_2d_transpose_array(tile_map, initial_value=0):
	var arr = []
	for x in range(tile_map[0].size()):
		var col = []
		for _y in range(tile_map.size()):
			col.append(initial_value)
		arr.append(col)
	return arr


# manhattan heuristic h(n), used to calculate cost f(n)
# given x and y of base position and x and y of target position
# returns the manhattan distance between self and target
func _heuristic(self_x, self_y, target_x, target_y):
	return abs(self_x - target_x) + abs(self_y - target_y)


# recursive function, given xy, an array containing the x and y
# indices of base tile, and parent, a 3D array containing the x
# and y indices of every tile's parent's x and y indices
# returns a list that starts from the child of self tile,
# child of child of self tile... to base tile indexed by xy
func _traceback(xy, parent):
	if parent[xy[0]][xy[1]] == []:
		# if tile doesn't have parent, then it is the starting self tile
		# don't pass self tile because self is already in self tile
		return []
	else:
		# if tile has a parent, then get the path that leads to parent
		var path = _traceback(parent[xy[0]][xy[1]], parent)
		# append tile to parent's path
		path.append(xy)
		return path
