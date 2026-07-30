extends Node

@onready var _speaker : Label = $MarginContainer/Panel/VBoxContainer/Speaker
@onready var _dialogue: RichTextLabel = $MarginContainer/Panel/VBoxContainer/Dialogue

func display_line(speaker : String, line = String):
	_speaker.visible = (speaker != "")
	_speaker.text = speaker
	_dialogue.text = line
	open()

func open():
	visible = true

func close():
	visible = false
	
func _on_continue_pressed:
	close()
	
