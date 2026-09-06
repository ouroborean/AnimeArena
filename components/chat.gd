extends Node
class_name Chat

var message_history = []
var chat_id

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func incoming_message(sender, message):
	add_message(sender, message)

func add_message(sender, message):
	var message_text = sender + ": " + message
	message_history.append(message_text)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
