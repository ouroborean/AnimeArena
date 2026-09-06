extends Character
class_name Semiramis


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2]
	character_name = "Semiramis"
	path_name = "semiramis"
	universe = CharacterConcept.Universe.FATE
	description = "The Wise Queen of Assyria, Semiramis is an Assassin and Caster-type Servant summoned by Shirou Kotomine in the Holy Grail War of Fate/Apocrypha."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "semiramis_unlock" in player.unlocks

func _process(delta):
	pass
