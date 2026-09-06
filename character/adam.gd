extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Adam"
	character_colors = [2, 3]
	universe = CharacterConcept.Universe.RECORD_OF_RAGNAROK
	path_name = "adam"
	description = "The First Human. Created by God in His own image and cast out of Eden, Adam fights on behalf of humanity in Ragnarok, wielding Divine Reflection to turn the gods' own power against them. His unblinking Eyes of the Lord let him endure any blow."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
