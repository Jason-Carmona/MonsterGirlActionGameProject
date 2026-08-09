extends Node

signal line_displayed(speaker, text, portrait)
signal choices_shown(choices_array)
signal dialogue_ended()

var current_data: Array
var current_index: int = 0

func load_dialogue(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Could not load dialogue file:", file_path)
		return
	
	var json_text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("JSON could not be loaded: ", parse_result)
		return
	
	current_data = json.data
	current_index = 0
	show_line()
	print("load_dialogue function complete.")
# starts off at the beginning of the json and just goes down
func start_dialogue(json_resource):
	current_data = json_resource
	current_index = 0
	show_line()

# display current line in JSON to screen
func show_line():
	if current_index >= current_data.size():
		dialogue_ended.emit()
		return
	
	var line = current_data[current_index]
	if line.has("choices"):
		choices_shown.emit(line["choices"])
	else:
		line_displayed.emit(line["speaker"], line["text"], line["portrait"])

# function to iterate through JSON 
func advance():
	current_index += 1
	show_line()

func make_choice(choice_id):
	# Jump to specific part of JSON for choices
	for i in range(current_data.size()):
		if current_data[i].has("id") and current_data[i]["id"] == choice_id:
			current_index = i
			show_line()
			return
		
