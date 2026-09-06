class_name Energy

enum Type {
	GREEN,
	BLUE,
	WHITE,
	RED,
	RANDOM
}

static func get_symbol(energy_type):
	var energy_string = Energy.Type.keys()[energy_type]
	var tooltip = load("res://assets/images/" + energy_string.to_lower() + "_energy.png")
	return tooltip
	
static func get_energy_name(energy_type, pretty=false):
	var string = Element.Type.keys()[energy_type]
	if pretty:
		string = string.capitalize()
	else:
		string = string.to_lower()
	return string
