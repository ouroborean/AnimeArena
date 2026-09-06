extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Yugi Mutou"
	path_name = "yugi"
	universe = CharacterConcept.Universe.YUGIOH
	character_colors = [2]
	description = "Yugi Mutou, bearer of the Millenium Puzzle and vessel for the ancient pharaoh Atem. Though his heart is peaceful and kind, when pushed into a corner he calls forth Atem's power to become the King of Games."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func check_card(args):
	var card_name = args[0]
	var mark = has_effect("Exodia, the Forbidden One", EffectType.Type.MARK)
	if mark:
		if not (card_name in mark.ability_targets):
			mark.ability_targets.append(card_name)
		mark.mag = len(mark.ability_targets)
		if mark.mag < 5:
			return
		var swap1 = Effect.ability_swap_effect(6, 0, self, -1)
		swap1.set_source(moveset.base_abilities[5])
		var swap2 = Effect.ability_swap_effect(6, 1, self, -1)
		swap2.set_source(moveset.base_abilities[5])
		var swap3 = Effect.ability_swap_effect(6, 2, self, -1)
		swap3.set_source(moveset.base_abilities[5])
		var swap4 = Effect.ability_swap_effect(6, 3, self, -1)
		swap4.set_source(moveset.base_abilities[5])
		var context = QueryContext.from_game_state(self, battle)
		Character.add_allied_effect(context, self, self, swap1)
		Character.add_allied_effect(context, self, self, swap2)
		Character.add_allied_effect(context, self, self, swap3)
		Character.add_allied_effect(context, self, self, swap4)
		var trigger = Effect.trigger_effect(Trigger.always(use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "Once Yugi uses Obliterate! his skills will return to their original versions.")
		trigger.set_source(moveset.base_abilities[5])
		Character.add_allied_effect(context, self, self, trigger)

func use_trigger(context):
	if context.owner.used_ability.ability_name != "Obliterate!":
		return
	effects.full_remove_effect_by_name("Exodia, the Forbidden One")

func is_unlocked(player):
	return "yugi_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
