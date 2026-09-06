extends Character
class_name Gilgamesh


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Gilgamesh"
	path_name = "gilgamesh"
	universe = CharacterConcept.Universe.FATE
	description = "Gilgamesh, the legendary King of Heroes and a Heroic Spirit summoned in the role of Archer. Gilgamesh is a proud warrior, and can summon a myriad of Noble Phantasms from the endless vaults he amassed during his life to overwhelm his foes with their individual power or the sheer weight of their blades."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
