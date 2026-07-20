extends Label

## Placeholder health readout. Swap for heart sprites once you have art.

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# Signals are how nodes talk without holding hard references to each other.
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.MAX_HEALTH)


func _on_health_changed(current: int, maximum: int) -> void:
	text = "HP  " + "*".repeat(current) + ".".repeat(maxi(maximum - current, 0))
