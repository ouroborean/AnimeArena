extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Jaden Yuki"
	path_name = "jaden"
	character_colors = [0, 1, 2, 3]
	universe = CharacterConcept.Universe.YUGIOH
	description = "Jaden Yuki, a new duelist in the next generation. Able to hear the voices inside the cards, he and his Elemental Hero cards are a force for righteousness."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func break_hero(args):
	var context = args[0]
	var effect = context['effect']
	var ability_name = effect.source.ability_name
	for character in battle.all_characters():
		character.effects.full_remove_effect_by_name(ability_name, self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
