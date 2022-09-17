extends Node2D

"""
Audio node, controls all audio sources and houses all AudioStreamPlayers
(non-positional audio players)

Node structure:
	Ambience: looped game ambience
	Appear: plays a srandom ound when an ememy appears in camera
		vision, has a cooldown of 5 seconds, timed by Appear/Timer
	Heartbeat: looped heartbeat, its pitch can be adjusted by
		Player
	Hurt: plays a random sound when player is hurt, doesn't
		have a cooldown, but cannot override an already-playing
		audio
	EnemyNoiseTimer: auto-starts, one-shot and has a wait time of 1,
		plays a random enemy noise 1 second after the previous enemy
		noise finishes playing. the enemy noises are AudioStreamPlayer2Ds
		(positional audio) under enemy scenes
	ItemBought: plays corresponding audio when player buys an item
	Prop: plays corresponding audio when player collects a prop
	ResurrectionUsed: plays an audio when player uses resurrection
	TunnelEntered: plays an audio when player enters tunnel for the first time
"""

# if set to true, then an enemy appear sound will play when enemy
# enters camera vision. if false, the sound is on cooldown and no
# sound will be played when enemy enters camera vision
var play_enemy_appear = true
var rng = RandomNumberGenerator.new()


func _ready():
	rng.randomize()


# called when global freeze signal is emitted from Game,
# stops all timers and pauses all audio streams
func _on_global_freeze(freeze):
	# stop/play all timers
	if freeze:
		$Ambience.stop()
		$Heartbeat.stop()
	else:
		$Ambience.play()
		$Heartbeat.play()
	# pause/resume audio players under self
	$Appear.stream_paused = freeze
	$Hurt.stream_paused = freeze
	$ItemBought/Both.stream_paused = freeze
	$ItemBought/GamePass.stream_paused = freeze
	$ItemBought/Other.stream_paused = freeze
	$ItemBought/Resurrection.stream_paused = freeze
	$Prop/Coin.stream_paused = freeze
	$Prop/Ice.stream_paused = freeze
	$Prop/VisionBuff.stream_paused = freeze
	$ResurrectionUsed.stream_paused = freeze
	$TunnelEntered.stream_paused = freeze
	# pause/resume positional audio players
	get_node("/root/Game/Tunnel/Area2D/EndGate/Audio").stream_paused = freeze
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.get_node("Noise").stream_paused = freeze


# given argument vol, a double in range from 0 to 1, adjust all
# volumes except audio associated with tunnels from 0 (silence)
# to 1 (full volume). called when player enters tunnel, or when
# player acquires resurrection and game pass
func set_all_volume(vol):
	# adjust all audio players under self
	$Ambience.volume_db = -10 + vol * 20
	$Heartbeat.volume_db = -40 + vol * 40
	$Appear.volume_db = -50 + vol * 55
	$Hurt.volume_db = -30 + vol * 30
	$ItemBought/GamePass.volume_db = -35 + vol * 30
	$ItemBought/GamePass.volume_db = -30 + vol * 30
	$ItemBought/Other.volume_db = -30 + vol * 30
	$ItemBought/Resurrection.volume_db = -40 + vol * 30
	$Prop/Coin.volume_db = -35 + vol * 20
	$Prop/Ice.volume_db = -30 + vol * 20
	$Prop/VisionBuff.volume_db = -30 + vol * 30
	$ResurrectionUsed.volume_db = -30 + vol * 30
	# notice that TunnelEntered and Tunnel/Area2D/EndGate/Audio
	# are not adjusted because we want players to always hear
	# those sound effects
	# adjust positional audio players
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.get_node("Noise").volume_db = -30 + vol * 30


# given argument speed, a double in range from 0 (slowest, default
# pitch) to 1 (maximum pitch). increasing the pitch increases
# playback speed
func set_heartbeat_speed(speed):
	$Heartbeat.pitch_scale = 1 + speed * 2


# called by Player.update_health()
# when player is damaged, play hurt sound unless it is already being played
func on_damaged():
	if not $Hurt.playing:
		_play_stream($Hurt, "hurt/" + str(rng.randi_range(0, 1)) + ".mp3")


# called by Player/Camera2D/Area2D
# when an enemy appears in camera vision, play enemy appear sound
# unless the play sound is on cool down
# unused argument position: denotes the position of the enemy
# entering the screen. I had the idea of making the audio player
# positional and place it at the position of the enemy, but I don't
# think it's very important
func on_enemy_appear(position):
	if play_enemy_appear:
		_play_stream($Appear, "enemy_appear/" + str(rng.randi_range(0, 6)) + ".mp3")
		# starts enemy appear sound cooldown
		play_enemy_appear = false
		$Appear/Timer.start()


# when enemy appear sound cooldown is over, allows the sound to play again
func _on_appear_timer_timeout():
	play_enemy_appear = true


# utility function, given player an AudioStreamPlayer(2D), plays
# the audio source at string path
# note that the function can only load mp3 but not wav, because
# wav audios do not have set_loop() method. also note that mp3
# are by default looped and wav are not
func _play_stream(player, path):
	var sfx = load("res://assets/audio/" + path)
	sfx.set_loop(false)
	player.stream = sfx
	player.play()


# called by enemies' AudioStreamPlayer2D, when their enemy noise
# finishes playing, starts timer before playing another noise
func on_enemy_noise_finished():
	$EnemyNoiseTimer.start()


# when timeout, play exactly one enemy noise on a random enemy's
# AudioStreamPlayer2D
func _on_EnemyNoiseTimer_timeout():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() > 0:
		var rand_enemy = enemies[rng.randi_range(0, enemies.size() - 1)]
		_play_stream(rand_enemy.get_node("Noise"), "enemy_noises/" + str(rng.randi_range(0, 5)) + ".mp3")
