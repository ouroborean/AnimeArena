extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Erza Scarlet"
	character_colors = [0, 1, 3]
	path_name = "erza"
	universe = CharacterConcept.Universe.FAIRY_TAIL
	description = "Erza Scarlet, contender for the position of strongest mage in Fairy Tail. Her magic allows her to manifest suits of armor and powerful weapons, giving her a versatile edge."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func wearing_armor(args):
	var armor_string = args[0]
	for effect in effects.get_effects_by_type(EffectType.Type.ERZA_ARMOR):
		if effect.effect_name() == armor_string:
			return true
	return false

func requip_armor(args):
	var armor_string = args[0]
	for effect in effects.get_effects_by_type(EffectType.Type.ERZA_ARMOR):
		effects.erase_effect(effect)
	for effect in effects.get_effects_by_type(EffectType.Type.COST_CHANGE):
		if effect.effect_name() == "Queen of Fairies":
			effects.erase_effect(effect)
	var context = QueryContext.from_game_state(self, battle)
	match armor_string:
		"clear_heart":
			var armor = Effect.erza_armor_effect(armor_string, "Clear Heart Clothing", 7)
			armor.set_source(moveset.base_abilities[3])
			if DisplayServer.get_name() != "headless":
				armor.tooltip = load("res://assets/images/Erza Scarlet/" + armor_string + ".png")
			Character.add_allied_effect(context, self, self, armor)
			var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 7, ["Titania's Rampage"])
			cost_change.set_source(moveset.base_abilities[3])
			cost_change.system = true
			Character.add_allied_effect(context, self, self, cost_change)
		"heavens_wheel":
			var armor = Effect.erza_armor_effect(armor_string, "Heaven's Wheel Armor", 5)
			armor.set_source(moveset.base_abilities[3])
			if DisplayServer.get_name() != "headless":
				armor.tooltip = load("res://assets/images/Erza Scarlet/" + armor_string + ".png")
			Character.add_allied_effect(context, self, self, armor)
			var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 7, ["Circle Blade"])
			cost_change.set_source(moveset.base_abilities[3])
			cost_change.system = true
			Character.add_allied_effect(context, self, self, cost_change)
		"nakagamis":
			var armor = Effect.erza_armor_effect(armor_string, "Nakagami's Armor", 3)
			armor.set_source(moveset.base_abilities[3])
			if DisplayServer.get_name() != "headless":
				armor.tooltip = load("res://assets/images/Erza Scarlet/" + armor_string + ".png")
			Character.add_allied_effect(context, self, self, armor)
			var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 7, ["Nakagami's Starlight"])
			cost_change.set_source(moveset.base_abilities[3])
			cost_change.system = true
			Character.add_allied_effect(context, self, self, cost_change)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
