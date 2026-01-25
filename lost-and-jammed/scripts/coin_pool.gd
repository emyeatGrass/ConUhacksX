extends Node2D

const POOL_SIZE = 30
var coins: Array[Area2D] = []
var coin_scene = preload("res://scenes/coin.tscn")


func _ready() -> void:
	for i in POOL_SIZE:
		var coin = coin_scene.instantiate()
		coin.hide()
		add_child(coin)
		coins.push_back(coin)
		
func get_coin() -> Area2D:
	# Pooling strategy: visible == in use. Hidden == "available".
	# Is it elegant? No. Is it fast and does it keep me from thinking? Yes.
	for coin in coins:
		if not coin.visible:
			coin.show()
			return coin
	return null
