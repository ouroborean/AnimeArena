extends Character
class_name Alphonse


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	
	var shield = Effect.shield_effect(30, -1)
	shield.set_source(moveset.base_abilities[3])
	Character.add_allied_effect(context, self, self, shield)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Alphonse Elric"
	path_name = "alphonse"
	universe = CharacterConcept.Universe.FULL_METAL_ALCHEMIST
	description = "Alphonse Elric, the soul of a boy trapped in a suit of armor. After an ill-fated attempt at resurrecting his mother, Alphonse's body was lost in the exchange. After his brother Edward traded his arm and leg to seal his soul in armor, Alphonse joined him on a quest to restore what was taken from them."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
