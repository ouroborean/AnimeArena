class_name Element

enum Type {
	BASE,
	FIRE,
	ICE,
	WATER,
	LIGHTNING,
	WIND,
	POISON,
	EARTH,
	HOLY,
	UNHOLY,
	SHADOW,
	GENERIC
}

static func get_symbol(element):
	var element_string = Element.Type.keys()[element]
	var tooltip = load("res://assets/tooltips/" + element_string.to_lower() + "_energy.png")
	return tooltip
	
static func get_element_name(element, pretty=false):
	var string = Element.Type.keys()[element]
	if pretty:
		string = string.capitalize()
	else:
		string = string.to_lower()
	return string
