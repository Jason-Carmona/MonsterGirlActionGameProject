extends CanvasLayer

@onready var panel: Panel = $Dialog/Panel
@onready var speaker_label: Label = $Dialog/Panel/VBoxContainer/Speaker
@onready var dialogue_label: Label = $Dialog/Panel/VBoxContainer/Dialogue
@onready var continue_button: Button = $Dialog/Panel/VBoxContainer/HBoxContainer/Continue
@onready var portrait_texture: TextureRect = $Dialog/Panel/Portrait


var full_text: String = ""
var is_revealing: bool = false

func _ready():
	# Connect signals here
	DialogueManager.line_displayed.connect(_on_line_displayed)
	continue_button.pressed.connect(_on_continue_pressed)
	visible = false
	
func _on_line_displayed(speaker: String, text: String, portrait: String):
	

	if portrait != "" and ResourceLoader.exists(portrait):
		var texture = load(portrait)
		portrait_texture.visible = true
		portrait_texture.texture = texture
	else: 
		portrait_texture.visible = false
		
	speaker_label.text = speaker
	speaker_label.visible = (speaker != "")
	full_text = text
	dialogue_label.text = text
	is_revealing = true
	visible = true
	
	
	 #Start the typewriter effect
	$TypewriterTimer.start(0.03)
	
func _on_typewriter_timer_timeout():
	if dialogue_label.text.length() < full_text.length():
		dialogue_label.text += full_text[dialogue_label.text.length()]
	else:
		is_revealing = false
		$TypewriterTimer.stop()

func _on_continue_pressed():
	if is_revealing:
		# Skip to the end of text
		dialogue_label.text = full_text
		is_revealing = false
		$TypewriterTimer.stop()
	else:
		DialogueManager.advance()

func open():
	visible = true

func close():
	visible = false
	
