extends Control
class_name MenuTextComponent
var message = "Sample Message"
@export var label: Label
@export var color_panel: TextureRect
@export var border_panel: TextureRect

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_message(new_message):
	message = new_message
	label.text = message



static func from_message(msg, size=Vector2(800, 65)):
	var menu = load("res://components/menu_text_component.tscn").instantiate()
	menu.change_size(size)
	menu.set_message(msg)
	
	return menu
	
func change_size(nsize):
	var new_x = nsize.x
	var new_y = nsize.y
	color_panel.size = Vector2(new_x, new_y)
	border_panel.size = Vector2(new_x + 4, new_y + 4)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
