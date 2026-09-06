extends Character
class_name Asta


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1, 3]
	character_name = "Asta"
	path_name = "asta"
	universe = CharacterConcept.Universe.BLACK_CLOVER
	description = "A Magic Knight of the Clover Kingdom, Asta wields the five-leaf clover grimoire and a variety of anti-magic swords."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func change_equip(args=[]):
	self.manually_advance_mission(9, 1)
	if has_effect("Liebe Unite", EffectType.Type.MARK, self) == null:
		effects.full_remove_effect_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER, self)
		effects.full_remove_effect_by_type(EffectType.Type.DAMAGE_MOD, self)
	else:
		var swords = 0
		if has_effect("Demon-Slayer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, self):
			swords += 1
		if has_effect("Demon-Dweller Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, self):
			swords += 1
		if has_effect("Demon-Destroyer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, self):
			swords += 1
		var dropped_sword
		if swords >= 2:
			var potential_swords = effects.get_effects_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER)
			for effect in potential_swords:
				if effect.user == self:
					effects.full_remove_effect_by_name(effect.source.ability_name, self)
					return

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
