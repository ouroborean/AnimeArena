class_name DamageType

enum Type {
	NORMAL,
	ENERGY,
	PHYSICAL,
	PIERCING,
	AFFLICTION,
	BLEED,
	TRUE
}

static func get_damage_type_name(d_type, pretty=false):
	var string = Type.keys()[d_type]
	if pretty:
		string = string.capitalize()
	else:
		string = string.to_lower()
	return string
