extends Character
class_name Byakuya


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2, 3]
	character_name = "Byakuya Kuchiki"
	path_name = "byakuya"
	universe = CharacterConcept.Universe.BLEACH
	description = "Byakuya Kuchiki, the 28th head of the Kuchiki Clan, serves as the Captain of the 6th squad of the Gotei 13. He controls thousands of blades at once using his zanpakutou, crushing enemies beneath a storm of cherry blossoms."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "byakuya_unlock" in player.unlocks

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
