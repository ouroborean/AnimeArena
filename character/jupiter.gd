extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sailor Jupiter"
	path_name = "jupiter"
	character_colors = [1]
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Makoto Kino, the girl known as Sailor Jupiter. A naturally strong girl with a tomboyish presentation, Jupiter is actually a gentle and kind Sailor Senshi. Though her specialty is her physical strength, she can also control plants and devastating electrical energy."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func gain_shield_break(args):
	var context = args[0]
	manually_advance_mission(6, 1)
	var boost = Effect.damage_mod_effect(5, -1, ["Supreme Thunder"])
	boost.set_source(moveset.base_abilities[4])
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	Character.add_allied_effect(context, self, self, boost)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
