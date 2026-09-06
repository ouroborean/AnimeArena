extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "At the end of each of his turns, Hashirama will give his team 5 Shield and deal 5 Piercing damage to the enemy team for each of Hashirama's currently delayed skills."

func split_desc():
	return [
		["At the end of each of Hashirama's turns, his team gains 5 Shield per skill he currently has delayed", Color.CADET_BLUE],
		["The enemy team takes 5 Piercing damage per skill he currently has delayed", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(delay_tick_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, "At the end of the turn, Hashirama will give his team 5 Shield and deal 5 Piercing damage to the enemy team for every skill currently delayed by Hashirama or his allies.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)
	
	var self_delay = Effect.delay_eff(1, -1, -1, ["Harmful"])
	self_delay.set_source(self)
	self_delay.system = true
	self_delay.stackable = false
	Character.add_allied_effect(context, user, user, self_delay)
	
	
func delay_tick_trigger(context):
	var total_delays = 0
	var hashirama = context['effect'].user
	for character in context['battle'].all_characters():
		for effect in character.effects.get_effects_by_type(EffectType.Type.DELAYED_SKILL):
			if effect.user == hashirama and not effect.duration == 1:
				total_delays += 1
				if hashirama.marked_by("Deep Forest Creation", hashirama):
					if effect.source.ability_name == "Deep Forest Bloom: Pollen":
						for pollen_target in hashirama.battle.all_characters():
							if pollen_target in hashirama.team.characters:
								Character.resolve_effect_healing(context, effect, pollen_target, 5)
							else:
								Character.resolve_effect_damage(context, effect, pollen_target, 5, DamageType.Type.AFFLICTION)
					elif effect.source.ability_name == "Deep Forest Bloom: Strangle":
						var valid_targets = []
						for strangle_character in context['enemy_team'].characters:
							if not strangle_character.dead and not strangle_character.banished and not strangle_character.is_invuln(self):
								valid_targets.append(strangle_character)
						if len(valid_targets) < 1:
							continue
						var random_target = valid_targets[context['battle'].roll(0, len(valid_targets) - 1)]
						var stun = Effect.stun_effect(2, ["Physical", "Energy"])
						stun.set_source(self)
						Character.add_hostile_effect(context, hashirama, random_target, stun)
	user.manually_advance_mission(6, total_delays)
	for i in range(total_delays):
		for character in context['ally_team'].characters:
			if not character.dead and not character.is_isolated() and not character.banished:
				var shield = Effect.shield_effect(5, -1)
				shield.set_source(self)
				Character.add_allied_effect(context, user, character, shield)
		for character in context['enemy_team'].characters:
			if not character.dead and not character.is_invuln(self) and not character.banished:
				Character.resolve_effect_damage(context, context['effect'], character, 5, DamageType.Type.PIERCING)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
