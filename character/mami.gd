extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Mami Tomoe"
	path_name = "mami"
	universe = CharacterConcept.Universe.MADOKA_MAGICA
	description = "Mami Tomoe, a kind and generous classmate who becomes Madoka and Sayaka's mentor as magical girls. Her magic lets her control ribbons and summon a wide array of firearms and artillery."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func corruption_stacks(args=[]):
	if not effects.has_effect("Soul Gem: Mami", EffectType.Type.MARK, self):
		return 0
	else:
		return effects.has_effect("Soul Gem: Mami", EffectType.Type.MARK, self).mag

func gain_corruption(args=[]):
	if not has_effect("Soul Gem: Mami", EffectType.Type.MARK):
		return
	effects.has_effect("Soul Gem: Mami", EffectType.Type.MARK, self).change_mag(1)
	if corruption_stacks() >= 8:
		die(self, moveset.base_abilities[5])
	elif corruption_stacks() >= 4:
		if not marked_by("Tiro Concert", self):
			var mark = Effect.mark(-1, "Tiro Concert deals 5 more damage.")
			mark.set_source(moveset.abilities[0])
			Character.add_allied_effect(QueryContext.from_game_state(self, battle), self, self, mark)
			var counter = has_effect("Soul Gem: Mami", EffectType.Type.TICKING_TRIGGER, self)
			if counter:
				counter.description = func (eff): return "Mami will gain 2 stacks of Soul Gem: Mami."
	elif corruption_stacks() >= 3:
		if not marked_by("Tiro Finale", self):
			var mark = Effect.mark(-1, "Ribbon Wrap will swap to Tiro Finale for 1 turn when used.")
			mark.set_source(moveset.abilities[4])
			Character.add_allied_effect(QueryContext.from_game_state(self, battle), self, self, mark)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
