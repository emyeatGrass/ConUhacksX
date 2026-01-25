extends Node2D

const POOL_SIZE = 30
var coins: Array[Area2D] = []
var coin_scene = preload("res://scenes/coin.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in POOL_SIZE:
		var coin = coin_scene.instantiate()
		coin.hide()
		add_child(coin)
		coins.push_back(coin)
		
func get_coin() -> Area2D:
	for coin in coins:
		if not coin.visible:
			coin.show()
			return coin
	return null
