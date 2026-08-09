extends Node2D

func _ready():
	print("Test scene loaded!")
	await get_tree().process_frame
	print("Calling load_dialogue...")
	DialogueManager.load_dialogue("res://data/test.json")
	
