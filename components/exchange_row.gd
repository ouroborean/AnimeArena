extends HBoxContainer
class_name ExchangeRow

var energy_type: Energy.Type
var held: int
var offered: int
var offer_disabled = false
var remove_disabled = false
signal change_offer(etype, val)

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()


static func from_energy_type(etype, val):
	var row = load("res://components/exchange_row.tscn").instantiate()
	row.set_labels(val)
	row.set_type(etype)
	return row

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_labels(val):
	held = val
	offered = 0
	$OwnedLabel.text = str(int(val))
	$OfferedLabel.text = "0"

func update_labels():
	$OwnedLabel.text = str(int(held))
	$OfferedLabel.text = str(int(offered))

func set_type(etype):
	energy_type = etype
	$EnergyTexture.texture = Energy.get_symbol(etype)

func offer_energy():
	if held > 1 and not offer_disabled:
		offered += 2
		held -= 2
		update_labels()
		change_offer.emit(energy_type, 2)

func show_offer():
	$OfferButton.modulate = Color.WHITE
	offer_disabled = false

func show_remove():
	$RemoveButton.modulate = Color.WHITE
	remove_disabled = false
	
func hide_offer():
	$OfferButton.modulate = Color.DIM_GRAY
	offer_disabled = true

func hide_remove():
	$RemoveButton.modulate = Color.DIM_GRAY
	remove_disabled = true

func remove_energy_offer():
	if offered > 1 and not remove_disabled:
		offered -= 2
		held += 2
		update_labels()
		change_offer.emit(energy_type, -2)

func click_offer(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		offer_energy()
		
func click_remove_offer(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		remove_energy_offer()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_remove_button_mouse_entered():
	$RemoveButton.modulate = Color.hex(0xff2d21ff)
	play_sound("hover")


func _on_remove_button_mouse_exited():
	$RemoveButton.modulate = Color.WHITE


func _on_offer_button_mouse_entered():
	$OfferButton.modulate = Color.hex(0xff2d21ff)
	play_sound("hover")


func _on_offer_button_mouse_exited():
	$OfferButton.modulate = Color.WHITE
