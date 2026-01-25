extends Node

@export var pool_size := 15

# Assign these in the Inspector.
@export var coin_fling_sounds: Array[AudioStream] = []
@export var enemy_hit_sounds: Array[AudioStream] = []
@export var sword_attack_sounds: Array[AudioStream] = []
@export var explosion_sounds: Array[AudioStream] = []
@export var player_hurt_sounds: Array[AudioStream] = []
@export var game_over_sound: Array[AudioStream] = []

var _audio_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in pool_size:
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		_audio_pool.append(audio_player)

func play_sound(
	sounds: Array[AudioStream],
	pitch_min: float = 0.95,
	pitch_max: float = 1.05
) -> void:
	if sounds.is_empty():
		return

	for audio_player in _audio_pool:
		if not audio_player.playing:
			_play_on(audio_player, sounds, pitch_min, pitch_max)
			return

	# All busy: steal the first one.
	_play_on(_audio_pool[0], sounds, pitch_min, pitch_max)


func play_coin_fling() -> void:
	play_sound(coin_fling_sounds, 0.9, 1.1)


func play_enemy_hit() -> void:
	play_sound(enemy_hit_sounds, 0.9, 1.1)
	
func play_sword_attack() -> void:
	play_sound(sword_attack_sounds)
	
func play_explosion() -> void:
	play_sound(explosion_sounds)

func play_player_hurt() -> void:
	play_sound(player_hurt_sounds, 0.8, 1.2)

func play_game_over() -> void:
	play_sound(game_over_sound)


func _play_on(
	audio_player: AudioStreamPlayer,
	sounds: Array[AudioStream],
	pitch_min: float,
	pitch_max: float
) -> void:
	audio_player.stop()
	audio_player.stream = sounds.pick_random()
	audio_player.pitch_scale = randf_range(pitch_min, pitch_max)
	audio_player.play()
