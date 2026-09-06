extends RefCounted
class_name TutorialLoader


static func script_for(character) -> Array:
	var path := "res://tutorials/%s.gd" % character.path_name
	if ResourceLoader.exists(path):
		var tutorial_class = load(path)
		if tutorial_class != null:
			var instance = tutorial_class.new()
			if instance.has_method("build"):
				return instance.build(character)
	return _auto_generate(character)


static func _auto_generate(character) -> Array:
	var s := DescriptionScript.new()
	s.line(character.character_name)
	if "description" in character and character.description != "":
		s.line(character.description, 3.0)
	if "moveset" in character and character.moveset != null:
		for ability in character.moveset.abilities:
			s.page_break()
			s.ability_segment(ability)
	return s.build()
