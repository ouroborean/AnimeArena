extends Character
class_name Zenitsu


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	universe = CharacterConcept.Universe.DEMON_SLAYER
	character_name = "Agatsuma Zenitsu"
	path_name = "zenitsu"
	description = "Zenitsu Agatsuma is a member of the Demon Slayer Corps, who was once a timid and cowardly individual. However, when he is forced to face his fears during a demon attack, he awakens to his true potential and becomes a formidable warrior."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func mastery7_condition(context):
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
