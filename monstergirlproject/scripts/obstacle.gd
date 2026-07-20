@tool
extends StaticBody2D

## A solid block. Drag into a room, set the size in the Inspector, done.
##
## `@tool` means this script also runs inside the editor, so resizing updates
## the art and the collision shape live in the viewport instead of only at
## runtime. That live feedback is the whole point for level building.

@export var size := Vector2(48, 48):
	set(value):
		size = value
		_rebuild()

@export var color := Color(0.36, 0.33, 0.42):
	set(value):
		color = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# Setters fire before children exist when loading from a scene file.
	if not is_node_ready():
		return

	var h := size * 0.5
	$Art.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y),
	])
	$Art.color = color

	var shape := $CollisionShape2D.shape as RectangleShape2D
	if shape:
		shape.size = size
