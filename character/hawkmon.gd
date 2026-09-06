extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Hawkmon"
	path_name = "hawkmon"
	universe = CharacterConcept.Universe.DIGIMON
	character_colors = [1, 3]
	description = "Hawkmon, a calm and collected Avian Digimon. It attacks using its claws and beaks until it has stored enough energy to Digivolve. It works best when coordinating with teammates."
	
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func notify_silphymon(effect):
	if not marked_by("Hawkmon Digivolve"):
		return
	var mark = has_effect("Hawkmon Digivolve", EffectType.Type.MARK)
	if mark.mag != 999:
		return

	var effect_id = 0
	var effect_string = "Sample"
	match effect.effect_type:
		EffectType.Type.STUN:
			effect_id = 1
			effect_string = " Stun"
		EffectType.Type.SILENCE:
			effect_id = 2
			effect_string = " Silence"
		EffectType.Type.DEF_NEGATE:
			effect_id = 3
			effect_string = " Shatter"
		EffectType.Type.ISOLATE:
			effect_id = 4
			effect_string = "n Isolation"
		EffectType.Type.TAUNT:
			effect_id = 5
			effect_string = " Taunt"
		EffectType.Type.BLIND:
			effect_id = 6
			effect_string = " Blind"
	if effect_id == 0 or effect_string == "Sample":
		return
	var exists = false
	for storage_eff in effects.get_effects_by_type(EffectType.Type.EMPTY):
		if storage_eff.mag == effect_id:
			exists = true
			storage_eff.duration = 7
	if not exists:
		var empty = Effect.empty(7, "Silphymon has witnessed a" + effect_string + " effect.")
		empty.set_source(moveset.base_abilities[2])
		empty.unique_render_id = 69
		empty.mag = effect_id
		Character.add_allied_effect(QueryContext.from_game_state(self, battle), self, self, empty)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
