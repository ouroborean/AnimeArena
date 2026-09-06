extends Character
class_name Yamamoto


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	gain_flames([0])

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Yamamoto Takeshi"
	path_name = "yamamoto"
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	description = "Yamamoto Takeshi, the Vongola Guardian of Rain. The heir to the Shigure Soen Ryu style of swordsmanship, Yamamoto is a mild-mannered teenager who has more interest in enjoying his time with his friends than improving the Vongola Mafia family."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func gain_flames(args):
	var count = args[0]
	var context = QueryContext.from_game_state(self, battle)
	var mark = Effect.mark(-1, func (eff): return "Yamamoto has " + str(eff.stacks) + " stacks of Asari Ugetsu.")
	mark.stacks = count
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(moveset.base_abilities[2])
	Character.add_allied_effect(context, self, self, mark)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
