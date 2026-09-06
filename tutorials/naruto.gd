extends TutorialTemplate


func build(character) -> Array:
	var s 
	s.line(character.character_name)
	s.line("The Hidden Leaf's loudest ninja.", 2.0)
	s.page_break()
	s.line("Naruto's kit revolves around stacking Shadow Clones, then converting them into burst damage through Rasengan.")
	for ability in character.moveset.abilities:
		s.page_break()
		s.ability_segment(ability)
	s.page_break()
	s.line("Tip: Save Sage Chakra Gather for a finishing turn — the bonus damage is highest when you can spike a single target.")
	return s.build()
