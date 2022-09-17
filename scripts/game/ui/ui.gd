extends CanvasLayer

"""
UI node, extends CanvasLayer, controls UI components that appear
on player's screen regardless of player's movement and the escape
screen

Node structure:
	Timer: auto-starts and has a wait time of 1 second, used to
		update TimeLabel on the top right corner
	DamageMask: default alpha value set to 0， visible when player
		is hurt, much like the blood mask in fps games
	Resurrection: default visibility set to false, animation does
		not loop, played when player uses resurrection
	Guide: a TextureRect as background, a RichTextLabel displaying
		the guide (what enemies there are, how many coins to win
		the game) before start of game. stays visible beofre Guide/Label/Timer
		time out and gradually fades out after game is unfreezed
	Guide/Label/Timer: auto-starts and is one-shot, 3 seconds wait
		time, when timeout calls Game._on_Guide_Timer_timeout() to
		unfreeze the game. this timer does not freeze upon global
		freeze signal because it unfreezes global freeze signal
	RichTextLabel: default visiblity set to false, displays a short
		text in the bottom right corner, aligns to the right
	RichtTextLabel/Timer: one shot and 4 seconds wait time. hides
		RichTextLabel upon timeout
	Esc: the esc page, default visibility set to false, turns on when
		escape is pressed, called by Game._input()
"""

# for easier access to nodes
onready var level_gen = get_node("/root/Game/LevelGen")
onready var player = get_node("/root/Game/Player")
onready var audio = get_node("/root/Game/Audio")
# how many minutes/seconds the game is in, show on the top right corner
var seconds = 0
# an array of size 4 (number of buyable items) containing the
# number of coins needed to buy speed, heal, resurrection and
# game pass
# difficulty-influenced, initialized after LevelGen is initialized
var item_prices
# the number of items displayed in the bottom left corner
# used to determine if there should be a change updated to 
# item_uis
var items_displayed = 0
# an array of size 4 containing 4 item.tscn instances located at
# the bottom left corner, default visiblity set to false, visible
# when the corresponding item is buyable
var item_uis = []
# an array of size 2 containing 2 status.tscn instances located
# under the coin bar, default visibility set to false, visible
# when player buys a vital item (resurrection, game pass)
var status_uis = []
# if set to true, will stop all updates and timers
var freeze = false
# for debugging only, if items' prices should be all 0s
var zero_price_items = false


# initialize UI nodes, called by Game.start_game() but after
# LevelGen is initialized
func initialize():
	# initialize items' prices based on LevelGen's coin_maximum
	if zero_price_items:
		item_prices = [0, 0, 0, 0]
	else:
		item_prices = [max(20, level_gen.coin_maximum / 10), max(50, level_gen.coin_maximum / 5), max(100, level_gen.coin_maximum / 2), level_gen.coin_maximum]
	# update coin maximum on label
	$CoinLabel.text = "0/" + str(level_gen.coin_maximum)
	# instantiate item.tscn and status.tscn instances
	for i in range(item_prices.size()):
		var item = level_gen.instance_scene("ui/item")
		item_uis.append(item)
		add_child(item)
		item.position = Vector2(60 + i * 90, 550)
	for i in range(2):
		var status = level_gen.instance_scene("ui/status")
		status_uis.append(status)
		add_child(status)
		status.position = Vector2(76 + i * 64, 177)
	# initializing guide based on the enemies LevelGen generated
	# the order that these enemy appears on Guide/Label
	var enemy_order = ["gui", "chi", "mei", "wang", "liang"]
	# bbcode string that will be printed on Guide/Label
	var enemy_str = ""
	# if the level has an enemy, print its icon on Guide/Label
	for i in range(enemy_order.size()):
		if level_gen.enemy_names.has(enemy_order[i]):
			enemy_str += "[img=<64>x<64>]assets/image/enemy/" + enemy_order[i] + ".png[/img] "
	# remove that last space to center the icons
	enemy_str.erase(enemy_str.length() - 1, 1)
	# display enemies and coin maximum on Guide/Label
	$Guide/Label.bbcode_text = "[center]\r\n" + enemy_str + "\r\nGoal: get " + str(level_gen.coin_maximum) + "\r\n[tornado radius=5 freq=2]coins[/tornado][/center]"
	# set damage mask and resurrection animation to be transparent
	# by default, can't access modulate.a on Godot Inspector, have
	# to do it through code
	$DamageMask.modulate.a = 0
	$Resurrection.modulate.a = 0.5


# called when a vital item is acquired so that status can be updated
func update_status_ui():
	# an array of size 0-2, if element = 0: display resurrection
	# if element = 1: used resurrection, if element = 2: game pass
	# if there is no element: don't display anything
	# always in the order of game pass -> resurrection
	var status_arr = []
	if player.game_pass == 1:
		status_arr.append(2)
	if player.resurrection == 1:
		status_arr.append(0)
	elif player.resurrection == 2:
		status_arr.append(1)
	# update status scene instances
	for i in range(2):
		var status = status_uis[i]
		if i < status_arr.size():
			# if player has this status, show its type
			status.set_type(status_arr[i])
			status.visible = true
		else:
			# hide if player doesn't have it
			status.visible = false


# when an item is bought, called by item.tscn, passes the argument
# type, if = 0: speed, if = 1: heal, if = 2: resurrection, if = 4:
# game pass
func on_item_bought(type):
	# calls player to obtain the buff of the item
	player.add_buff(type)
	# and substract player's coins
	player.update_coin(-item_prices[type])
	# if the item is speed or heal, play a sound
	# if player buys resurrection or game pass and doesn't have
	# both, play another two sounds
	# if player has both resurrection and game pass, play a fourth sound
	if type == 0 or type == 1:
		audio.get_node("ItemBought/Other").play()
	elif type == 2:
		if player.game_pass == 1:
			audio.get_node("ItemBought/Both").play()
		else:
			audio.get_node("ItemBought/Resurrection").play()
	elif type == 3:
		if player.resurrection == 1:
			audio.get_node("ItemBought/Both").play()
		else:
			audio.get_node("ItemBought/GamePass").play()


# update player's health on health bar
func update_health(health):
	$HealthBar.value = health


# gradually fades away DamageMask and Guide if their alpha values
# are set to be larger than 0
func _process(delta):
	if freeze:
		return
	$DamageMask.modulate.a = max(0, $DamageMask.modulate.a - 0.05 * delta / 0.1666666)
	$Guide.modulate.a = max(0, $Guide.modulate.a - 0.1 * delta / 0.1666666)


# called by Player.update_coin(), updates players' coin amount on UI
# and updates item.tscn if neccessary
func update_coin(coin):
	# update coin label and coin bar
	$CoinLabel.text = str(coin) + "/" + str(level_gen.coin_maximum)
	$CoinBar.value = 100.0 * coin / level_gen.coin_maximum
	# an array of size 0-4, if element = 0: speed, = 1: heal,
	# = 2: resurrection, = 3: game pass, if element doesn't exist
	# player doesn't have coins to buy it
	# find what items player can buy
	var items_can_buy = []
	for i in range(item_prices.size()):
		# player cannot buy resurrection or game pass twice
		if coin >= item_prices[i] and not (i == 2 and player.resurrection != 0) and not (i == 3 and player.game_pass != 0):
			items_can_buy.append(i)
	# invert items can buy so that the more expensive ones go on the left
	items_can_buy.invert()
	# check if the old item.tscn needs to be updated
	# this method of checking number of buyable items may not work
	# if new items were to be introduced in the game
	if items_can_buy.size() != items_displayed:
		# item.tscn needs to be updated, update number of buyable items
		items_displayed = items_can_buy.size()
		for i in range(item_prices.size()):
			var item = item_uis[i]
			if i < items_can_buy.size():
				# display the buyable item's type
				item.visible = true
				var type = items_can_buy[i]
				item.set(type, item_prices[type])
			else:
				# hides the item scene if cannot buy more items
				item.visible = false


# time out every second, update time into the game on TimeLabel
func _on_Timer_timeout():
	seconds += 1
	var label_text = ""
	if seconds / 60 < 10:
		label_text += "0"
	label_text += str(seconds / 60) + ":"
	if seconds % 60 < 10:
		label_text += "0"
	label_text += str(seconds % 60)
	$TimeLabel.text = label_text


# when global freeze signal is emitted from Game, freeze updates and stop timers
# don't stop Guide/Label/Timer because it unfreezes the signal
func _on_game_global_freeze(freeze):
	self.freeze = freeze
	if freeze:
		$Timer.stop()
		$RichTextLabel/Timer.stop()
	else:
		$Timer.start()
		$RichTextLabel/Timer.start()


# when resurrection animation is finished, hides the sprite
func _on_Resurrection_animation_finished():
	$Resurrection.visible = false


# display a bbcode text in the RichTextLabel at the bottom right
func set_rich_text(text):
	$RichTextLabel.bbcode_text = text
	$RichTextLabel.visible = true
	# start the timer so that after 4 seconds the label is hidden
	$RichTextLabel/Timer.start()


# time out and hides the message on the RichTextLabel at the bottom right
func _on_RichTextLabel_Timer_timeout():
	$RichTextLabel.visible = false
